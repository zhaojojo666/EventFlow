"""Build an upload bundle, optionally including a consistent local data snapshot."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import socket
import subprocess
import tarfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]


def run(*args):
    result = subprocess.run(args, cwd=ROOT, check=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    return result.stdout.decode("utf-8", errors="replace").strip()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--with-local-data", action="store_true")
    args = parser.parse_args()
    if args.with_local_data:
        with socket.socket() as probe:
            probe.settimeout(1)
            if probe.connect_ex(("127.0.0.1", 8082)) == 0:
                raise SystemExit("Stop the local EventFlow backend before exporting data.")
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    stage = ROOT / "output" / ("deploy-bundle-" + stamp)
    stage.mkdir(parents=True)
    files = ["Dockerfile", ".dockerignore", "compose.yaml", ".env.example",
             "DEPLOY_ALIYUN.md", "scripts/deploy-first.sh", "scripts/restore-redis.sh",
             "target/eventflow-ticketing-0.0.1-SNAPSHOT.jar",
             "src/main/resources/db/eventflow.sql"]
    for relative in files:
        dest = stage / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, dest)
    migration = stage / "migration"
    if args.with_local_data:
        migration.mkdir()
        compose = ["docker", "compose", "-p", "eventflow-desktop-qa",
                   "-f", "compose.local.yaml"]
        mysql = run(*compose, "ps", "-q", "mysql")
        redis = run(*compose, "ps", "-q", "redis")
        if not mysql or not redis:
            raise SystemExit("Local MySQL and Redis must be running.")
        mysql_exec = ["docker", "exec", "-e", "MYSQL_PWD=eventflow-qa-local", mysql]
        tables = run(*mysql_exec, "mysql", "-uroot", "eventflow_desktop", "-N", "-e",
                     "SHOW TABLES").splitlines()
        counts = {}
        for table in tables:
            if not table.startswith("tb_") or not table.replace("_", "").isalnum():
                raise SystemExit("Unexpected table name: " + table)
            counts[table] = int(run(*mysql_exec, "mysql", "-uroot", "eventflow_desktop",
                                    "-N", "-e", f"SELECT COUNT(*) FROM `{table}`"))
        run(*mysql_exec, "mysqldump", "-uroot", "--single-transaction", "--quick",
            "--routines", "--triggers", "--events", "--no-tablespaces",
            "--set-gtid-purged=OFF", "--column-statistics=0",
            "--default-character-set=utf8mb4",
            "--result-file=/tmp/eventflow-migration.sql", "eventflow_desktop")
        run("docker", "cp", mysql + ":/tmp/eventflow-migration.sql", str(migration / "mysql.sql"))
        run("docker", "exec", "-e", "REDISCLI_AUTH=eventflow-qa-local", redis,
            "redis-cli", "--rdb", "/tmp/eventflow-migration.rdb")
        run("docker", "cp", redis + ":/tmp/eventflow-migration.rdb", str(migration / "redis.rdb"))
        upload_count = 0
        with tarfile.open(migration / "uploads.tar", "w") as archive:
            uploads = ROOT / "uploads"
            if uploads.exists():
                for item in sorted(uploads.rglob("*")):
                    if item.is_file():
                        if item.is_symlink():
                            raise SystemExit("Symlink in uploads: " + str(item))
                        archive.add(item, arcname=item.relative_to(uploads).as_posix())
                        upload_count += 1
        with (migration / "counts.tsv").open("w", encoding="utf-8", newline="\n") as output:
            for table, count in counts.items():
                output.write(f"{table}\t{count}\n")
        manifest = {"created_utc": datetime.now(timezone.utc).isoformat(),
                    "source_database": "eventflow_desktop", "destination_database": "eventflow",
                    "table_counts": counts, "uploaded_files": upload_count,
                    "jar_sha256": digest(stage / files[-2])}
        (migration / "manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        checked = [stage / relative for relative in files if relative != "DEPLOY_ALIYUN.md"]
        checked += [item for item in migration.iterdir() if item.is_file()]
        with (migration / "checksums.sha256").open("w", encoding="utf-8", newline="\n") as output:
            for item in sorted(checked):
                output.write(f"{digest(item)}  {item.relative_to(stage).as_posix()}\n")
    package = ROOT / "EventFlow-deploy.tar.gz"
    # Keep the previous generated archive recoverable; do not include it in the new bundle.
    if package.exists():
        shutil.copy2(package, ROOT / "output" / ("previous-deploy-" + stamp + ".tar.gz"))
    with tarfile.open(package, "w:gz", compresslevel=6) as archive:
        for item in sorted(stage.rglob("*")):
            if item.is_file():
                archive.add(item, arcname=item.relative_to(stage).as_posix())
    result = {"package": str(package), "bytes": package.stat().st_size,
              "sha256": digest(package), "staging_directory": str(stage),
              "includes_local_data": args.with_local_data}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    (ROOT / "output" / "latest-deploy-package.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

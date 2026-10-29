"""Restore the latest snapshot into disposable local containers and verify it."""
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def run(*args, timeout=120):
    result = subprocess.run(args, check=True, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=timeout)
    return result.stdout.decode("utf-8", errors="replace").strip()


def main():
    package = json.loads((ROOT / "output/latest-deploy-package.json").read_text("utf-8"))
    stage = Path(package["staging_directory"])
    if not stage.resolve().is_relative_to((ROOT / "output").resolve()):
        raise RuntimeError("Unexpected staging location")
    snapshot = stage / "migration"
    manifest = json.loads((snapshot / "manifest.json").read_text("utf-8"))
    for line in (snapshot / "checksums.sha256").read_text("utf-8").splitlines():
        expected, relative = line.split("  ", 1)
        file = stage / relative
        if not file.resolve().is_relative_to(stage.resolve()):
            raise RuntimeError("Unexpected checksum path")
        assert hashlib.sha256(file.read_bytes()).hexdigest() == expected, relative
    assert hashlib.sha256(Path(package["package"]).read_bytes()).hexdigest() == package["sha256"]
    for port in (23307, 26380, 18085):
        with socket.socket() as probe:
            if probe.connect_ex(("127.0.0.1", port)) == 0:
                raise RuntimeError(f"Test port {port} is already occupied")
    suffix = str(int(time.time()))
    mysql_name = "eventflow-restore-mysql-" + suffix
    redis_name = "eventflow-restore-redis-" + suffix
    redis_volume = "eventflow-restore-redis-data-" + suffix
    test_password = "eventflow-restore-check-only"
    started = []
    made_volume = False
    app = None
    log_file = None
    delayed_server = ROOT / "output" / ("delayed-redis-server-" + suffix)
    delayed_server.write_text('#!/bin/sh\nsleep 3\nexec /usr/local/bin/redis-server "$@"\n',
                              encoding="utf-8", newline="\n")
    try:
        run("docker", "run", "--rm", "--entrypoint", "bash", "-v", f"{stage}:/bundle:ro",
            "mysql:8.0", "-n", "/bundle/scripts/deploy-first.sh")
        run("docker", "run", "--rm", "--entrypoint", "sh", "-v", f"{stage}:/bundle:ro",
            "redis:7.2-alpine", "-n", "/bundle/scripts/restore-redis.sh")
        run("docker", "run", "-d", "--name", mysql_name, "--memory", "512m",
            "-e", "MYSQL_ROOT_PASSWORD=" + test_password, "-e", "MYSQL_DATABASE=eventflow",
            "-p", "127.0.0.1:23307:3306", "-v",
            f"{snapshot / 'mysql.sql'}:/docker-entrypoint-initdb.d/01-eventflow.sql:ro",
            "mysql:8.0", "--innodb-buffer-pool-size=128M", "--performance-schema=OFF")
        started.append(mysql_name)
        run("docker", "volume", "create", redis_volume)
        made_volume = True
        run("docker", "run", "--rm", "--user", "root", "--entrypoint", "sh",
            "-v", redis_volume + ":/data", "-v", f"{snapshot / 'redis.rdb'}:/backup/redis.rdb:ro",
            "-v", f"{stage / 'scripts/restore-redis.sh'}:/backup/restore-redis.sh:ro",
            "-v", f"{delayed_server}:/test-source/redis-server:ro",
            "-e", "PATH=/test-bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "redis:7.2-alpine", "-c",
            "mkdir /test-bin; cp /test-source/redis-server /test-bin/redis-server; "
            "chmod +x /test-bin/redis-server; exec sh /backup/restore-redis.sh")
        run("docker", "run", "-d", "--name", redis_name, "-p", "127.0.0.1:26380:6379",
            "-v", redis_volume + ":/data", "redis:7.2-alpine", "redis-server",
            "--appendonly", "yes", "--requirepass", test_password)
        started.append(redis_name)
        mysql = ["docker", "exec", "-e", "MYSQL_PWD=" + test_password, mysql_name,
                 "mysql", "-h127.0.0.1", "-uroot", "eventflow", "-N", "-e"]
        ready = False
        for attempt in range(90):
            try:
                run(*mysql, "SELECT COUNT(*) FROM tb_event", timeout=5)
                ready = True
                break
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                time.sleep(1)
        if not ready:
            raise RuntimeError(run("docker", "logs", "--tail", "60", mysql_name))
        for table, expected in manifest["table_counts"].items():
            actual = int(run(*mysql, f"SELECT COUNT(*) FROM `{table}`"))
            assert actual == expected, (table, actual, expected)
        redis = ["docker", "exec", "-e", "REDISCLI_AUTH=" + test_password,
                 redis_name, "redis-cli"]
        source = ["docker", "exec", "-e", "REDISCLI_AUTH=eventflow-qa-local",
                  "eventflow-desktop-qa-redis-1", "redis-cli"]
        stocks = json.loads(run(*source, "--json", "KEYS", "eventflow:ticket:stock:*"))
        for key in stocks:
            assert run(*source, "GET", key) == run(*redis, "GET", key), key
        stream = "eventflow:stream:ticket-orders"
        assert run(*source, "XLEN", stream) == run(*redis, "XLEN", stream)
        run("docker", "restart", redis_name)
        for attempt in range(15):
            try:
                if run(*redis, "PING") == "PONG":
                    break
            except subprocess.CalledProcessError:
                pass
            time.sleep(1)
        for key in stocks:
            assert run(*source, "GET", key) == run(*redis, "GET", key), key
        env = os.environ.copy()
        for key in ("SPRING_PROFILES_DEFAULT", "SPRING_APPLICATION_JSON", "JAVA_TOOL_OPTIONS"):
            env.pop(key, None)
        env.update({"SPRING_PROFILES_ACTIVE": "production",
                    "DB_URL": "jdbc:mysql://127.0.0.1:23307/eventflow?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true",
                    "DB_USER": "root", "DB_PASSWORD": test_password,
                    "REDIS_HOST": "127.0.0.1", "REDIS_PORT": "26380",
                    "REDIS_PASSWORD": test_password, "EVENTFLOW_DEMO_MODE": "true"})
        log_file = (ROOT / "output/migration-app-check.log").open("w", encoding="utf-8")
        app = subprocess.Popen([(str(Path(os.environ["JAVA_HOME"]) / "bin" / ("java.exe" if os.name == "nt" else "java")) if os.environ.get("JAVA_HOME") else "java"),
                                "-Xms128m", "-Xmx384m", "-jar",
                                str(stage / "target/eventflow-ticketing-0.0.1-SNAPSHOT.jar"),
                                "--server.port=18085"], env=env, cwd=ROOT,
                               stdout=log_file, stderr=subprocess.STDOUT,
                               creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        catalog = None
        for attempt in range(40):
            if app.poll() is not None:
                raise RuntimeError("App exited; see output/migration-app-check.log")
            try:
                with urllib.request.urlopen("http://127.0.0.1:18085/events", timeout=2) as response:
                    catalog = json.load(response)
                if catalog["success"]:
                    break
            except Exception:
                time.sleep(1)
        assert catalog and catalog["success"], "Catalog API did not become ready"
        with urllib.request.urlopen("http://127.0.0.1:18085/", timeout=3) as response:
            assert response.status == 200
        report = {"result": "PASS", "table_counts": manifest["table_counts"],
                  "redis_stock_keys_checked": len(stocks), "redis_stream_preserved": True,
                  "redis_aof_restart_passed": True, "production_profile_api_passed": True,
                  "delayed_redis_startup_passed": True,
                  "home_page_passed": True, "package_sha256": package["sha256"]}
        (ROOT / "output/migration-review.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, ensure_ascii=False, indent=2))
    finally:
        if app and app.poll() is None:
            app.terminate()
            app.wait(timeout=20)
        if log_file:
            log_file.close()
        for name in started:
            subprocess.run(["docker", "rm", "-f", "-v", name], capture_output=True)
        if made_volume:
            subprocess.run(["docker", "volume", "rm", redis_volume], capture_output=True)
        delayed_server.unlink(missing_ok=True)


if __name__ == "__main__":
    main()

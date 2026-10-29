"""Export a source-only GitHub folder and ZIP without local data or credentials."""
from datetime import datetime
import hashlib
import ipaddress
import json
from pathlib import Path
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def copy_tree(source, destination):
    for item in sorted(source.rglob("*")):
        if any(part in {"__pycache__", "node_modules", "results", ".git"}
               for part in item.relative_to(source).parts):
            continue
        if item.is_symlink():
            raise RuntimeError("Symlinks are not exported: " + str(item))
        if item.is_file() and item.suffix not in {".pyc", ".log", ".rdb", ".aof", ".jtl"}:
            target = destination / item.relative_to(source)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, target)


def write(path, value):
    path.write_text(value, encoding="utf-8", newline="\n")


def main():
    name = "EventFlow-GitHub"
    if (ROOT / name).exists() or (ROOT / (name + ".zip")).exists():
        name += "-" + datetime.now().strftime("%Y%m%d-%H%M%S")
    folder = ROOT / name
    folder.mkdir()
    for directory in ("src", "scripts", "design", "docs"):
        copy_tree(ROOT / directory, folder / directory)
    for relative in ("pom.xml", "README.md", ".gitignore", ".dockerignore", ".env.example",
                     "compose.yaml", "compose.local.yaml", "Dockerfile", "apifox-openapi.yaml",
                     "start-local.cmd", "start-local.ps1", "stop-local.ps1"):
        shutil.copy2(ROOT / relative, folder / relative)
    # The private server runbook remains in the working project. Export a generic one.
    shutil.copy2(ROOT / "docs/DEPLOYMENT.md", folder / "DEPLOY_ALIYUN.md")
    legacy_source = ROOT / "jmeter"
    if not legacy_source.exists():
        legacy_source = ROOT / "legacy/jmeter"
    copy_tree(legacy_source, folder / "legacy/jmeter")
    legacy = folder / "legacy/jmeter/README.md"
    legacy_text = legacy.read_text("utf-8-sig")
    if not legacy_text.startswith("# 历史 JMeter 压测资料"):
        write(legacy, "# 历史 JMeter 压测资料\n\n"
          "本目录来自旧版点评工程，包含旧接口、旧表名和 Redis 键名，尚未适配当前 EventFlow。"
          "仅保留作迁移参考，不可直接用于当前业务库，也不构成本项目的性能测试结果。"
          "当前验证入口见仓库根目录 README 与 src/test。\n\n"
          "以下是历史版本使用记录：\n\n" + legacy_text)
    legacy_script = folder / "legacy/jmeter/run-seckill-load-test.ps1"
    text = legacy_script.read_text("utf-8-sig")
    text = re.sub(r"\[string\]\$JMeterHome = '[^']*'", "[string]$JMeterHome = $env:JMETER_HOME", text)
    text = re.sub(r"\[string\]\$MySqlHome = '[^']*'", "[string]$MySqlHome = $env:MYSQL_HOME", text)
    write(legacy_script, text)
    # Keep prompts and final assets; omit machine-specific generation file locations.
    prompts_file = folder / "design/assets-prompts.json"
    prompts = json.loads(prompts_file.read_text("utf-8-sig"))
    for asset in prompts["assets"]:
        asset.pop("source", None)
    write(prompts_file, json.dumps(prompts, ensure_ascii=False, indent=2) + "\n")
    review = folder / "scripts/review_mobile.cjs"
    text = review.read_text("utf-8-sig")
    text = re.sub(r"require\('[^']*/playwright'\)", "require('playwright')", text, count=1)
    text = text.replace("const base='http://127.0.0.1:8082';",
                        "const base=process.env.EVENTFLOW_BASE_URL||'http://127.0.0.1:8082';")
    text = text.replace("const fs = require('node:fs');",
                        "const fs = require('node:fs');\nfs.mkdirSync('output',{recursive:true});")
    write(review, text)
    backend = folder / "scripts/check_backend.cjs"
    text = backend.read_text("utf-8-sig").replace("const fs=require('node:fs');",
              "const fs=require('node:fs');\nfs.mkdirSync('output',{recursive:true});")
    write(backend, text)
    verification = folder / "scripts/verify-migration.py"
    text = verification.read_text("utf-8-sig")
    text = text.replace('str(Path.home() / ".jdks/ms-17.0.18/bin/java.exe")',
                        '(str(Path(os.environ["JAVA_HOME"]) / "bin" / ("java.exe" if os.name == "nt" else "java")) if os.environ.get("JAVA_HOME") else "java")')
    text = text.replace("creationflags=subprocess.CREATE_NO_WINDOW",
                        'creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0)')
    write(verification, text)
    api = folder / "apifox-openapi.yaml"
    text = api.read_text("utf-8-sig")
    text = text.replace("从后端控制台取得验证码", "在演示模式下从响应 data.demoCode 取得验证码")
    text = text.replace("注意：当前 `/user/logout` 的业务实现会返回“功能未完成”。",
                        "`/user/logout` 会注销当前 Token。本文档主要覆盖基础接口，新增演出与预订接口见 README。")
    text = text.replace("验证码已生成；验证码输出在后端控制台并保存到 Redis",
                        "演示模式生成验证码、保存到 Redis，并在 data.demoCode 中返回；未接入真实短信")
    write(api, text)
    files = sorted(p for p in folder.rglob("*") if p.is_file())
    blocked_parts = {"target", ".idea", ".run", ".tools", "output", "uploads", "migration",
                     ".deploy-state", "node_modules", ".git", "__pycache__"}
    for item in files:
        relative = item.relative_to(folder)
        if blocked_parts.intersection(relative.parts) or item.name == ".env":
            raise RuntimeError("Unexpected private/generated file: " + str(relative))
        if item.suffix.lower() in {".java", ".py", ".cjs", ".ps1", ".md", ".json", ".yaml", ".sh", ".xml"}:
            text = item.read_text("utf-8-sig")
            if re.search(r"[A-Za-z]:[/\\]+Users[/\\]+|BEGIN [A-Z ]*PRIVATE KEY", text):
                # This exporter contains its own detection pattern; it holds no private data.
                if relative.as_posix() != "scripts/export-github.py":
                    raise RuntimeError("Private path or server address in " + str(relative))
            for address in re.findall(r"\b(?:\d{1,3}\.){3}\d{1,3}\b", text):
                try:
                    parsed = ipaddress.ip_address(address)
                except ValueError:
                    continue
                if parsed.is_global:
                    raise RuntimeError("Public IP address in " + str(relative))
    archive = ROOT / (name + ".zip")
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for item in files:
            output.write(item, arcname=(Path(name) / item.relative_to(folder)).as_posix())
    with zipfile.ZipFile(archive) as check:
        assert check.testzip() is None
        assert len(check.namelist()) == len(files)
    report = {"folder": str(folder), "zip": str(archive), "files": len(files),
              "zip_bytes": archive.stat().st_size,
              "zip_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
              "source_java_files": len(list((folder / "src").rglob("*.java"))),
              "ai_webp_assets": len(list((folder / "src/main/resources/static/imgs/eventflow").glob("*.webp"))),
              "excluded": sorted(blocked_parts | {".env", "deployment/data archives"})}
    (ROOT / "output").mkdir(exist_ok=True)
    write(ROOT / "output/github-export-review.json", json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

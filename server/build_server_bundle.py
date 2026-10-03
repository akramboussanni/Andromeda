#!/usr/bin/env python3
"""Build the no-Git Windows server zip consumed by Setup-Andromeda-Server.ps1."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--core", type=Path, default=ROOT.parent / "Andromeda.Core")
    parser.add_argument("--output", type=Path, default=ROOT / "dist" / "Andromeda.Server.Windows.zip")
    parser.add_argument("--version", default="0.11.2")
    parser.add_argument("--mod-version", default="0.11.1")
    args = parser.parse_args()
    core = args.core.resolve()
    if not (core / "setup_server.py").is_file():
        raise SystemExit(f"Core setup not found at {core}; pass --core")

    tracked = subprocess.check_output(["git", "-C", str(core), "ls-files"], text=True).splitlines()
    required_untracked = [".env.example", "landing_page.py", "setup_server.py", "Setup-Andromeda-Server.bat"]
    tracked.extend(path for path in required_untracked if (core / path).is_file())
    tracked.extend(str(path.relative_to(core)) for folder in ("server_setup",) for path in (core / folder).rglob("*.py"))
    manifest = {
        "schema": 1,
        "version": args.version,
        "mod": {"repo": "akramboussanni/Andromeda.Mod", "tag": args.mod_version, "assetPattern": r"^Andromeda\.Mod.*\.(zip|dll)$"},
        "melonloader": {"repo": "LavaGang/MelonLoader", "version": "latest", "asset": "MelonLoader.x64.zip"},
        "steam": {"appId": "999860"},
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temp:
        stage = Path(temp)
        for relative_name in sorted(set(tracked)):
            relative = Path(relative_name)
            if relative.parts[0] == "tests" or relative.name == ".gitignore":
                continue
            source = core / relative
            if source.is_file():
                target = stage / "core" / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        (stage / "andromeda-server-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        with zipfile.ZipFile(args.output, "w", zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(stage.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(stage))
    print(args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Produce a single-threaded release Web build; no upload/deployment side effects."""

import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot")
    if godot is None:
        godot = "/Applications/Godot.app/Contents/MacOS/Godot"
    output = ROOT / "build/web"
    output.mkdir(parents=True, exist_ok=True)
    (output.parent / ".gdignore").touch()
    for sidecar in output.glob("*.import"):
        sidecar.unlink()
    for arguments in [("--editor", "--import", "--quit"),
                      ("--export-release", "Web", str(output / "index.html"))]:
        result = subprocess.run(
            [godot, "--headless", "--path", str(ROOT), *arguments],
            text=True, capture_output=True, check=False,
        )
        log = result.stdout + result.stderr
        if result.returncode or any(marker in log for marker in ("ERROR:", "SCRIPT ERROR", "Parse Error")):
            raise SystemExit(log)
    for filename in ("index.html", "index.js", "index.pck", "index.wasm"):
        path = output / filename
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"Missing or empty export: {path}")
    # Loading the real exported pack catches class_name-only dependencies
    # that editor/headless scene tests can accidentally satisfy from res://.
    for scene in ("features/stage_flow/stage_select", "levels/prototype_alley/prototype_alley", "levels/industrial_yard/industrial_yard", "levels/woods/woods", "levels/headquarters/headquarters"):
        result = subprocess.run(
            [godot, "--headless", "--path", str(ROOT), "--main-pack",
             str(output / "index.pck"), "--script", str(ROOT / "tools/smoke_test_web_export.gd"),
             "--", f"res://{scene}.tscn"],
            text=True, capture_output=True, check=False,
        )
        log = result.stdout + result.stderr
        if result.returncode or "WEB_EXPORT_SMOKE_TEST_PASS" not in log or any(marker in log for marker in ("ERROR:", "WARNING:", "SCRIPT ERROR", "Parse Error")):
            raise SystemExit(log)
    print(f"Release Web build: {output}")
    for path in sorted(output.iterdir()):
        if path.is_file():
            print(f"  {path.name}: {path.stat().st_size / 1024 / 1024:.2f} MiB")


if __name__ == "__main__":
    main()

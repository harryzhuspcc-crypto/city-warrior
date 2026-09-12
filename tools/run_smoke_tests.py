#!/usr/bin/env python3
"""Run every headless smoke test and fail on Godot diagnostics.

Godot can exit with status 0 after some script/runtime errors, so process exit
codes alone are not a sufficient CI gate for this project.
"""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import sys


PROJECT_ROOT = Path(__file__).resolve().parent.parent
TESTS = (
    "tools/smoke_test_player.gd",
    "tools/smoke_test_step_4.gd",
    "tools/smoke_test_steps_4_5.gd",
    "tools/smoke_test_combat_overlap.gd",
    "tools/smoke_test_special_moves.gd",
)
DIAGNOSTIC_MARKERS = (
    "ERROR:",
    "WARNING:",
    "SCRIPT ERROR",
    "Parse Error",
    "SMOKE_TEST_FAIL",
)


def _godot_executable() -> str:
    configured = os.environ.get("GODOT_BIN")
    if configured:
        return configured
    discovered = shutil.which("godot")
    if discovered:
        return discovered
    macos_app = "/Applications/Godot.app/Contents/MacOS/Godot"
    if Path(macos_app).is_file():
        return macos_app
    raise FileNotFoundError("Set GODOT_BIN to a Godot 4.7+ executable")


def main() -> int:
    godot = _godot_executable()
    failed = False

    for test_path in TESTS:
        command = [
            godot,
            "--headless",
            "--path",
            str(PROJECT_ROOT),
            "--script",
            f"res://{test_path}",
        ]
        try:
            result = subprocess.run(
                command,
                capture_output=True,
                check=False,
                text=True,
                timeout=30,
            )
        except subprocess.TimeoutExpired:
            print(f"FAIL {test_path}: timed out after 30 seconds", file=sys.stderr)
            failed = True
            continue

        output = result.stdout + result.stderr
        diagnostics = [
            line
            for line in output.splitlines()
            if any(marker in line for marker in DIAGNOSTIC_MARKERS)
        ]
        passed = result.returncode == 0 and not diagnostics and "PASS" in output
        print(f"{'PASS' if passed else 'FAIL'} {test_path}")
        if not passed:
            print(output.rstrip(), file=sys.stderr)
            failed = True

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())

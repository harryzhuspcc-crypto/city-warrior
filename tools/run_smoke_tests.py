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
    "tools/smoke_test_williams.gd",
    "tools/smoke_test_hair_grab.gd",
    "tools/smoke_test_encounter.gd",
    "tools/smoke_test_ladder.gd",
    "tools/smoke_test_combo.gd",
    "tools/smoke_test_music.gd",
    "tools/smoke_test_combat_audio.gd",
)
# Headless Godot paces physics to real time, so a suite's budget is really a
# budget on simulated seconds. The ladder suite climbs the SCOOP ladder's
# 135 px at Billy's own 48 px/s several times over, which is most of a minute
# on its own; the rest finish in a few seconds each.
SUITE_TIMEOUT_SECONDS = 120
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
                timeout=SUITE_TIMEOUT_SECONDS,
            )
        except subprocess.TimeoutExpired:
            print(
                f"FAIL {test_path}: timed out after {SUITE_TIMEOUT_SECONDS} seconds",
                file=sys.stderr,
            )
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

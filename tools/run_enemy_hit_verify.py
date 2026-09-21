"""Verify all enemy hurt animations and combat hit receipts in an isolated copy; never touch the player's save.

Usage: python tools/run_enemy_hit_verify.py --godot /path/to/godot
The copy, user data, logs and optional screenshots remain under Temp/.
"""

import argparse
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--render", action="store_true", help="Render screenshots in a hidden window")
    parser.add_argument("--output-root", type=Path, help="Parent Temp directory for isolated verification copies")
    args = parser.parse_args()
    workspace = Path(__file__).resolve().parents[1]
    temp = args.output_root.resolve() if args.output_root else workspace / "Temp"
    temp.mkdir(exist_ok=True)
    sandbox = Path(tempfile.mkdtemp(prefix="enemy-hit-verify-", dir=temp))
    for folder in ("scripts", "scenes", "art", "data", "themes"):
        shutil.copytree(workspace / folder, sandbox / folder)
    # Reuse imported assets when available, while keeping all writes in the sandbox.
    if (workspace / ".godot" / "imported").exists():
        shutil.copytree(workspace / ".godot" / "imported", sandbox / ".godot" / "imported")
    config = (workspace / "project.godot").read_text(encoding="utf-8")
    config = config.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\n'
                            f'config/custom_user_dir_name="{sandbox.as_posix()}/userdata"')
    config = config.replace('TestBridge="*res://test_bridge.gd"\n', '')
    config = re.sub(r'^_mcp_game_helper=.*\n', '', config, flags=re.M)
    config = re.sub(r'^enabled=PackedStringArray\(.*\)', 'enabled=PackedStringArray()', config, flags=re.M)
    (sandbox / "project.godot").write_text(config, encoding="utf-8")
    env = os.environ.copy()
    env["APPDATA"] = str(sandbox / "appdata")
    env["ENEMY_HIT_TEST_ROOT"] = str(sandbox)
    env["LOCALAPPDATA"] = str(sandbox / "localappdata")
    base = [str(Path(args.godot).resolve()), "--path", str(sandbox)]
    print(f"Verification directory: {sandbox}", flush=True)
    import_result = subprocess.run(base + ["--headless", "--editor", "--import", "--log-file", "import.log"],
                                   env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300)
    (sandbox / "import-output.log").write_text(import_result.stdout + import_result.stderr, encoding="utf-8")
    if import_result.returncode or any(marker in import_result.stdout + import_result.stderr
                                       for marker in ("SCRIPT ERROR", "SHADER ERROR", "Parse Error", "Compile Error")):
        print(import_result.stdout + import_result.stderr)
        return 1
    rendering = ["--resolution", "720x1280", "--audio-driver", "Dummy"] if args.render else ["--headless"]
    startupinfo = None
    if args.render and os.name == "nt":
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = subprocess.SW_HIDE
    (sandbox / "Temp").mkdir(exist_ok=True)
    suites = [
        ("enemy-hit", "res://scenes/verify/EnemyHitVerify.tscn", "ENEMY_HIT_RESULT:PASS"),
        ("combat-feedback", "res://scenes/combat/CombatFeedbackVerify.tscn", "FEEDBACK_RESULT:PASS"),
    ]
    for name, scene, marker in suites:
        command = base + rendering + ["--log-file", str(sandbox / (name + ".log")), scene]
        if args.render: command += ["--", "--visual"]
        result = subprocess.run(command, env=env, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=180, startupinfo=startupinfo)
        output = result.stdout + result.stderr
        (sandbox / (name + "-output.log")).write_text(output, encoding="utf-8")
        print(output, flush=True)
        if result.returncode != 0 or marker not in output or any(
            error in output for error in ("SCRIPT ERROR", "SHADER ERROR", "Shader compilation failed")):
            return 1
    return 0



if __name__ == "__main__":
    raise SystemExit(main())

"""Run the real scene flow in an isolated copy; never touch the player's save.

Usage: python tools/run_transition_verify.py --godot /path/to/godot
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
    parser.add_argument("--suite", choices=("transition", "pause-abandon"), default="transition")
    parser.add_argument("--render", action="store_true", help="Render screenshots in a hidden window")
    parser.add_argument("--output-root", type=Path, help="Parent Temp directory for isolated verification copies")
    args = parser.parse_args()
    verifier = "PauseAbandonVerify" if args.suite == "pause-abandon" else "TransitionVerify"
    result_marker = "PAUSE_ABANDON_RESULT:PASS" if args.suite == "pause-abandon" else "TRANSITION_RESULT:PASS"
    workspace = Path(__file__).resolve().parents[1]
    temp = args.output_root.resolve() if args.output_root else workspace / "Temp"
    temp.mkdir(exist_ok=True)
    sandbox = Path(tempfile.mkdtemp(prefix="transition-verify-", dir=temp))
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
    # Last autoload persists while the test exercises actual scene replacement.
    config = config.replace('[display]', f'{verifier}="*res://scripts/verify/{verifier}.gd"\n\n[display]')
    (sandbox / "project.godot").write_text(config, encoding="utf-8")
    env = os.environ.copy()
    env["APPDATA"] = str(sandbox / "appdata")
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
    result = subprocess.run(base + rendering + ["--log-file", "verify.log", "--", f"--{args.suite}-verify"],
                            env=env, capture_output=True, text=True, encoding="utf-8", errors="replace",
                            timeout=120, startupinfo=startupinfo)
    output = result.stdout + result.stderr
    (sandbox / "verify-output.log").write_text(output, encoding="utf-8")
    print(output)
    return 0 if result.returncode == 0 and result_marker in output and not any(
        marker in output for marker in ("SCRIPT ERROR", "SHADER ERROR", "Shader compilation failed")) else 1


if __name__ == "__main__":
    raise SystemExit(main())

"""Run status VFX and enemy action checks serially in an isolated project copy."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    sandbox = root / "Temp/status-orbit-verify"
    sandbox.mkdir(parents=True, exist_ok=True)
    for folder in ("scripts", "scenes", "data", "themes", "art"):
        shutil.copytree(root / folder, sandbox / folder, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns("candidates", "*.gif", "*.psd", "*.blend", "*source", "palette_source"))
    if (root / ".godot/imported").exists():
        shutil.copytree(root / ".godot/imported", sandbox / ".godot/imported", dirs_exist_ok=True)
    config = (root / "project.godot").read_text(encoding="utf-8")
    config = config.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\n' +
                            f'config/custom_user_dir_name="{sandbox.as_posix()}/userdata"')
    config = re.sub(r'^(TestBridge|_mcp_game_helper)=.*\n', '', config, flags=re.M)
    config = re.sub(r'^enabled=PackedStringArray\(.*\)', 'enabled=PackedStringArray()', config, flags=re.M)
    (sandbox / "project.godot").write_text(config, encoding="utf-8")
    (sandbox / "Temp").mkdir(exist_ok=True)
    env = os.environ.copy()
    env.update(APPDATA=str(sandbox / "appdata"), LOCALAPPDATA=str(sandbox / "localappdata"),
               STATUS_ORBIT_TEST_ROOT=str(sandbox), UPGRADE_VERIFY_ROOT=str(sandbox),
               ENEMY_HIT_TEST_ROOT=str(sandbox))
    godot = Path(args.godot).resolve()
    if godot.name.endswith("_console.exe"):
        godot = godot.with_name(godot.name.replace("_console.exe", ".exe"))
    startupinfo = None
    if os.name == "nt":
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = subprocess.SW_HIDE

    def run(name, options, marker=None):
        result = subprocess.run([str(godot), "--path", str(sandbox), "--log-file", str(sandbox / (name + ".log"))] + options,
                                env=env, capture_output=True, text=True, encoding="utf-8", errors="replace",
                                timeout=300, startupinfo=startupinfo)
        output = result.stdout + result.stderr
        (sandbox / (name + "-output.log")).write_text(output, encoding="utf-8")
        if result.returncode or any(x in output for x in ("SCRIPT ERROR", "Parse Error", "Compile Error", "SHADER ERROR")) or marker and marker not in output:
            print(output, flush=True)
            raise SystemExit(1)
        print("\n".join(line for line in output.splitlines() if "RESULT" in line or "[FAIL]" in line), flush=True)
        print(name + " completed", flush=True)

    print("Verification directory: " + str(sandbox), flush=True)
    run("import", ["--headless", "--editor", "--import"])
    for name, scene, marker in [
        ("status-orbit", "res://scenes/verify/StatusOrbitVerify.tscn", "STATUS_ORBIT_RESULT:PASS"),
        ("enemy-action", "res://scenes/verify/EnemyActionPresentationVerify.tscn", "ENEMY_PRESENTATION_RESULT:PASS"),
        ("combat-feedback", "res://scenes/combat/CombatFeedbackVerify.tscn", "FEEDBACK_RESULT:PASS"),
    ]:
        visual = args.render and name == "status-orbit"
        options = ["--resolution", "720x1280", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"] if visual else ["--headless"]
        run(name, options + [scene] + (["--", "--visual"] if visual else []), marker)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

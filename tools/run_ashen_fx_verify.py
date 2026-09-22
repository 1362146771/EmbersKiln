"""Run Ashen Binder VFX and combat regressions serially in an isolated project copy."""
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
    parser.add_argument("--suite", choices=("all", "ashen", "hidden-act", "enemy-action", "card-queue", "boss-lab"), default="all")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    sandbox = root / "Temp/ashen-fx-verify"
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
    if args.render and args.suite in ("all", "ashen"):
        for old_frame in (sandbox / "Temp/ashen_frames").glob("*.png"):
            old_frame.unlink()
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
        ("boss-lab", "res://scenes/combat/AshenBossLab.tscn", "ASHEN_LAB_RESULT:PASS"),
        ("ashen", "res://scenes/verify/AshenBinderFXVerify.tscn", "ASHEN_FX_RESULT:PASS"),
        ("hidden-act", "res://scenes/verify/HiddenActVerify.tscn", "HIDDEN_ACT_RESULT:PASS"),
        ("enemy-action", "res://scenes/verify/EnemyActionPresentationVerify.tscn", "ENEMY_PRESENTATION_RESULT:PASS"),
        ("card-queue", "res://scenes/verify/CardPlayQueueVerify.tscn", "CARD_QUEUE_RESULT:PASS"),
    ]:
        if args.suite != "all" and args.suite != name:
            continue
        visual = args.render and name in ("ashen", "card-queue", "boss-lab")
        options = ["--resolution", "720x1280", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"] if visual else ["--headless"]
        run(name, options + [scene] + (["--", "--smoke"] + (["--visual"] if visual else []) if name == "boss-lab" else (["--", "--visual"] if visual else [])), marker)
        if name == "boss-lab":
            run("profile", ["--headless", "--quit-after", "240", "res://scenes/verify/ProfilePersistenceVerify.tscn"], "PROFILE_RESULT:PASS")
    if args.render:
        out = root/"outputs/qa/ashen-fx"
        out.mkdir(parents=True, exist_ok=True)
        for image in (sandbox/"Temp").glob("ashen_*.png"):
            shutil.copy2(image, out/image.name)
        from PIL import Image
        frames = [Image.open(p).convert("RGB").resize((432,768)) for p in sorted((sandbox/"Temp/ashen_frames").glob("*.png"))]
        if frames and args.suite in ("all", "ashen"):
            frames[0].save(out/"ashen_binder_preview.gif", save_all=True, append_images=frames[1:], duration=90, loop=0)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

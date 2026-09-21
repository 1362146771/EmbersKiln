"""Serial Boss relic verification in a fully isolated project and user directory."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--reuse", type=Path)
    parser.add_argument("--render", action="store_true")
    parser.add_argument("--suite", default="boss")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    (root / "Temp").mkdir(exist_ok=True)
    sandbox = args.reuse.resolve() if args.reuse else Path(tempfile.mkdtemp(prefix="boss-relic-verify-", dir=root / "Temp"))
    if not sandbox.is_relative_to(root / "Temp"):
        raise ValueError("Verification copy must stay inside project Temp")
    print(f"Verification directory: {sandbox}", flush=True)
    for folder in ("scripts", "scenes", "data", "themes"):
        shutil.copytree(root / folder, sandbox / folder, dirs_exist_ok=True)
    if not args.reuse:
        shutil.copytree(root / "art", sandbox / "art", ignore=shutil.ignore_patterns("candidates", "*.gif", "*.psd", "*.blend", "*source", "palette_source"))
        if (root / ".godot/imported").exists():
            shutil.copytree(root / ".godot/imported", sandbox / ".godot/imported")
    else:
        shutil.copytree(root / "art/icons/relic", sandbox / "art/icons/relic", dirs_exist_ok=True)
    shutil.copytree(root / "art/icons/rewards", sandbox / "art/icons/rewards", dirs_exist_ok=True)
    config = (root / "project.godot").read_text(encoding="utf-8")
    config = config.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\n' + f'config/custom_user_dir_name="{sandbox.as_posix()}/userdata"')
    config = re.sub(r'^(TestBridge|_mcp_game_helper)=.*\n', '', config, flags=re.M)
    config = re.sub(r'^enabled=PackedStringArray\(.*\)', 'enabled=PackedStringArray()', config, flags=re.M)
    (sandbox / "project.godot").write_text(config, encoding="utf-8")
    (sandbox / "Temp").mkdir(exist_ok=True)
    env = os.environ.copy()
    env["APPDATA"] = str(sandbox / "appdata")
    env["LOCALAPPDATA"] = str(sandbox / "localappdata")
    env["BOSS_RELIC_TEST_ROOT"] = str(sandbox)
    env["RELIC_ONCE_TEST_APPDATA"] = env["APPDATA"]
    godot = Path(args.godot).resolve()
    # The Windows console launcher spawns a second process. Run the engine itself
    # so waiting/timeout tracks its actual lifetime, not just its wrapper.
    if godot.name.endswith("_console.exe"):
        engine = godot.with_name(godot.name.replace("_console.exe", ".exe"))
        if engine.exists(): godot = engine
    base = [str(godot), "--path", str(sandbox)]
    def run(name, command, marker=None):
        result = subprocess.run(base + ["--log-file", str(sandbox / (name + ".log"))] + command, env=env,
                                capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300,
                                startupinfo=startupinfo)
        output = result.stdout + result.stderr
        (sandbox / (name + "-output.log")).write_text(output, encoding="utf-8")
        bad = any(x in output for x in ("SCRIPT ERROR", "Parse Error", "Compile Error", "SHADER ERROR"))
        if result.returncode or bad or marker and marker not in output:
            print(output, flush=True)
            raise SystemExit(1)
        print("\n".join(line for line in output.splitlines() if "RESULT" in line or "[FAIL]" in line or "ERROR" in line), flush=True)
        print(name + " completed", flush=True)
    startupinfo = None
    if os.name == "nt":
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupinfo.wShowWindow = subprocess.SW_HIDE
    run("import", ["--headless", "--editor", "--import"])
    suites = {
        "shards": ("res://scenes/verify/UpgradeShardVerify.tscn", "UPGRADE_SHARD_RESULT:PASS"),
        "boss": ("res://scenes/verify/BossRelicVerify.tscn", "BOSS_RELIC_RESULT:PASS"),
        "queue": ("res://scenes/verify/CardPlayQueueVerify.tscn", "CARD_QUEUE_RESULT:PASS"),
        "cards": ("res://scenes/verify/IroncladCardPoolVerify.tscn", "IRONCLAD_CARD_POOL_RESULT:PASS"),
        "act": ("res://scenes/combat/ActVerify.tscn", "ACT_RESULT:PASS"),
        "combat": ("res://scenes/combat/CombatTest.tscn", "SMOKE_RESULT:PASS"),
    }
    selected = list(suites) if args.suite == "all" else [args.suite]
    for suite in selected:
        scene, marker = suites[suite]
        render = args.render and suite in ("boss", "shards")
        options = ["--resolution", "720x1280", "--rendering-method", "gl_compatibility", "--audio-driver", "Dummy"] if render else ["--headless"]
        if suite in ("act", "combat"): options += ["--quit-after", "240"]
        options += [scene]
        if render: options += ["--", "--visual"]
        run(suite + ("-visual" if render else ""), options, marker)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

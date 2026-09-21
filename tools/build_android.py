"""Build an internal ARM64 APK in an isolated project copy.

Requires matching Godot Android templates plus an Android SDK with platform-tools
and build-tools. No editor plugins, MCP autoloads or player saves enter the copy.
"""
import argparse
import fnmatch
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from android_assets import AndroidAssets, apply_export_filters, verify_apk

ERRORS = ("SCRIPT ERROR", "SHADER ERROR", "Parse Error", "Compile Error", "ERROR:")


def run(command, env, log, timeout=600):
    result = subprocess.run(command, env=env, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=timeout)
    output = result.stdout + result.stderr
    log.write_text(output, encoding="utf-8")
    print(output[-7000:], flush=True)
    if result.returncode or any(marker in output for marker in ERRORS):
        raise RuntimeError(f"Command failed; see {log}")
    return output


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--sdk", required=True, type=Path)
    parser.add_argument("--java", required=True, type=Path)
    parser.add_argument("--templates", required=True, type=Path)
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args()
    workspace = Path(__file__).resolve().parents[1]
    output = workspace / "outputs/android"
    output.mkdir(parents=True, exist_ok=True)
    (workspace / "outputs/.gdignore").touch()
    stage = Path(tempfile.mkdtemp(prefix="android-build-", dir=workspace / "Temp"))
    print(f"Build directory: {stage}", flush=True)

    preset_source = (workspace / "export_presets.cfg").read_text(encoding="utf-8")
    policy = json.loads((workspace / "tools/android_assets.json").read_text(encoding="utf-8"))
    preset_source = apply_export_filters(preset_source, policy)
    exclusions = re.search(r'exclude_filter="(.*)"', preset_source).group(1).split(",")
    art_exclusions = [p for p in exclusions if p.startswith("art/")]
    assets = AndroidAssets(workspace, exclusions)

    def ignore(directory, names):
        if ".gdignore" in names:
            return names
        return [name for name in names if name.endswith((".zip", ".gif", ".py", ".md", ".html", ".TMP"))
                or name == "__pycache__" or assets.omit((Path(directory) / name).relative_to(workspace).as_posix()) or any(fnmatch.fnmatchcase((Path(directory) / name).relative_to(workspace).as_posix(), pattern) for pattern in art_exclusions)]

    for folder in ("scripts", "scenes", "art", "data", "themes"):
        shutil.copytree(workspace / folder, stage / folder, ignore=ignore)
    assets.configure_imports(stage)
    # Copy only cached imports belonging to assets in this build.
    for sidecar in stage.rglob("*.import"):
        if sidecar.relative_to(stage).as_posix().removesuffix(".import") in assets.reimport:
            continue  # A changed import recipe must not reuse the old texture cache.
        for relative in re.findall(r'res://(\.godot/imported/[^"\n]+)', sidecar.read_text(encoding="utf-8")):
            source = workspace / relative
            target = stage / relative
            if source.is_file() and not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
                checksum = source.with_suffix(".md5")
                if checksum.is_file():
                    shutil.copy2(checksum, target.with_suffix(".md5"))

    config = (workspace / "project.godot").read_text(encoding="utf-8")
    config = re.sub(r'^(?:TestBridge|_mcp_game_helper)=.*\n', '', config, flags=re.M)
    config = re.sub(r'^enabled=PackedStringArray\(.*\)', 'enabled=PackedStringArray()', config, flags=re.M)
    (stage / "project.godot").write_text(config, encoding="utf-8")
    preset = preset_source
    preset_name = re.search(r'^name="([^"]+)"', preset, re.M).group(1)
    for mode in ("debug", "release"):
        template = (args.templates / f"android_{mode}.apk").resolve().as_posix()
        preset = re.sub(rf'^custom_template/{mode}=.*$', f'custom_template/{mode}="{template}"', preset, flags=re.M)
    (stage / "export_presets.cfg").write_text(preset, encoding="utf-8")
    env = os.environ.copy()
    env["APPDATA"] = str(stage / "appdata")
    env["LOCALAPPDATA"] = str(stage / "localappdata")
    env["JAVA_HOME"] = str(args.java.resolve())
    env["ANDROID_HOME"] = str(args.sdk.resolve())
    env["PATH"] = str(args.java.resolve() / "bin") + os.pathsep + env.get("PATH", "")
    for directory in (stage / "appdata", stage / "localappdata"):
        directory.mkdir(parents=True, exist_ok=True)
        (directory / ".gdignore").touch()
    settings = stage / "appdata/Godot/editor_settings-4.7.tres"
    settings.parent.mkdir(parents=True, exist_ok=True)
    key = output / "debug.keystore"
    settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
                        f'export/android/java_sdk_path = "{args.java.resolve().as_posix()}"\n'
                        f'export/android/android_sdk_path = "{args.sdk.resolve().as_posix()}"\n'
                        f'export/android/debug_keystore = "{key.as_posix()}"\n'
                        'export/android/debug_keystore_user = "androiddebugkey"\n'
                        'export/android/debug_keystore_pass = "android"\n', encoding="utf-8")
    base = [str(args.godot.resolve()), "--path", str(stage)]
    run(base + ["--headless", "--editor", "--import", "--log-file", str(stage / "import.log")],
        env, stage / "import-output.log")
    verify_config = config.replace('[display]', 'AndroidVerify="*res://scripts/verify/AndroidVerify.gd"\n\n[display]')
    (stage / "project.godot").write_text(verify_config, encoding="utf-8")
    rendering = ["--resolution", "720x1280", "--position", "-3000,-3000", "--audio-driver", "Dummy"] if args.render else ["--headless"]
    try:
        result = run(base + rendering + ["--log-file", str(stage / "verify.log"), "--", "--android-verify"],
                     env, stage / "verify-output.log", timeout=120)
        if "ANDROID_RESULT:PASS" not in result:
            raise RuntimeError("Android regression checks did not complete")
    finally:
        (stage / "project.godot").write_text(config, encoding="utf-8")
    if args.verify_only:
        print("ANDROID_VERIFY_COMPLETE", flush=True)
        return
    if not key.exists():
        run([str(args.java.resolve() / "bin/keytool.exe"), "-genkeypair", "-keystore", str(key),
             "-storepass", "android", "-keypass", "android", "-alias", "androiddebugkey",
             "-dname", "CN=Android Debug,O=Android,C=US", "-keyalg", "RSA", "-keysize", "2048",
             "-validity", "10000"], env, stage / "keytool.log")
    apk = output / "embers-kiln-internal.apk"
    run(base + ["--headless", "--editor", "--export-debug", preset_name, str(apk),
                "--log-file", str(stage / "export.log")], env, stage / "export-output.log", timeout=900)
    verify_apk(apk, workspace, exclusions)
    print(f"APK_READY: {apk} ({apk.stat().st_size / 1048576:.1f} MiB)", flush=True)


if __name__ == "__main__":
    main()

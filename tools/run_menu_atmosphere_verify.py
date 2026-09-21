"""Run serial menu render/navigation checks with isolated user saves.

Stop the project's editor play session before running this command.
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--record", action="store_true")
    parser.add_argument("--logo", action="store_true", help="Verify the title and its interaction with the existing menu")
    parser.add_argument("--navigation", action="store_true")
    parser.add_argument("--renderer", default="mobile", choices=["mobile", "gl_compatibility"])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = root / "Temp/menu_atmosphere_verify"
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["APPDATA"] = str(output / "appdata")
    env["LOCALAPPDATA"] = str(output / "localappdata")
    Path(env["APPDATA"]).mkdir(exist_ok=True)
    Path(env["LOCALAPPDATA"]).mkdir(exist_ok=True)
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = subprocess.SW_HIDE
    engine = Path(args.godot)
    if engine.name.endswith("_console.exe"):
        engine = engine.with_name(engine.name.replace("_console.exe", ".exe"))

    def run(name, options, marker=None):
        command = [str(engine), "--path", str(root), "--log-file", str(output / (name + ".log"))] + options
        result = subprocess.run(command, env=env, capture_output=True, text=True,
                                encoding="utf-8", errors="replace", startupinfo=startup, timeout=180)
        text = result.stdout + result.stderr
        (output / (name + "-output.log")).write_text(text, encoding="utf-8")
        # This host's certificate-store error is unrelated to offline rendering.
        error_lines = [line for line in text.splitlines() if "ERROR:" in line
                       and "Failed to read the root certificate store" not in line]
        errors = ("Parse Error", "Shader compilation failed", "[FAIL]")
        if result.returncode or error_lines or any(e in text for e in errors) or (marker and marker not in text):
            print(text, flush=True)
            raise SystemExit(result.returncode or 1)
        print("\n".join(line for line in text.splitlines() if any(s in line for s in ("[PASS]", "RESULT", "PIXEL_DELTA"))), flush=True)
        print(name + " completed", flush=True)

    run("import", ["--headless", "--editor", "--import"])
    if args.logo:
        logo_options = ["--rendering-method", args.renderer, "--audio-driver", "Dummy", "--resolution", "720x1280",
                        "res://scenes/verify/MainMenuLogoVerify.tscn"]
        if args.record:
            logo_options += ["--", "--record"]
        run("logo-" + args.renderer, logo_options, "MENU_LOGO_RESULT FAIL=0")
    options = ["--rendering-method", args.renderer, "--audio-driver", "Dummy", "--resolution", "720x1280",
               "res://scenes/verify/MainMenuAtmosphereVerify.tscn"]
    if args.record and not args.logo:
        options += ["--", "--record"]
    run("atmosphere-" + args.renderer, options, "MENU_ATMOSPHERE_RESULT FAIL=0")
    if args.record and not args.logo:
        subprocess.run([sys.executable, str(root / "tools/verify_menu_smoke_motion.py")], check=True)
    if args.navigation:
        run("navigation", ["--headless", "res://scenes/verify/MenuEntryFlowVerify.tscn"], "MENU_ENTRY_FLOW_RESULT FAIL=0")


if __name__ == "__main__":
    main()

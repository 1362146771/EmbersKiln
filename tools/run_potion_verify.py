"""Verify potion stacking, inventory and drag interactions in an isolated Godot copy."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='F:/app/Godot_v4.7.1-stable_win64.exe')
    parser.add_argument('--stage', choices=('all', 'effects', 'acquire', 'drag'), default='all')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    sandbox = root / 'Temp/potion-rules-verify'
    sandbox.mkdir(parents=True, exist_ok=True)

    def copy_changed(source, destination):
        src, dst = Path(source), Path(destination)
        if not dst.exists() or (src.stat().st_size, src.stat().st_mtime_ns) != (dst.stat().st_size, dst.stat().st_mtime_ns):
            shutil.copy2(src, dst)
        return str(dst)

    for folder in ('scripts', 'scenes', 'data', 'themes', 'art'):
        shutil.copytree(root / folder, sandbox / folder, dirs_exist_ok=True, copy_function=copy_changed,
                        ignore=shutil.ignore_patterns('candidates', '*.gif', '*.psd', '*.blend', '*source', 'palette_source'))
    if not (sandbox / '.godot/imported').exists() and (root / '.godot/imported').exists():
        shutil.copytree(root / '.godot/imported', sandbox / '.godot/imported')
    config = (root / 'project.godot').read_text(encoding='utf-8')
    config = config.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\n' +
                            f'config/custom_user_dir_name="{sandbox.as_posix()}/userdata"')
    config = re.sub(r'^(TestBridge|_mcp_game_helper)=.*\n', '', config, flags=re.M)
    config = re.sub(r'^enabled=PackedStringArray\(.*\)', 'enabled=PackedStringArray()', config, flags=re.M)
    (sandbox / 'project.godot').write_text(config, encoding='utf-8')
    (sandbox / 'Temp').mkdir(exist_ok=True)
    env = dict(os.environ, APPDATA=str(sandbox / 'appdata'), LOCALAPPDATA=str(sandbox / 'localappdata'))
    startup = None
    if os.name == 'nt':
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = subprocess.SW_HIDE

    def run(name, options, marker='', graphical=False):
        print('Running ' + name, flush=True)
        display = ['--resolution', '720x1280', '--rendering-method', 'gl_compatibility'] if graphical else ['--headless']
        result = subprocess.run([args.godot, '--audio-driver', 'Dummy', '--path', str(sandbox),
                                 '--log-file', str(sandbox / (name + '.log'))] + display + options,
                                env=env, capture_output=True, text=True, encoding='utf-8', errors='replace',
                                startupinfo=startup, timeout=300)
        output = result.stdout + result.stderr
        (sandbox / (name + '-output.log')).write_text(output, encoding='utf-8')
        engine_errors = [line for line in output.splitlines() if 'ERROR:' in line
                         and 'Failed to read the root certificate store.' not in line
                         and not re.search(r'ERROR: \d+ resources still in use at exit', line)]
        bad = result.returncode or engine_errors or '[FAIL]' in output or any(token in output for token in (
            'SCRIPT ERROR', 'Parse Error', 'Compile Error', 'SHADER ERROR')) or (marker and marker not in output)
        print('\n'.join(line for line in output.splitlines()
                        if any(token in line for token in ('[PASS]', '[FAIL]', 'RESULT', 'VERIFY_DONE', 'ERROR', 'WARNING'))), flush=True)
        if bad:
            raise SystemExit(1)
        if 'leaked at exit' in output or 'resources still in use at exit' in output:
            print(name + ': assertions passed; exit resource warnings remain', flush=True)

    # Each subprocess exits before the next starts. No production saves, ports or import cache are shared.
    run('import', ['--editor', '--import'])
    for name, scene, marker in (
        ('effects', 'PotionEnchantVerify', '[PE_VERIFY_DONE] ALL PASS'),
        ('acquire', 'PotionEnchantAcquireVerify', '[ACQUIRE_VERIFY_DONE] ALL PASS'),
        ('drag', 'PotionDragVerify', 'POTION_DRAG_RESULT: PASS'),
    ):
        if args.stage not in ('all', name):
            continue
        run(name, ['--quit-after', '600', f'res://scenes/verify/{scene}.tscn'], marker, graphical=name == 'drag')
    print('POTION_SUITE:PASS\nArtifacts: ' + str(sandbox), flush=True)


if __name__ == '__main__':
    main()

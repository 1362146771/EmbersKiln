"""Verify special enemy icons serially with isolated saves, imports and logs."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='F:/app/Godot_v4.7.1-stable_win64.exe')
    parser.add_argument('--render', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    sandbox = root / 'Temp/enemy-special-icon-verify'
    sandbox.mkdir(parents=True, exist_ok=True)
    for folder in ('scripts', 'scenes', 'data', 'themes', 'art'):
        shutil.copytree(root/folder, sandbox/folder, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns('candidates', 'review_v1', '*.gif', '*.psd', '*.blend', 'source', 'palette_source'))
    if (root/'.godot/imported').exists():
        shutil.copytree(root/'.godot/imported', sandbox/'.godot/imported', dirs_exist_ok=True)
    config = (root/'project.godot').read_text(encoding='utf-8')
    config = config.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\n' +
                            f'config/custom_user_dir_name="{sandbox.as_posix()}/userdata"')
    config = re.sub(r'^(TestBridge|_mcp_game_helper)=.*\n', '', config, flags=re.M)
    config = re.sub(r'^enabled=PackedStringArray\(.*\)', 'enabled=PackedStringArray()', config, flags=re.M)
    (sandbox/'project.godot').write_text(config, encoding='utf-8')
    (sandbox/'Temp').mkdir(exist_ok=True)
    env = dict(os.environ, APPDATA=str(sandbox/'appdata'), LOCALAPPDATA=str(sandbox/'localappdata'), ESCORT_TEST_APPDATA=sandbox.as_posix())
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = subprocess.SW_HIDE

    def run(name, options, marker=''):
        print('Running ' + name, flush=True)
        result = subprocess.run([args.godot, '--path', str(sandbox), '--log-file', str(sandbox/(name+'.log'))] + options,
                                env=env, capture_output=True, text=True, encoding='utf-8', errors='replace',
                                startupinfo=startup, timeout=300)
        output = result.stdout + result.stderr
        (sandbox/(name+'-output.log')).write_text(output, encoding='utf-8')
        if result.returncode or any(x in output for x in ('SCRIPT ERROR', 'Parse Error', 'Compile Error', 'SHADER ERROR')) or marker and marker not in output:
            print(output, flush=True)
            raise SystemExit(1)
        print('\n'.join(x for x in output.splitlines() if 'RESULT' in x or '[FAIL]' in x or 'failures' in x), flush=True)

    run('import', ['--headless', '--editor', '--import'])
    opts = ['--resolution', '720x1280', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy'] if args.render else ['--headless']
    run('enemy-special-icons', opts + ['res://scenes/verify/EnemySpecialIconVerify.tscn'] + (['--', '--visual'] if args.render else []), 'ENEMY_SPECIAL_ICON_RESULT:PASS')
    run('status-icons', ['--headless', 'res://scenes/verify/StatusIconVerify.tscn'], 'STATUS_ICON_VERIFY: 0 failures')
    run('boss-pressure', ['--headless', 'res://scenes/verify/BossPressureVerify.tscn'], 'BOSS_PRESSURE_RESULT:PASS')
    run('escort-elite', ['--headless', 'res://scenes/verify/EscortEliteVerify.tscn'], 'ESCORT_ELITE_RESULT:PASS')
    if args.render:
        output = root/'outputs/qa/enemy-special-icons'
        output.mkdir(parents=True, exist_ok=True)
        for capture in (sandbox/'Temp').glob('enemy_special_*.png'):
            shutil.copy2(capture, output/capture.name)


if __name__ == '__main__':
    main()

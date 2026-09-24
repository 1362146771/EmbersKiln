"""Run UI, pose and hit-rest regressions serially in an isolated project copy.

Usage: python tools/run_combat_regression.py --render
Use --stage ui / pose / feedback to verify one stage while fixing a regression.
"""
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
    parser.add_argument('--stage', choices=('ui', 'pose', 'feedback', 'all'), default='all')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    sandbox = root / 'Temp/combat-regression-verify'
    sandbox.mkdir(parents=True, exist_ok=True)

    def copy_changed(source, destination):
        src, dst = Path(source), Path(destination)
        if not dst.exists() or (src.stat().st_size, src.stat().st_mtime_ns) != (dst.stat().st_size, dst.stat().st_mtime_ns):
            shutil.copy2(src, dst)
        return str(dst)

    for folder in ('scripts', 'scenes', 'data', 'themes', 'art'):
        shutil.copytree(root/folder, sandbox/folder, dirs_exist_ok=True, copy_function=copy_changed)
    if not (sandbox/'.godot/imported').exists() and (root/'.godot/imported').exists():
        shutil.copytree(root/'.godot/imported', sandbox/'.godot/imported')
    config = (root/'project.godot').read_text(encoding='utf-8')
    config = config.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\n' +
                            f'config/custom_user_dir_name="{sandbox.as_posix()}/userdata"')
    config = re.sub(r'^(TestBridge|_mcp_game_helper)=.*\n', '', config, flags=re.M)
    config = re.sub(r'^enabled=PackedStringArray\(.*\)', 'enabled=PackedStringArray()', config, flags=re.M)
    (sandbox/'project.godot').write_text(config, encoding='utf-8')
    (sandbox/'Temp').mkdir(exist_ok=True)
    env = dict(os.environ, APPDATA=str(sandbox/'appdata'), LOCALAPPDATA=str(sandbox/'localappdata'))
    startup = None
    if os.name == 'nt':
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = subprocess.SW_HIDE

    def run(name, options, marker=''):
        print('Running ' + name, flush=True)
        result = subprocess.run([args.godot, '--verbose', '--path', str(sandbox), '--log-file', str(sandbox/(name+'.log'))] + options,
                                env=env, capture_output=True, text=True, encoding='utf-8', errors='replace',
                                startupinfo=startup, timeout=300)
        output = result.stdout + result.stderr
        (sandbox/(name+'-output.log')).write_text(output, encoding='utf-8')
        if result.returncode or 'ERROR:' in output or '[FAIL]' in output or marker and marker not in output:
            print('\n'.join(line for line in output.splitlines() if any(token in line for token in ('[FAIL]', 'ERROR', 'WARNING', 'RESULT', 'Leaked instance:', 'Resource still in use:', ' at:'))), flush=True)
            raise SystemExit(1)
        print('\n'.join(line for line in output.splitlines() if 'RESULT' in line or 'failures' in line or '[P0Verify]' in line), flush=True)

    run('import', ['--headless', '--editor', '--import'])
    opts = ['--resolution', '720x1280', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy'] if args.render else ['--headless']
    suites = {
        'ui': [('formal-ui', 'verify/FormalBattleUIVerify', 'FORMAL_BATTLE_RESULT FAIL=0'),
               ('p0', 'combat/P0Verify', '[P0Verify] RESULT=PASS')],
        'pose': [('pose', 'combat/PoseVerify', 'POSE_RESULT:PASS'),
                 ('death', 'verify/PlayerDeathVerify', 'PLAYER_DEATH_RESULT:PASS')],
        'feedback': [('feedback', 'combat/CombatFeedbackVerify', 'FEEDBACK_RESULT:PASS')],
    }
    for stage, entries in suites.items():
        if args.stage not in ('all', stage):
            continue
        for name, scene, marker in entries:
            run(name, opts + [f'res://scenes/{scene}.tscn'] + (['--', '--visual'] if args.render else []), marker)
    print('Artifacts: ' + str(sandbox), flush=True)


if __name__ == '__main__':
    main()

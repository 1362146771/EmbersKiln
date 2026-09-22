"""Serial narrative, profile and menu verification in an isolated Godot project."""
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
    parser.add_argument('--run-fixture', type=Path, help='Read-only copy of a run save for town departure regression')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    sandbox = root / 'Temp/difficulty-progression-verify'
    sandbox.mkdir(parents=True, exist_ok=True)
    for folder in ('scripts', 'scenes', 'data', 'themes', 'art'):
        shutil.copytree(root/folder, sandbox/folder, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns('candidates', '*.gif', '*.psd', '*.blend', '*source', 'palette_source'))
    for obsolete in ('scripts/meta/GrannyDialogueUI.gd', 'scripts/meta/GrannyDialogueUI.gd.uid', 'scenes/town/GrannyDialogue.tscn', 'scripts/meta/DifficultySelectionUI.gd', 'scripts/meta/DifficultySelectionUI.gd.uid', 'scenes/main/DifficultySelection.tscn'):
        (sandbox/obsolete).unlink(missing_ok=True)
    if (root/'.godot/imported').exists():
        shutil.copytree(root/'.godot/imported', sandbox/'.godot/imported', dirs_exist_ok=True)
    config = (root/'project.godot').read_text(encoding='utf-8')
    config = config.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\n' +
                            f'config/custom_user_dir_name="{sandbox.as_posix()}/userdata"')
    config = re.sub(r'^(TestBridge|_mcp_game_helper)=.*\n', '', config, flags=re.M)
    config = re.sub(r'^enabled=PackedStringArray\(.*\)', 'enabled=PackedStringArray()', config, flags=re.M)
    (sandbox/'project.godot').write_text(config, encoding='utf-8')
    (sandbox/'Temp').mkdir(exist_ok=True)
    fixture = sandbox/'Temp/town_departure_fixture.json'
    if args.run_fixture:
        shutil.copy2(args.run_fixture, fixture)
    else:
        fixture.unlink(missing_ok=True)
    env = dict(os.environ, APPDATA=str(sandbox/'appdata'), LOCALAPPDATA=str(sandbox/'localappdata'))
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
        print('\n'.join(x for x in output.splitlines() if 'RESULT' in x or '[FAIL]' in x), flush=True)
    run('import', ['--headless', '--editor', '--import'])
    opts = ['--resolution', '720x1280', '--rendering-method', 'gl_compatibility', '--audio-driver', 'Dummy'] if args.render else ['--headless']
    run('difficulty-progression', opts + ['--quit-after', '600', 'res://scenes/verify/DifficultyProgressionVerify.tscn'] + (['--', '--visual'] if args.render else []), 'DIFFICULTY_PROGRESSION_RESULT:PASS')
    run('difficulty-baseline', ['--headless', '--quit-after', '240', 'res://scenes/combat/DifficultyVerify.tscn'], 'DIFF_RESULT:PASS')
    run('granny', ['--headless', '--quit-after', '2400', 'res://scenes/verify/GrannyDialogueVerify.tscn'], 'GRANNY_RESULT:PASS')
    run('menu', ['--headless', '--quit-after', '3600', 'res://scenes/verify/MenuEntryFlowVerify.tscn'], 'MENU_ENTRY_FLOW_RESULT FAIL=0')
    run('profile', ['--headless', '--quit-after', '240', 'res://scenes/verify/ProfilePersistenceVerify.tscn'], 'PROFILE_RESULT:PASS')
    if args.render:
        output = root/'outputs/qa/difficulty'
        output.mkdir(parents=True, exist_ok=True)
        for image in (sandbox/'Temp').glob('difficulty_*.png'):
            shutil.copy2(image, output/image.name)
    print('DIFFICULTY_SUITE:PASS', flush=True)


if __name__ == '__main__':
    main()

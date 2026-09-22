"""Serial Godot audio regression in a separate project/user-data/cache directory."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='F:/app/Godot_v4.7.1-stable_win64.exe')
    parser.add_argument('--import-only', action='store_true')
    parser.add_argument('--render', action='store_true')
    parser.add_argument('--touch', action='store_true', help='Enable touchscreen emulation in the isolated project')
    parser.add_argument('--rendering-method', default='gl_compatibility', choices=['gl_compatibility', 'mobile'])
    parser.add_argument('--resolution', default='720x1280')
    parser.add_argument('--only', nargs='+', choices=['audio','settings','scroll','card-queue','potion','death','haptics'])
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    sandbox = root / 'Temp/audio-verify'
    sandbox.mkdir(parents=True, exist_ok=True)
    (sandbox/'Temp').mkdir(exist_ok=True)
    for folder in ('scripts', 'scenes', 'data', 'themes'):
        shutil.copytree(root/folder, sandbox/folder, dirs_exist_ok=True)
    def copy_art(source, target):
        # Raw art is only read by Godot; generated import metadata remains separate.
        if Path(target).exists():
            if os.path.samefile(source, target): return target
            return shutil.copy2(source, target)
        if Path(source).suffix == '.import': return shutil.copy2(source, target)
        try: os.link(source, target)
        except OSError: shutil.copy2(source, target)
        return target
    shutil.copytree(root/'art', sandbox/'art', dirs_exist_ok=True, copy_function=copy_art,
                    ignore=shutil.ignore_patterns('review_v1','candidates','*.gif','*.psd','*.blend','*source','palette_source'))
    if (root/'.godot/imported').exists():
        shutil.copytree(root/'.godot/imported', sandbox/'.godot/imported', dirs_exist_ok=True)
    config = (root/'project.godot').read_text(encoding='utf-8')
    config = config.replace('[application]', '[application]\nconfig/use_custom_user_dir=true\n' +
                            f'config/custom_user_dir_name="{sandbox.as_posix()}/userdata"')
    config = re.sub(r'^(TestBridge|_mcp_game_helper)=.*\n', '', config, flags=re.M)
    config = re.sub(r'^enabled=PackedStringArray\(.*\)', 'enabled=PackedStringArray()', config, flags=re.M)
    if args.touch:
        config += '\n[input_devices]\npointing/emulate_touch_from_mouse=true\npointing/emulate_mouse_from_touch=true\n'
    (sandbox/'project.godot').write_text(config, encoding='utf-8')
    env = dict(os.environ, APPDATA=str(sandbox/'appdata'), LOCALAPPDATA=str(sandbox/'localappdata'))
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = subprocess.SW_HIDE
    def run(name, options, marker=''):
        if name != 'import' and args.only and name not in args.only: return
        print('Running '+name, flush=True)
        result = subprocess.run([args.godot, '--path', str(sandbox), '--log-file', str(sandbox/(name+'.log'))]+options,
                                env=env, capture_output=True, text=True, encoding='utf-8', errors='replace',
                                startupinfo=startup, timeout=300)
        output = result.stdout+result.stderr
        (sandbox/(name+'-output.log')).write_text(output, encoding='utf-8')
        if result.returncode or any(s in output for s in ['SCRIPT ERROR','Parse Error','Compile Error','SHADER ERROR']) or marker and marker not in output:
            print(f'{name} exit={result.returncode}; expected={marker}', flush=True)
            lines = output.splitlines()
            failures = [i for i,line in enumerate(lines) if any(s in line for s in ['ERROR','Error','[FAIL]'])]
            print('\n'.join(lines[i] for index in failures for i in range(max(0,index-1),min(len(lines),index+5))) if failures else output[-5000:], flush=True)
            raise SystemExit(1)
        print('\n'.join(s for s in output.splitlines() if 'RESULT' in s or '[FAIL]' in s), flush=True)
    run('import', ['--headless','--editor','--import'])
    if args.import_only: return
    runtime=['--headless'] if not args.render else ['--resolution',args.resolution,'--rendering-method',args.rendering_method,'--audio-driver','Dummy']
    if args.touch or args.only and 'scroll' in args.only:
        run('scroll',runtime+['--quit-after','18000','res://scenes/verify/MobileScrollVerify.tscn'],'MOBILE_SCROLL_RESULT:PASS')
    run('settings',runtime+['--quit-after','3000','res://scenes/verify/SettingsVerify.tscn'],'SETTINGS_RESULT:PASS')
    run('audio',runtime+['--quit-after','18000','res://scenes/verify/AudioVerify.tscn'],'AUDIO_RESULT:PASS')
    for name,scene,marker in [
        ('haptics','HapticVerify','HAPTIC_RESULT:PASS'),
        ('card-queue','CardPlayQueueVerify','CARD_QUEUE_RESULT:PASS'),
        ('potion','PotionDragVerify','POTION_DRAG_RESULT: PASS'),
        ('death','PlayerDeathVerify','PLAYER_DEATH_RESULT:PASS'),
    ]:
        run(name,['--headless','--quit-after','6000',f'res://scenes/verify/{scene}.tscn'],marker)
    print('AUDIO_SUITE:PASS',flush=True)


if __name__ == '__main__': main()

"""Promote the user-approved SFX set and build the small runtime cue map."""
from pathlib import Path
import json
import hashlib
import shutil

ROOT = Path(__file__).resolve().parents[2]
review = ROOT / 'art/audio/review_v1'
manifest = json.loads((review / 'manifest.json').read_text(encoding='utf-8'))
dest = ROOT / 'art/audio/sfx'
dest.mkdir(exist_ok=True)
config = {
    'version': 1,
    'voices': 12,
    'default_volumes': {'Master': 0.85, 'SFX': 1.0, 'Ambience': 0.55},
    'ambience_fade_seconds': 0.65,
    'cues': {}, 'enemies': {},
    'enchant_profiles': {
        'kiln_cleave': 'enchant_cleave', 'furnace_wave': 'enchant_flame', 'harvest_arc': 'enchant_reap',
        'carnage': 'enchant_cleave', 'uppercut': 'enchant_cleave', 'searing_blow': 'enchant_flame',
        'fiend_fire': 'enchant_flame', 'sever_soul': 'enchant_reap', 'blood_for_blood': 'enchant_cleave',
    },
    'scene_ambience': {
        'MainMenu.tscn': 'amb_menu', 'Town.tscn': 'amb_town',
        'PreRunPreparation.tscn': 'amb_town', 'PreRunAdPreparation.tscn': 'amb_town',
        'RestUI.tscn': 'amb_rest', 'HiddenActEntrance.tscn': 'amb_hidden',
    },
    'scene_cues': {'TreasureUI.tscn': 'chest_open', 'EventUI.tscn': 'event_enter',
                   'RewardUI.tscn': 'reward_open', 'HiddenActEntrance.tscn': 'hidden_open'},
    'act_ambience': ['amb_act1', 'amb_act2', 'amb_act3', 'amb_hidden'],
    'button_cues': {
        'ResumeButton': 'pause_close', 'CompendiumButton': 'ui_open',
        'CancelAbandonButton': 'ui_cancel', 'ConfirmAbandonButton': 'ui_confirm',
        'BackButton': 'ui_cancel', 'CloseButton': 'ui_close',
        'EndTurnButton': '', 'PlayButton': 'ui_confirm',
        'PrevButton': 'ui_page', 'NextButton': 'ui_page',
    },
}
for cue in manifest['cues']:
    paths = []
    for f in cue['files']:
        source = review / f['file']
        assert hashlib.sha256(source.read_bytes()).hexdigest() == f['sha256']
        shutil.copy2(source, dest / source.name)
        paths.append('res://art/audio/sfx/' + source.name)
    ui = cue['group'] == '界面与地图'
    config['cues'][cue['id']] = {
        'files': paths, 'bus': 'Ambience' if cue['loop'] else 'UI' if ui else 'SFX',
        'loop': cue['loop'], 'cooldown': .08 if ui else .045,
        'gain_db': 0.0,
        'priority': 3 if cue['id'] in ['player_death', 'boss_death', 'victory', 'defeat', 'run_win'] else 1 if ui else 2,
    }
for item in manifest['coverage']:
    if item['group'] == '敌人':
        config['enemies'][item['id']] = {'hit': item['cues'][0],
            'moves': {k: v[0] for k, v in item['moves'].items()}}
(ROOT / 'data/audio.json').write_text(json.dumps(config, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(f"Installed {sum(len(c['files']) for c in config['cues'].values())} WAVs / {len(config['cues'])} cues")

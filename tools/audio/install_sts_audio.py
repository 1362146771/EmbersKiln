"""Install local STS assets and map existing presentation events; no gameplay changes."""
import argparse
import fnmatch
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]

# Cue groups share a semantic source. Wildcards select authored variations only.
SOUNDS = {
    'ui_click ui_toggle town_building': 'SOTE_SFX_UIClick_*_v2.wav',
    'ui_confirm pause_close loadout_select': 'SOTE_SFX_CardSelect_v2.ogg',
    'ui_cancel ui_close': 'SOTE_SFX_ShopRugClose_v1.ogg',
    'ui_open pause_open': 'SOTE_SFX_ViewDeck_v2.ogg',
    'ui_page event_enter': 'SOTE_SFX_UI_Parchment_*',
    'ui_deny': 'SOTE_SFX_CardReject_v1.ogg',
    'map_select': 'SOTE_SFX_MapSelect_*',
    'card_pickup card_return': 'SOTE_SFX_CardSelect_v2.ogg',
    'card_draw card_shuffle': 'STS_SFX_CardDeal8_v1.ogg',
    'card_attack': 'SOTE_SFX_FastAtk_v2.ogg',
    'card_skill energy_gain': 'SOTE_SFX_Buff_*',
    'card_power enchant_power': 'STS_SFX_Power_v1.ogg',
    'card_discard': 'SOTE_SFX_UI_Parchment_*',
    'card_exhaust card_remove': 'SOTE_SFX_ExhaustCard.ogg',
    'card_acquire card_copy card_recover reward_open': 'SOTE_SFX_ObtainCard_v2.ogg',
    'card_upgrade': 'SOTE_SFX_UpgradeCard_v1.ogg',
    'card_status burn_tick': 'STS_SFX_BurnCard_v1.ogg',
    'axe_swing': 'STS_SFX_EnemyAtk_Axe_v1.ogg',
    'axe_heavy': 'SOTE_SFX_HeavyAtk_v2.ogg',
    'hit_ceramic': 'SOTE_SFX_IronClad_Atk_RR*_v2.ogg',
    'hit_clay': 'SOTE_SFX_FastBlunt_v2.ogg',
    'hit_metal': 'STS_SFX_EnemyAtk_Sword_v1.ogg',
    'hit_stone': 'SOTE_SFX_HeavyBlunt_v2.ogg',
    'hit_ash': 'STS_SFX_PowerWoosh_v1.ogg',
    'player_hit self_damage': 'SOTE_SFX_Blood_*',
    'block_gain': 'SOTE_SFX_GainDefense_RR*_v3.ogg',
    'block_hit buffer_trigger': 'SOTE_SFX_BlockAtk_v2.ogg',
    'block_break enemy_interrupt': 'SOTE_SFX_DefenseBreak_v2.ogg',
    'heal status_anneal': 'SOTE_SFX_HealShort_*_v2.ogg',
    'turn_start': 'SOTE_SFX_PlayerTurn_v4_*.ogg',
    'turn_end': 'SOTE_SFX_EndTurn_v2.ogg',
    'heat_gain': 'SOTE_SFX_FireIgnite_*',
    'heat_burst heart_burst chi_echo': 'SOTE_SFX_BossOrbIgnite2_v2.ogg',
    'player_death defeat': 'STS_DeathStinger_v4_SFX.ogg',
    'enemy_death': 'STS_SFX_JawWormDefeat_v2.ogg',
    'combat_start': 'STS_SFX_BattleStart_[12]_v1.ogg',
    'thorns': 'STS_SFX_FlameBarrier_v2.ogg',
    'status_heat status_stoke': 'STS_SFX_Strength_v1.ogg',
    'status_temper': 'STS_SFX_Dexterity_v2.ogg',
    'status_crazed status_damp': 'SOTE_SFX_Debuff_*',
    'status_ashrot': 'STS_SFX_PoisonApply_v1.ogg',
    'status_glaze': 'STS_SFX_Metallicize_v2.ogg',
    'status_thirst': 'STS_SFX_VampireBite_v2.ogg',
    'status_cleanse': 'STS_SFX_Nullify_v1.ogg',
    'enemy_tackle': 'STS_SFX_ChampSlap_v2.ogg',
    'enemy_stab': 'STS_SFX_EnemyAtk_Dagger_v1.ogg',
    'enemy_claw heart_claw': 'STS_SFX_ByrdAtk[123]_v2.ogg',
    'enemy_bite': 'STS_SFX_VampireBite_v2.ogg',
    'enemy_wing': 'STS_SFX_Flight_v2.ogg',
    'enemy_fire matron_fire heart_scald ashen_burst': 'SOTE_SFX_BossGhostFireAtk_*',
    'enemy_slam matron_bar ashen_press': 'STS_SFX_Bludgeon_v1.ogg',
    'enemy_hex chi_reactive': 'STS_SFX_CollectorDebuff_v2.ogg',
    'enemy_charge heart_stoke boss_awaken': 'STS_SFX_ChampChargeUp_v2.ogg',
    'enemy_buff': 'SOTE_SFX_Buff_*',
    'enemy_summon': 'STS_SFX_CollectorSummon_v2.ogg',
    'enemy_steal gold_spend': 'SOTE_SFX_Gold_v1.ogg',
    'enemy_detonate': 'SOTE_SFX_BossOrbIgnite1_v2.ogg',
    'enemy_sweep': 'STS_SFX_EnemyAtk_Scythe_v1.ogg',
    'matron_seal': 'SOTE_SFX_BossBallTransform_v1.ogg',
    'matron_vent': 'STS_SFX_BGTorchExtinguish_v1.ogg',
    'matron_cool ashen_vent': 'STS_SFX_PiercingWail_v2.ogg',
    'heart_ward enchant_seal': 'STS_SFX_DonuDecaDefense_v2.ogg',
    'chi_slash': 'STS_SFX_AwakenedOne3Atk_v1.ogg',
    'chi_soul': 'SOTE_SFX_MagicFast_*',
    'chi_pounce': 'STS_SFX_AwakenedOnePounce_v2.ogg',
    'chi_sludge': 'STS_SFX_SlimedAtk_v2.ogg',
    'ashen_seal': 'STS_SFX_Shackled_v1.ogg',
    'ashen_backlash': 'STS_SFX_Constrict_v2.ogg',
    'boss_death': 'STS_SFX_Guardian3Destroy_v2.ogg',
    'enchant_cleave': 'STS_SFX_Bludgeon_v1.ogg',
    'enchant_flame': 'SOTE_SFX_GhostGuardianFlames_v1.ogg',
    'enchant_reap': 'STS_SFX_Reaper_v1.ogg',
    'enchant_rush': 'STS_SFX_Whirlwind_v2.ogg',
    'gold_gain': 'SOTE_SFX_Gold_RR*_v3.ogg',
    'fireseed_gain granny_blessing': 'STS_SFX_BonfireSpirits_v1.ogg',
    'relic_gain': 'SOTE_SFX_DropRelic_Magical.ogg',
    'relic_trigger': 'SOTE_SFX_RelicActivation_v1.ogg',
    'potion_gain': 'SOTE_SFX_DropPotion_*',
    'potion_use potion_splash': 'SOTE_SFX_Potion_*',
    'shard_gain': 'SOTE_SFX_DropRelic_Clink.ogg',
    'chest_open': 'SOTE_SFX_ChestOpen_v2.ogg',
    'victory': 'SOTE_SFX_Victory_v1.ogg',
    'act_clear': 'STS_BossVictoryStinger_1_v3_SFX.ogg',
    'run_win': 'music/STS_EndingStinger_v1.ogg',
    'revive': 'STS_SFX_DarklingRegrow_v2.ogg',
    'hidden_open transition_chapter': 'SOTE_SFX_DungeonGate.ogg',
    'transition_boss': 'STS_SFX_BattleStart_Boss_v1.ogg',
    'ad_reward town_build_ready': 'STS_NewUnlock_v1.ogg',
    'town_build_start': 'sts_sfx_shovel_v1.ogg',
    'town_upgrade town_reroll': 'STS_SFX_OminousForge_v1.ogg',
    'town_research': 'STS_SFX_AncientWriting_v1.ogg',
    'town_enchant altar_enchant': 'STS_SFX_ShiningLight_v1.ogg',
    'granny_dialogue': 'SOTE_SFX_SleepBlanket_v1.ogg',
    'rest_settle': 'STS_SleepJingle_1a_NewMix_v1.ogg',
    'shop_refresh': 'SOTE_SFX_ShopRugOpen_v1.ogg',
    'amb_menu': 'SOTE_SFX_WindAmb_v1.ogg',
    'amb_town amb_act2': 'SOTE_SFX_CityAmb_v1.ogg',
    'amb_act1': 'SOTE_Level1_Ambience_v6.ogg',
    'amb_act3': 'STS_SFX_BeyondAmb_v1.ogg',
    'amb_hidden': 'STS_SFX_LowRumble_Long_v4.ogg',
    'amb_rest': 'SOTE_SFX_RestFireDry_v2.ogg',
}
MUSIC = {
    'music_menu': 'STS_MenuTheme_NewMix_v1.ogg', 'music_town': 'STS_Merchant_NewMix_v1.ogg',
    'music_act1': 'STS_Level1_NewMix_v1.ogg', 'music_act2': 'STS_Level2_NewMix_v1.ogg',
    'music_act3': 'STS_Level3_v2.ogg', 'music_hidden': 'STS_Act4_BGM_v2.ogg',
    'music_boss1': 'STS_Boss1_NewMix_v1.ogg', 'music_boss2': 'STS_Boss2_NewMix_v1.ogg',
    'music_boss3': 'STS_Boss3_NewMix_v1.ogg', 'music_boss4': 'STS_Boss4_v6.ogg',
    'music_elite': 'STS_EliteBoss_NewMix_v1.ogg', 'music_rest': 'STS_Shrine_NewMix_v1.ogg',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('F:/WorkingFiles/123/STS'))
    args = parser.parse_args()
    manifest = json.loads((args.source/'manifest.json').read_text(encoding='utf-8'))
    available = {e['file']: e for e in manifest['files']}
    config = json.loads((ROOT/'data/audio.json').read_text(encoding='utf-8'))
    config['cues'] = {k:v for k,v in config['cues'].items() if v['bus'] != 'Music'}
    assigned = {}
    for ids, pattern in SOUNDS.items():
        full = 'audio/'+pattern if pattern.startswith('music/') else 'audio/sound/'+pattern
        matches = sorted(p for p in available if fnmatch.fnmatchcase(p, full))
        if not matches: raise ValueError('Missing source: '+full)
        for cue in ids.split():
            if cue in assigned: raise ValueError('Duplicate cue '+cue)
            assigned[cue] = matches
    assert set(assigned) == set(config['cues']), set(config['cues']) ^ set(assigned)
    for cue, filename in MUSIC.items():
        assigned[cue] = ['audio/music/'+filename]
        config['cues'][cue] = {'bus':'Music','loop':True,'cooldown':0,'priority':0,'gain_db':-8.0}
    installed = {}
    for cue, paths in assigned.items():
        spec = config['cues'][cue]
        spec['files'] = ['res://art/audio/sts/'+p for p in paths]
        spec['gain_db'] = -14.0 if spec['bus'] == 'Ambience' else -8.0 if spec['bus'] == 'Music' else -6.0
        for relative in paths:
            if relative in installed: continue
            entry = available[relative]
            source = args.source/relative
            assert hashlib.sha256(source.read_bytes()).hexdigest() == entry['sha256'], relative
            dest = ROOT/'art/audio/sts'/relative
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source,dest)
            installed[relative] = entry
    config['version'] = 2
    config['source'] = 'Slay the Spire local installation'
    config['default_volumes']['Music'] = 0.5
    config['music_fade_seconds'] = 1.2
    config['scene_music'] = {'MainMenu.tscn':'music_menu','Town.tscn':'music_town',
        'PreRunPreparation.tscn':'music_town','PreRunAdPreparation.tscn':'music_town',
        'ShopUI.tscn':'music_town','RestUI.tscn':'music_rest','EventUI.tscn':'music_rest',
        'AltarUI.tscn':'music_rest','HiddenActEntrance.tscn':'music_hidden'}
    config['act_music'] = ['music_act1','music_act2','music_act3','music_hidden']
    config['boss_music'] = ['music_boss1','music_boss2','music_boss3','music_boss4']
    config['elite_music'] = 'music_elite'
    config['runtime_file_count'] = sum(len(s['files']) for s in config['cues'].values())
    (ROOT/'data/audio.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    provenance = {k:manifest[k] for k in ['source','archive','archive_sha256','transformation']}
    provenance['files'] = list(installed.values())
    (ROOT/'art/audio/sts/manifest.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (ROOT/'art/audio/sts/README.md').write_text('# STS audio\n\n来源：用户指定的 Slay the Spire 本地安装包。原文件名、内容和 SHA-256 保留；这些素材不是本项目原创。\n\n运行映射：`data/audio.json`。完整提取目录：`F:/WorkingFiles/123/STS`。重建：`python tools/audio/install_sts_audio.py`。\n',encoding='utf-8')
    print(f'INSTALL_PASS: {len(assigned)} cues / {len(installed)} distinct original files')


if __name__ == '__main__': main()

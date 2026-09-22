"""Build all approval WAVs, content coverage, audition mixes and offline review UI.

Run: python tools/audio/build_review.py
Requires NumPy. Writes only art/audio/review_v1 and outputs/sfx_review_v1.zip.
"""
from pathlib import Path
import hashlib
import json
import math
import sys
import wave
import zipfile
import numpy as np

from catalog import CUES
from synthesis import RATE, render

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'art/audio/review_v1'
IDS = {c['id'] for c in CUES}


def read(name):
    return json.loads((ROOT/'data'/f'{name}.json').read_text(encoding='utf-8-sig'))


def kinds(value):
    result=[]
    if isinstance(value,dict):
        if 'kind' in value: result.append(value)
        for v in value.values(): result.extend(kinds(v))
    elif isinstance(value,list):
        for v in value: result.extend(kinds(v))
    return result


def effect_cues(effects):
    result=[]
    for e in kinds(effects):
        k=e['kind']
        if k in ['apply_status','status']:
            result.append('status_'+e['status'])
        elif k.startswith('power_'):
            result.append('card_power')
        elif k in ['damage','aoe_damage','random_enemy_damage','scaled_damage','strength_scaled_damage',
                   'damage_from_block','fatal_damage','exhaust_hand_damage','x_aoe_damage','heal_unblocked_aoe']:
            result.append('hit_ceramic')  # Material is selected from target at runtime.
            if k=='heal_unblocked_aoe': result.append('heal')
        elif k in ['block','double_block']:result.append('block_gain')
        elif k in ['draw','exhaust_hand_and_draw']:result.append('card_draw')
        elif k in ['exhaust','exhaust_non_attack_hand']:result.append('card_exhaust')
        elif k=='energy':result.append('energy_gain')
        elif k=='gain_kiln_heat':result.append('heat_gain')
        elif k in ['gain_strength','temporary_strength','double_strength','conditional_enemy_intent_strength']:result.append('status_heat')
        elif k=='gain_dexterity':result.append('status_temper')
        elif k=='reduce_enemy_strength':result.append('status_damp')
        elif k=='lose_hp':result.append('self_damage')
        elif k=='heal':result.append('heal')
        elif k=='temporary_thorns':result.append('thorns')
        elif k in ['add_card','random_attack_to_hand','copy_hand_card','copy_self_to_discard']:
            result.append('card_status' if e.get('card_id') in ['wound','burn','dazed'] else 'card_copy')
        elif k in ['recover_exhausted_card','return_discard_to_draw_top','topdeck_hand']:result.append('card_recover')
        elif k=='upgrade_hand':result.append('card_upgrade')
        elif k=='play_top_draw_exhaust':result.extend(['card_draw','card_exhaust'])
        elif k in ['double_next_attacks','all_other_cards_attack']:result.append('card_skill')
        elif k=='rally':result.extend(['enemy_buff','block_gain'])
        elif k=='recruit':result.append('enemy_summon')
        elif k=='self_destruct':result.append('enemy_detonate')
        elif k in ['conditional_target_status','increment_card_damage','set_no_draw','card_hp_loss_count']:
            # Rule gates / bookkeeping have no separate sound; actual result does.
            pass
        else:raise ValueError(f'Unmapped effect kind: {k}')
    return list(dict.fromkeys(result))


def coverage():
    entries=[]
    def row(group, key, name, cues, note=''):
        cues=list(dict.fromkeys(cues))
        assert set(cues)<=IDS,(key,set(cues)-IDS)
        entries.append(dict(group=group,id=key,name=name,cues=cues,note=note))
    card_profiles=read('vfx')['enchant_attack']['card_profiles']
    profile_cues={
        'kiln_cleave':'enchant_cleave','furnace_wave':'enchant_flame','harvest_arc':'enchant_reap',
        'carnage':'enchant_cleave','uppercut':'enchant_cleave','searing_blow':'enchant_flame',
        'fiend_fire':'enchant_flame','sever_soul':'enchant_reap','blood_for_blood':'enchant_cleave',
    }
    for c in read('cards')['cards']:
        card_type=c['type']
        cues=['card_draw','card_status','card_exhaust'] if card_type=='status' else [
            'card_pickup','card_'+card_type,'card_discard',*effect_cues(c)]
        if card_type=='attack': cues.extend(['axe_heavy' if c.get('cost',0)>=2 else 'axe_swing'])
        if c['id'] in card_profiles:cues.append(profile_cues[card_profiles[c['id']]])
        row('卡牌',c['id'],c['name'],cues,'含基础／升级效果；命中按目标材质替换，同一动作选主音，禁止把本行所有声音同时叠播。')
    for s in read('statuses')['statuses']:
        cues=['status_'+s['id'],'status_cleanse']
        if s['id']=='ashrot':cues.append('burn_tick')
        if s['id']=='anneal':cues.append('heal')
        if s['id']=='glaze':cues.append('buffer_trigger')
        row('状态',s['id'],s['name'],cues,'仅实际获得／触发／净化，普通层数刷新与自然到期不重复播放。')
    for p in read('potions')['potions']:
        row('药水',p['id'],p['name'],['potion_gain','potion_use','potion_splash',*effect_cues(p)],'启封、落点、效果按演出顺序；无效使用不响。')
    for r in read('relics')['relics']:
        row('遗物',r['id'],r['name'],['relic_gain','relic_trigger'],'被动常驻属性不循环播放；触发音按实际效果回执限频。')
    for e in read('enchants')['enchants']:
        mods=e.get('mods',{})
        cues=['town_enchant','loadout_select',*effect_cues(mods)]
        if any(k in mods for k in ['damage_bonus','aoe_damage_bonus','splash_damage']):cues.append('enchant_cleave')
        if 'block_bonus' in mods or 'block_per_exhausted' in mods:cues.append('enchant_seal')
        for card in e.get('restriction',{}).get('card_ids',[]):
            if card in card_profiles:cues.append(profile_cues[card_profiles[card]])
        if len(cues)==2:cues.append('enchant_power')
        row('附魔',e['id'],e['name'],cues,'素材按表现类型复用；数值增幅不额外叠音，实际效果沿用卡牌／状态音。')
    family={
        'claylump':('enemy_tackle','hit_clay'), 'sootling':('enemy_stab','hit_ash'),
        'embermoth':('enemy_wing','hit_ash'), 'potsherd':('enemy_claw','hit_ceramic'),
        'glazetick':('enemy_stab','hit_clay'), 'kilnstatue':('enemy_slam','hit_stone'),
        'ashcantor':('enemy_hex','hit_ash'), 'robber':('enemy_stab','hit_ceramic'),
        'kilnward':('enemy_sweep','hit_metal'), 'glazemaw':('enemy_bite','hit_ceramic'),
        'slagbeast':('enemy_fire','hit_stone'), 'kilnwarden':('enemy_slam','hit_metal'),
        'cindermoth':('enemy_wing','hit_ash'), 'meltgolem':('enemy_slam','hit_stone'),
        'kiln_captain':('enemy_sweep','hit_metal'), 'cinderfiend':('enemy_claw','hit_ash'),
        'magmawhelp':('enemy_bite','hit_clay'), 'coalseer':('enemy_hex','hit_ash'),
        'ember_eater':('enemy_bite','hit_ceramic'),
        'kilnheart_ember':('heart_claw','hit_ceramic'), 'sagger_matron':('matron_bar','hit_ceramic'),
        'chi_the_first':('chi_slash','hit_ceramic'), 'ashen_binder':('ashen_burst','hit_ceramic'),
    }
    bosses={
        'sagger_matron':{'bar':'matron_bar','seal':'matron_seal','fire':'matron_fire','vent':'matron_vent','cool':'matron_cool'},
        'ashen_binder':{'seal':'ashen_seal','ash_burst':'ashen_burst','press':'ashen_press','vent':'ashen_vent'},
    }
    move_count=0
    for e in read('enemies')['enemies']:
        base=e['id'].removesuffix('_act3')
        if base.startswith('escort_'):
            fam=('enemy_sweep','hit_metal' if base in ['escort_guard','escort_vanguard'] else 'hit_ceramic')
        else:fam=family[base]
        moves=list(e.get('moves',[]))
        for phase in e.get('phases',[]):
            moves.extend(phase.get('moves',[]))
            if 'entry_move' in phase:moves.append(phase['entry_move'])
        cues=[fam[1],'boss_death' if e['tier']=='boss' else 'enemy_death']
        action_map={}
        for m in moves:
            mid=m['id']; intent=m['intent']
            if base in bosses:fx=bosses[base][mid]
            elif mid.startswith('phase_entry'):fx='boss_awaken'
            elif base=='kilnheart_ember':
                fx=next(v for k,v in [('claw','heart_claw'),('execute','heart_claw'),('ward','heart_ward'),('scald','heart_scald'),('stoke','heart_stoke'),('burst','heart_burst')] if mid.startswith(k))
            elif base=='chi_the_first':
                fx=next(v for k,v in [('slash','chi_slash'),('soul','chi_soul'),('echo','chi_echo'),('pounce','chi_pounce'),('sludge','chi_sludge')] if mid.startswith(k))
            elif mid=='detonate':fx='enemy_detonate'
            elif mid=='rally':fx='enemy_buff'
            elif intent=='charge':fx='enemy_charge'
            elif intent=='defend':fx='block_gain'
            elif intent=='debuff':fx='enemy_hex'
            elif intent=='buff':fx='enemy_buff'
            elif intent=='attack':
                fx='enemy_fire' if mid in ['scald','molten_slam','flare','eruption','immolate','lava_glob','doom_blast','doom'] else fam[0]
            else:raise ValueError(f'Unmapped enemy move {base}/{mid}/{intent}')
            extra=effect_cues(m.get('after_effects',[]))
            if mid=='mug':extra.append('enemy_steal')
            if mid=='deploy':extra.append('enemy_summon')
            action_map[mid]=[fx,*extra]
            cues.extend(action_map[mid]);move_count+=1
        if base.startswith('escort_'):cues.append('enemy_summon')
        if base=='sagger_matron':cues.append('enemy_interrupt')
        if base=='ashen_binder':cues.append('ashen_backlash')
        if base=='chi_the_first':cues.extend(['chi_reactive','heal'])
        row('敌人',e['id'],e['name'],cues,'连击每段复用动作声；护甲命中按实际吸收结果替换。')
        entries[-1]['moves']=action_map
    event_map={'gold':'gold_gain','heal':'heal','lose_hp':'self_damage','remove_card':'card_remove',
               'add_card':'card_acquire','add_enchant':'altar_enchant','add_potion':'potion_gain','add_relic':'relic_gain'}
    for e in read('events')['events']:
        cues=['event_enter']
        for opt in e['options']:
            for k,v in opt['effects'].items():
                cues.append('gold_spend' if k=='gold' and isinstance(v,(int,float)) and v<0 else event_map[k])
        row('事件',e['id'],e['title'],cues,'选项事务成功后按实际结果选择播放；离开只用返回声。')
    for f in read('meta_progression')['facilities']:
        row('镇内设施',f['id'],f['name'],['town_building','town_build_start','town_build_ready','town_upgrade','town_research'],'附魔另用永久附魔／重铸／配印音。')
    counts={g:sum(e['group']==g for e in entries) for g in dict.fromkeys(e['group'] for e in entries)}
    counts['敌人动作']=move_count
    return entries,counts


def write_wav(path,x):
    path.parent.mkdir(parents=True,exist_ok=True)
    pcm=np.rint(x*32767).astype('<i2')
    with wave.open(str(path),'wb') as w:
        w.setnchannels(1 if x.ndim==1 else x.shape[1]); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(pcm.tobytes())
    return pcm.astype(float)/32768


def stats(x):
    peak=float(np.max(np.abs(x)))
    rms=float(np.sqrt(np.mean(x*x)))
    y=np.mean(x,axis=1) if x.ndim==2 else x
    buckets=np.array_split(y,100)
    return dict(duration=round(len(x)/RATE,3),channels=1 if x.ndim==1 else x.shape[1],
                peak_dbfs=round(20*math.log10(max(peak,1e-9)),2),
                rms_dbfs=round(20*math.log10(max(rms,1e-9)),2),
                dc=round(float(np.max(np.abs(np.mean(x,axis=0)))),8),
                seam_delta=round(float(np.max(np.abs(x[0]-x[-1]))),8),
                waveform=[round(float(np.max(np.abs(b)))/max(peak,1e-9),3) for b in buckets])


def make_demos(bank):
    plans=[
        ('demo_combat','一回合战斗',16,[
            (0,'combat_start'),(1.4,'turn_start'),(2.1,'card_draw'),(2.33,'card_draw'),(2.56,'card_draw'),
            (3.5,'card_pickup'),(3.85,'card_attack'),(3.90,'axe_swing'),(4.19,'hit_ceramic'),(4.4,'card_discard'),
            (5.6,'card_skill'),(5.85,'block_gain'),(6.25,'card_discard'),(7.3,'turn_end'),
            (8.25,'enemy_stab'),(8.26,'block_hit'),(9.5,'turn_start'),(10,'card_draw'),
            (10.8,'axe_heavy'),(11.22,'enchant_cleave'),(12.4,'enemy_death'),(13.9,'victory')]),
        ('demo_combo','连击、状态与药水',15,[
            (0,'card_attack'),(.08,'axe_swing'),(.35,'hit_metal'),(.62,'hit_metal'),(.89,'hit_metal'),
            (2.0,'status_heat'),(3.1,'status_damp'),(4.4,'potion_use'),(4.82,'potion_splash'),(5.04,'heal'),
            (6.6,'enemy_slam'),(6.65,'block_break'),(8,'player_hit'),(9.2,'status_ashrot'),(10.5,'burn_tick'),
            (11.5,'card_exhaust'),(12.7,'heat_burst')]),
        ('demo_boss','四位首领动作选听',22,[
            (0,'matron_seal'),(1.6,'matron_fire'),(3.35,'matron_vent'),(5.3,'heart_claw'),
            (6.5,'heart_burst'),(8.5,'boss_awaken'),(10.6,'chi_slash'),(11.7,'chi_soul'),
            (12.02,'chi_soul'),(12.34,'chi_soul'),(12.66,'chi_soul'),(14.1,'ashen_seal'),
            (15.7,'ashen_burst'),(16.06,'ashen_burst'),(16.42,'ashen_burst'),
            (17.6,'ashen_backlash'),(18.5,'ashen_press'),(20.0,'ashen_vent')]),
        ('demo_town','窑口镇与奖励',17,[
            (0,'town_building'),(.7,'town_build_start'),(2.4,'town_build_ready'),(3.8,'town_upgrade'),
            (5.5,'town_enchant'),(7.1,'loadout_select'),(8.1,'granny_dialogue'),(8.8,'granny_blessing'),
            (10.3,'chest_open'),(11.6,'relic_gain'),(13.1,'gold_gain'),(14.2,'shard_gain'),(15.2,'fireseed_gain')]),
        ('demo_loop','营火接缝试听 · 连续两圈',24,[(0,'amb_rest'),(12,'amb_rest')]),
    ]
    names={c['id']:c['name'] for c in CUES}
    demos=[]
    for key,name,seconds,events in plans:
        stereo=key=='demo_loop'
        x=np.zeros((round(seconds*RATE),2)) if stereo else np.zeros(round(seconds*RATE))
        for at,cid in events:
            audio=bank[cid]; i=round(at*RATE); n=min(len(audio),len(x)-i)
            x[i:i+n]+=audio[:n]
        peak=np.max(np.abs(x)); gain=min(1,.79/max(peak,1e-8)); x*=gain
        path=DEST/'demos'/f'{key}.wav'; decoded=write_wav(path,x)
        demos.append(dict(id=key,name=name,file=path.relative_to(DEST).as_posix(),
                          group='组合试听',loop=False,files=[],use='编排试听，非游戏运行录音。',
                          events=[dict(time=at,name=names[cid],id=cid) for at,cid in events],
                          **stats(decoded)))
    return demos


def main():
    if hasattr(sys.stdout,'reconfigure'):sys.stdout.reconfigure(encoding='utf-8')
    assert len(IDS)==len(CUES)
    DEST.mkdir(parents=True,exist_ok=True)
    mapping,counts=coverage()
    result=[]; bank={}; failures=[]
    for index,c in enumerate(CUES):
        entry={k:v for k,v in c.items() if k not in ['params','seconds','level_dbfs']}
        entry['loop']=bool(c['params'].get('loop',False)); entry['files']=[]
        for v in range(1,c['variants']+1):
            x=render(c,v)
            filename=f"{c['id']}_{v:02}.wav"
            path=DEST/'wav'/filename
            decoded=write_wav(path,x)
            st=stats(decoded)
            if not np.isfinite(x).all() or st['peak_dbfs']>-2.0 or st['rms_dbfs']<-44 or st['dc']>.0001:
                failures.append((filename,{k:v for k,v in st.items() if k!='waveform'}))
            if st['seam_delta']>.0001:failures.append((filename,'endpoint mismatch'))
            if v==1:bank[c['id']]=decoded
            entry['files'].append(dict(file='wav/'+filename,variant=v,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),**st))
        result.append(entry)
        if (index+1)%25==0:print(f'Generated {index+1}/{len(CUES)} cue families',flush=True)
    assert not failures,failures
    demos=make_demos(bank)
    data=dict(version='sfx-review-v1',title='炽窑 · 音效审批',status='待用户试听审批，未接入正式游戏',
              method='原创程序合成／分层拟音，不含下载采样、模型生成音频或人声配音。',
              format='PCM WAV / 44.1 kHz / 16 bit；短音单声道，循环环境声立体声。',
              cues=result,demos=demos,coverage=mapping,coverage_counts=counts,
              technical_checks=dict(files=sum(len(c['files']) for c in result),
                  silence_clipping_dc_and_endpoints='PASS',runtime='NOT VERIFIED',listening='待用户审批'))
    (DEST/'manifest.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    template=(Path(__file__).parent/'review.html').read_text(encoding='utf-8')
    embedded=json.dumps(data,ensure_ascii=False,separators=(',',':')).replace('</','<\\/')
    (DEST/'index.html').write_text(template.replace('__AUDIO_DATA__',embedded),encoding='utf-8')
    (DEST/'README.md').write_text('''# 炽窑音效审批包 v1

状态：待用户审批；未接入正式游戏。打开 `index.html` 可离线试听、切换变体、按分类连续试听、填写意见并导出 JSON／Markdown。浏览器本地保存仅属于当前浏览器和地址，请导出备份；更换浏览器可导入 JSON。

## 制作与内容
全部声音由 `tools/audio/catalog.py`、`synthesis.py`、`build_review.py` 原创程序合成。没有第三方录音／歌曲采样、模型生成音频或人声配音。陶器、铁器、纸张、风与炉火是待审批声音提案。胜负／领取短提示属于音效；背景音乐另做。

短音：44.1kHz / 16-bit PCM / mono；环境：同规格 stereo / 12秒循环。环境声不带头尾淡出，播放器在接入时单独做渐入渐出。音频留峰值余量，不进行硬削波。候选目录带 `.gdignore`，避免审批素材被正式项目导入。

145类音效并不等于每张卡都用独立文件：同类材质与反馈复用，常用动作提供变体。`manifest.json` 包含文件校验值、峰值／RMS／时长／波形、每个现有内容条目的素材映射。连击每段单独播放；一项内容映射列出可能用到的声音，不表示同时播放全部声音。组合试听为编排示例，不是实际运行录音。

## 接入要求（待审批后实施）
- 音效调用应依据表现层的真实命中／领取回执，不能只监听提前发生的数值变化。
- 卡牌飞行破风与命中分开；连击按每段命中播放。群体攻击选择主命中层并限制叠音。
- 常用变体轮换，短时间批量抽牌／弃牌／状态合并。取消、失败不播成功反馈。
- 地图／镇内界面复用通用 UI 音，不给文字逐字加声音。
- Music / SFX / Ambience 独立音量；保存设置，暂停、切后台、广告接管时正确暂停与恢复。
- 未在真实设备上验证响度、动作同步、并发音量或后台行为，均为 NOT VERIFIED。

审批后仅把选定的 WAV 与正式映射移入生产目录。现有 `transition_boss.wav` 与 `transition_chapter.wav` 未替换。
''',encoding='utf-8')
    archive=ROOT/'outputs/sfx_review_v1.zip';archive.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for f in sorted(DEST.rglob('*')):
            if f.is_file() and f.name!='.gdignore':z.write(f,'sfx_review_v1/'+f.relative_to(DEST).as_posix())
        for name in ['catalog.py','synthesis.py','build_review.py','review.html']:
            z.write(Path(__file__).parent/name,'sfx_review_v1/source/'+name)
    print(json.dumps(dict(cues=len(result),wav_files=data['technical_checks']['files'],demos=len(demos),
                          coverage=counts,archive_bytes=archive.stat().st_size),ensure_ascii=False))


if __name__=='__main__':main()

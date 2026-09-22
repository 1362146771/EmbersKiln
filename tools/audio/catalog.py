"""Approval-only SFX cue sheet. No gameplay values or runtime bindings."""

CUES = []


def cue(group, key, name, recipe, seconds, use, variants=1, level=-19, **params):
    CUES.append(dict(id=key, group=group, name=name, recipe=recipe,
                     seconds=seconds, use=use, variants=variants,
                     level_dbfs=level, params=params))


for key, name, recipe, seconds, use in [
    ('ui_click', '轻触陶签', 'tap', .13, '普通按钮点击；避免与领取反馈同时叠播'),
    ('ui_confirm', '确认', 'confirm', .33, '确认选择、保存设置'),
    ('ui_cancel', '返回／取消', 'cancel', .22, '关闭浮窗、取消选择'),
    ('ui_open', '展开面板', 'paper', .26, '牌堆、图鉴、详情打开'),
    ('ui_close', '收起面板', 'paper', .19, '牌堆、图鉴、详情关闭'),
    ('ui_page', '翻页', 'paper', .31, '图鉴切页、选牌列表翻页'),
    ('ui_deny', '操作未成立', 'deny', .27, '能量不足、非法目标、容量不足、不可用'),
    ('ui_toggle', '设置开关', 'tap', .12, '设置开关切换'),
    ('map_select', '地图落点', 'step', .36, '确认可到达地图节点'),
    ('pause_open', '暂停', 'cancel', .38, '打开暂停设置'),
    ('pause_close', '继续', 'confirm', .32, '关闭暂停设置'),
]:
    cue('界面与地图', key, name, recipe, seconds, use, level=-25)

for key, name, recipe, seconds, use, variants in [
    ('card_pickup', '拿起手牌', 'paper', .19, '开始拖牌；长按查看不重复触发', 2),
    ('card_draw', '抽牌', 'paper', .23, '卡牌进入手牌；快速连续抽牌限频', 3),
    ('card_attack', '攻击牌投出', 'paper_cast', .28, '攻击牌飞行开始，命中音另播', 2),
    ('card_skill', '技能牌施放', 'skill', .46, '技能演出开始，效果音按回执播放', 2),
    ('card_power', '能力牌入场', 'power', .90, '能力牌成功生效，一张一次', 2),
    ('card_discard', '落入弃牌堆', 'paper', .25, '正常出牌及回合结束弃牌', 3),
    ('card_shuffle', '洗牌', 'shuffle', .72, '弃牌堆洗回抽牌堆，一次洗牌一次', 2),
    ('card_exhaust', '消耗成灰', 'burn', .62, '卡牌进入消耗堆，批量时合并', 2),
    ('card_return', '卡牌回弹', 'paper', .26, '无效落点回手，和拒绝音择一播放', 1),
    ('card_acquire', '获得卡牌', 'acquire', .67, '永久卡牌实际入库后', 1),
    ('card_upgrade', '卡牌锻造升级', 'forge', 1.10, '升级交易成功后', 1),
    ('card_remove', '永久焚牌', 'burn', .95, '确认且永久删牌成功后', 1),
    ('card_copy', '复制／生成卡牌', 'copy', .52, '临时复制、生成牌进入牌堆', 1),
    ('card_recover', '回收卡牌', 'recover', .52, '消耗回收、弃牌置顶、手牌置顶', 1),
    ('card_status', '伤口／灼伤／晕眩入堆', 'ash', .47, '生成状态牌；伤口等本身不可主动打出', 1),
]:
    cue('卡牌与牌堆', key, name, recipe, seconds, use, variants, -23)

for key, name, recipe, seconds, use, variants, level, params in [
    ('axe_swing', '斧刃破风', 'whoosh', .34, '挥斧前摇，命中前完成', 3, -19, {}),
    ('axe_heavy', '重斧破风', 'whoosh', .48, '重击前摇', 2, -18, {'size':1.6}),
    ('hit_ceramic', '陶壳命中', 'ceramic', .48, '陶器敌人受击；下劈与伤害数字同帧', 3, -17, {}),
    ('hit_clay', '泥躯命中', 'mud', .40, '陶泥团、釉蛭等软质目标受击', 3, -18, {}),
    ('hit_metal', '铁甲命中', 'metal', .50, '披甲敌人受击', 3, -18, {}),
    ('hit_stone', '石躯命中', 'stone', .52, '窑龛像等厚重目标受击', 3, -17, {}),
    ('hit_ash', '灰躯命中', 'ash', .40, '煤灰／灰焰类目标受击', 3, -19, {}),
    ('player_hit', '主角受伤', 'body', .46, '实际掉血的那次命中，不加人声', 3, -18, {}),
    ('block_gain', '建立格挡', 'shield', .44, '格挡实际增加；批量增加合并', 2, -21, {}),
    ('block_hit', '格挡承击', 'metal', .30, '攻击被完全吸收', 3, -20, {'size':.8}),
    ('block_break', '护层破裂', 'shatter', .56, '承击导致格挡耗尽；替代普通格挡音', 2, -18, {}),
    ('heal', '生命恢复', 'heal', .80, '实际回血／休息治疗', 2, -22, {}),
    ('energy_gain', '能量补充', 'energy', .46, '额外能量实际获得', 2, -22, {}),
    ('turn_start', '玩家回合开始', 'turn', .62, '控制权交回玩家', 1, -22, {}),
    ('turn_end', '结束回合', 'end_turn', .43, '结束回合提交成功', 1, -23, {}),
    ('heat_gain', '窑温积累', 'heat', .44, '窑温增长；不随界面刷新重复播放', 2, -23, {}),
    ('heat_burst', '窑温共鸣', 'eruption', 1.12, '窑温达到现有规则并触发共鸣', 2, -17, {}),
    ('player_death', '陶身倒地', 'collapse', 1.20, '玩家倒地演出；落地重音约0.7秒', 1, -18, {}),
    ('enemy_death', '敌人瓦解', 'shatter', .86, '敌人死亡演出，等待实际死亡展示', 3, -19, {}),
    ('combat_start', '迎战', 'battle', 1.0, '新战斗进入后一次', 1, -20, {}),
    ('self_damage', '献血／自损', 'body', .26, '非攻击来源的实际生命损失', 2, -23, {'size':.7}),
    ('thorns', '反伤', 'shard', .35, '荆棘等实际反伤回执', 2, -21, {}),
]:
    cue('战斗反馈', key, name, recipe, seconds, use, variants, level, **params)

for key, name, recipe, seconds in [
    ('heat', '力量', 'strength', .63), ('temper', '敏捷', 'air', .55),
    ('crazed', '易伤', 'fracture', .58), ('damp', '虚弱', 'weak', .66),
    ('ashrot', '燃烧', 'burn', .60), ('anneal', '再生', 'heal', .74),
    ('stoke', '活力', 'energy', .56), ('glaze', '缓冲', 'shield', .63),
    ('thirst', '衰朽', 'decay', .77),
]:
    cue('状态效果', 'status_'+key, name+'获得', recipe, seconds,
        '仅该状态新增或增加层数时播放；不因刷新、自然递减重复播放', level=-23)
cue('状态效果', 'status_cleanse', '净化／移除减益', 'cleanse', .69, '实际净化成功', level=-22)
cue('状态效果', 'burn_tick', '燃烧跳伤', 'crackle', .27, '燃烧实际造成伤害时', 2, -24)
cue('状态效果', 'buffer_trigger', '缓冲生效', 'shield', .28, '缓冲实际抵消伤害时', 2, -23)

for key, name, recipe, seconds, use in [
    ('enemy_tackle', '泥体冲撞', 'mud', .53, '冲撞、泥体扑击'),
    ('enemy_stab', '尖刺突袭', 'stab', .33, '煤灰仔／釉蛭刺击'),
    ('enemy_claw', '利爪撕击', 'claw', .43, '陶片鬼／烬魈挥爪，每次命中单播'),
    ('enemy_bite', '咬合', 'bite', .37, '釉裂兽／岩浆幼兽咬击'),
    ('enemy_wing', '振翅灰扑', 'wing', .66, '烬蛾、灰蛾行动'),
    ('enemy_fire', '熔火喷吐', 'fire', .78, '熔火／熔浆喷射，单次冲击'),
    ('enemy_slam', '重物砸落', 'stone', .70, '石像／巨像／重装敌人重击'),
    ('enemy_hex', '灰咒施放', 'hex', .73, '咒术攻击、施加减益'),
    ('enemy_charge', '蓄势', 'charge', .88, '敌人进入蓄力动作'),
    ('enemy_buff', '敌方强化', 'strength', .76, '敌人主动强化动作；状态声择主音'),
    ('enemy_summon', '随从补入', 'summon', .92, '实际生成新随从'),
    ('enemy_steal', '掠走金币', 'coins', .44, '强盗实际夺金'),
    ('enemy_detonate', '倒计时自爆', 'eruption', 1.00, '引信陶俑自爆命中'),
    ('enemy_interrupt', '蓄力被打断', 'fracture', .68, '实际满足打断条件'),
    ('enemy_sweep', '铁器横扫', 'claw', .54, '护窑兵／护卫／窑卫長武器攻击'),
]:
    cue('敌人动作', key, name, recipe, seconds, use, 2 if key in ['enemy_stab','enemy_claw','enemy_bite','enemy_sweep'] else 1, -19)

for key, name, recipe, seconds, use in [
    ('matron_bar', '匣母 · 拦路', 'stone', .83, '拦路命中'),
    ('matron_seal', '匣母 · 封匣', 'seal', 1.05, '陶匣闭合、建立蓄火姿态'),
    ('matron_fire', '匣母 · 开窑', 'eruption', 1.28, '开窑喷火命中'),
    ('matron_vent', '匣母 · 泄压', 'vent', 1.12, '破盾打断后喷出泄压气流'),
    ('matron_cool', '匣母 · 散热', 'air', .88, '自然散热动作'),
    ('heart_claw', '窑心 · 烬爪／处决', 'claw', .62, '每段命中播放一次，不把连击烘焙到素材'),
    ('heart_ward', '窑心 · 护炉', 'seal', .79, '护炉防御动作'),
    ('heart_scald', '窑心 · 灼面', 'fire', .94, '灼面命中'),
    ('heart_stoke', '窑心 · 炽焰蓄势', 'charge', 1.10, '蓄势动作'),
    ('heart_burst', '窑心 · 炉心爆裂', 'eruption', 1.42, '炉心爆裂命中'),
    ('boss_awaken', '首领 · 阶段强化', 'awaken', 1.62, '半血／四分之一血阶段强化演出'),
    ('chi_slash', '窑主 · 焰斩', 'flame_slash', .76, '焰斩命中'),
    ('chi_soul', '窑主 · 灵击', 'soul', .40, '四重灵击每段命中'),
    ('chi_echo', '窑主 · 暗焰爆发', 'dark_burst', 1.44, '暗焰爆发命中'),
    ('chi_pounce', '窑主 · 扑击', 'body', .53, '三重扑击每段命中'),
    ('chi_sludge', '窑主 · 灰浆侵蚀', 'sludge', .96, '灰浆命中'),
    ('chi_reactive', '窑主 · 能力反制', 'hex', .46, '第一阶段能力反制实际生效'),
    ('ashen_seal', '灰络 · 封焰束环', 'chain_seal', 1.06, '束环收紧封焰'),
    ('ashen_burst', '灰络 · 连续喷灰', 'ash_burst', .48, '每段灰焰命中播放一次'),
    ('ashen_press', '灰络 · 压窑', 'press', 1.09, '宽弧压窑命中'),
    ('ashen_vent', '灰络 · 换气蓄压', 'vent', 1.24, '换气动作'),
    ('ashen_backlash', '灰络 · 灰索反冲', 'rope', .27, '出牌后实际反冲；达到既有上限后静音'),
    ('boss_death', '首领 · 熄炉崩解', 'boss_collapse', 1.90, '首领最终死亡演出'),
]:
    cue('首领专属', key, name, recipe, seconds, use,
        2 if key in ['chi_soul','ashen_burst','ashen_backlash'] else 1,
        -23 if key=='ashen_backlash' else -18)

for key, name, recipe, seconds, use in [
    ('enchant_cleave', '附魔 · 碎窑重斩', 'heavy_ceramic', .92, '重击类附魔命中，替代普通命中主音'),
    ('enchant_flame', '附魔 · 炉潮烈焰', 'fire', 1.06, '群体烈焰／焚身类附魔命中'),
    ('enchant_reap', '附魔 · 收割吸取', 'reap', 1.14, '收割类附魔弧斩与回流'),
    ('enchant_rush', '附魔 · 连斩', 'claw', .30, '连击类附魔每段命中'),
    ('enchant_seal', '附魔 · 护印', 'shield', .74, '防护类附魔生效'),
    ('enchant_power', '附魔 · 炉印苏醒', 'power', .98, '能力类永久附魔首次激活'),
]:
    cue('附魔表现', key, name, recipe, seconds, use, level=-20)

for key, name, recipe, seconds, use in [
    ('gold_gain', '金币入袋', 'coins', .65, '金币实际获得'),
    ('gold_spend', '支付金币', 'coins', .40, '购买／删牌实际扣款'),
    ('fireseed_gain', '火种归炉', 'embers', .93, '火种结算领取'),
    ('relic_gain', '获得遗物', 'relic', 1.06, '遗物实际获得'),
    ('relic_trigger', '遗物触发', 'relic', .35, '有可见演出的遗物触发；被动属性不循环响'),
    ('potion_gain', '获得药水', 'bottle', .47, '药水实际入库'),
    ('potion_use', '启封药瓶', 'uncork', .48, '合法使用提交后；无效拖放不响'),
    ('potion_splash', '药釉泼洒', 'splash', .61, '药水效果落点'),
    ('shard_gain', '获得升级碎片', 'shard', .61, '领取升级碎片成功'),
    ('chest_open', '宝箱开启', 'chest', 1.02, '首次打开宝箱'),
    ('reward_open', '展开战利品', 'acquire', .76, '战利品页首次出现'),
    ('victory', '战斗胜利', 'victory', 1.45, '敌人死亡演出结束后'),
    ('defeat', '远征失败', 'defeat', 1.55, '最终失败结算，避免覆盖倒地重音'),
    ('act_clear', '幕章通关', 'triumph', 1.70, '幕末结算'),
    ('run_win', '远征完成', 'triumph', 2.20, '最终胜利结算'),
    ('revive', '余火复燃', 'rebirth', 1.36, '复燃资格确认成功、恢复开战检查点'),
    ('hidden_open', '隐藏窑道开启', 'gate', 1.68, '隐藏幕入口演出'),
    ('transition_boss', '首领转场', 'battle', .96, '首领转场候选，现有正式素材保留'),
    ('transition_chapter', '章节转场', 'vent', 1.03, '章节转场候选，现有正式素材保留'),
    ('ad_reward', '广告奖励到账', 'acquire', .71, '广告奖励事务成功；广告中不播放游戏音效'),
]:
    cue('奖励与流程', key, name, recipe, seconds, use, level=-22 if seconds<1 else -20)

for key, name, recipe, seconds, use in [
    ('town_building', '选中镇中建筑', 'wood', .27, '建筑点击反馈'),
    ('town_build_start', '动工', 'hammer', .96, '建设事务成功后'),
    ('town_build_ready', '工程就绪', 'ready', .83, '工程首次就绪；不随倒计时刷新重播'),
    ('town_upgrade', '设施修复完成', 'forge', 1.33, '领取设施升级'),
    ('town_research', '研究配方', 'research', 1.06, '研究解锁实际领取'),
    ('town_enchant', '永久附魔', 'enchant', 1.21, '献祭火种附魔成功'),
    ('town_reroll', '重铸附魔', 'forge', 1.04, '重铸成功'),
    ('loadout_select', '配印入槽', 'seal', .35, '实际配印成功；满额不播放成功音'),
    ('granny_dialogue', '陶婆翻动衣袖', 'cloth', .27, '切换整句对白；不逐字播放，无人声配音'),
    ('granny_blessing', '陶婆馈赠', 'blessing', 1.06, '馈赠实际领取；不暗示隐藏奖励内容'),
    ('rest_settle', '营火坐定', 'wood', .60, '选择休息，随后按回血结果播放治疗'),
    ('event_enter', '翻开事件', 'paper', .61, '事件正文出现'),
    ('shop_refresh', '商店重新铺货', 'shuffle', .84, '库存刷新成功'),
    ('altar_enchant', '祭坛刻印', 'enchant', 1.08, '祭坛附魔实际成功'),
]:
    cue('窑口镇与事件', key, name, recipe, seconds, use, level=-23)

for key, name, material, use in [
    ('amb_menu', '巨窑 · 炉腹与烟流', 'kiln', '主菜单背景，低音量循环'),
    ('amb_town', '窑口镇 · 微风与远处工坊', 'town', '镇景／陶婆场景循环，无可辨识人声'),
    ('amb_act1', '第一幕 · 冷窑风隙', 'wind', '第一幕探索与战斗底层'),
    ('amb_act2', '第二幕 · 炉火与热气', 'fire', '第二幕探索与战斗底层'),
    ('amb_act3', '第三幕 · 深炉轰鸣', 'deep', '第三幕探索与战斗底层'),
    ('amb_hidden', '隐藏幕 · 灰流与束索', 'ash', '隐藏幕／灰络场地循环'),
    ('amb_rest', '营火 · 木炭轻爆', 'camp', '休息场地循环'),
]:
    cue('循环环境声', key, name, 'ambience', 12.0, use, level=-29, material=material, loop=True)

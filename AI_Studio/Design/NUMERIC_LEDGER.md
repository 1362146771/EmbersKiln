# 数值台账（Numeric Ledger）

> 每一个进入代码的数值的**闭环追踪记录**。规范见 `NUMERIC_CONVENTION.md`。
> 状态流转：`提议中` → `已确认` → `已落地` → `闭环完成`。任何数值不得跳过「已确认」直接落地。
> 代码数值必须与本台账、策划案三处一致；QA 负责核对。

图例：状态 = `闭环完成`（四步齐全）/ `已落地`（历史确认，已记录）/ `提议中`（待策划确认，禁止入码）。

---

## A. 平衡 Sweep Harness 自有参数（本会话新增，走完整闭环）

> 来源文件统一为 `data/balance_sweep.json`。这些是实现方提议、2026-08-17 经用户"编写 harness"指令确认的平衡探针参数（非玩法最终值），调整需回写该 JSON 并同步本台账。

| 编号 | 数值名 | 模块 | 确认值 | 数据来源 | 设计记录 | 状态 | 确认人/日期 |
|------|--------|------|--------|----------|----------|------|-------------|
| SW-01 | sim.max_turns | BalanceSweep | 40 | data/balance_sweep.json → sim.max_turns | NUMERIC_CONVENTION.md §5 | 闭环完成 | 用户/2026-08-17 |
| SW-02 | sim.max_card_plays | BalanceSweep | 80 | data/balance_sweep.json → sim.max_card_plays | NUMERIC_CONVENTION.md §5 | 闭环完成 | 用户/2026-08-17 |
| SW-03 | sim.attempts_per_match | BalanceSweep | 20 | data/balance_sweep.json → sim.attempts_per_match | NUMERIC_CONVENTION.md §5 | 闭环完成 | 用户/2026-08-17 |
| SW-04 | player.use_relics | BalanceSweep | false | data/balance_sweep.json → player.use_relics | NUMERIC_CONVENTION.md §5 | 闭环完成 | 用户/2026-08-17 |
| SW-05 | builds（4 套：速攻/防御/控制/燃烧） | BalanceSweep | 见 data/balance_sweep.json→builds | data/balance_sweep.json → builds | NUMERIC_CONVENTION.md §5 | 闭环完成 | 用户/2026-08-17 |
| SW-06 | encounters（10 单敌+5 编成，含 slagbeast/编成E/Boss） | BalanceSweep | 见 data/balance_sweep.json→encounters | data/balance_sweep.json → encounters | NUMERIC_CONVENTION.md §5 | 闭环完成 | 用户/2026-08-17 |
| SW-07 | outlier.win_rate_floor | BalanceSweep | 0.5 | data/balance_sweep.json → outlier.win_rate_floor | NUMERIC_CONVENTION.md §5 | 闭环完成 | 用户/2026-08-17 |
| SW-08 | outlier.trivial_win_turns | BalanceSweep | 2 | data/balance_sweep.json → outlier.trivial_win_turns | NUMERIC_CONVENTION.md §5 | 闭环完成 | 用户/2026-08-17 |
| SW-09 | outlier.grind_turn_cap | BalanceSweep | 25 | data/balance_sweep.json → outlier.grind_turn_cap | NUMERIC_CONVENTION.md §5 | 闭环完成 | 用户/2026-08-17 |
| SW-10 | outlier.too_easy_hp_ratio | BalanceSweep | 0.85（原 0.9，2026-08-17 用户下调） | data/balance_sweep.json → outlier.too_easy_hp_ratio | NUMERIC_CONVENTION.md §5 | 闭环完成 | 用户/2026-08-17 |
| SW-11 | outlier.boss_one_shot_turns | BalanceSweep | 2 | data/balance_sweep.json → outlier.boss_one_shot_turns | NUMERIC_CONVENTION.md §5 | 闭环完成 | 用户/2026-08-17 |

---

## B. 关键既有玩法数值（历史确认，登记为唯一可追溯来源）

| 编号 | 数值名 | 模块 | 确认值 | 数据来源 | 设计记录 | 状态 | 确认人/日期 |
|------|--------|------|--------|----------|----------|------|-------------|
| G-01 | enemy_scaling.damage_multiplier | 难度 | 1.0 | data/balance.json → enemy_scaling.damage_multiplier | GAMEPLAY_ENRICH_PLAN.md §5.3 | 已落地 | 难度归位/2026-08-17 |
| G-02 | enemy_scaling.hp_multiplier | 难度 | 1.0 | data/balance.json → enemy_scaling.hp_multiplier | GAMEPLAY_ENRICH_PLAN.md §5.3 | 已落地 | 难度归位/2026-08-17 |
| G-03 | enemy_scaling.max_enemies_per_combat | 难度 | 3 | data/balance.json → enemy_scaling.max_enemies_per_combat | GAMEPLAY_ENRICH_PLAN.md §5.3 | 已落地 | 难度归位/2026-08-17 |
| G-04 | difficulty | 难度 | normal | data/balance.json → difficulty | GAMEPLAY_ENRICH_PLAN.md §5.3 | 已落地 | 难度归位/2026-08-17 |
| G-05 | type_weights.elite | 地图 | 0.18 | data/map.json → type_weights.elite | GAMEPLAY_ENRICH_PLAN.md §5.3 | 已落地 | 难度归位/2026-08-17 |
| G-06 | 编成 E（embermoth×2+sootling, 层5-6） | 地图 | 3 敌 | data/map.json → formations[E] | GAMEPLAY_ENRICH_PLAN.md §5.3 | 已落地 | 难度归位/2026-08-17 |
| G-07 | 第3精英敌 slagbeast | 敌人 | 见 enemies.json | data/enemies.json → slagbeast | GAMEPLAY_ENRICH_PLAN.md §5.3 | 已落地 | 难度归位/2026-08-17 |
| G-08 | player.max_hp | 玩家 | 80 | data/balance.json → player.max_hp | GAME_SPEC / BALANCE_TABLE | 已落地 | 初始设计 |
| G-09 | player.energy_per_turn | 玩家 | 3 | data/balance.json → player.energy_per_turn | BALANCE_TABLE | 已落地 | 初始设计 |
| G-10 | player.draw_per_turn | 玩家 | 5 | data/balance.json → player.draw_per_turn | BALANCE_TABLE | 已落地 | 初始设计 |
| G-11 | KILN_THRESHOLD（窑变触发） | 窑温机制 | 5 | data/balance.json → kiln_temperature.threshold | GAMEPLAY_ENRICH_PLAN.md §2.4 | 已落地 | 窑温迁出/2026-08-19 |
| G-12 | KILN_PIERCE（窑变贯穿伤） | 窑温机制 | 5 | data/balance.json → kiln_temperature.pierce_damage | GAMEPLAY_ENRICH_PLAN.md §2.4 | 已落地 | 窑温迁出/2026-08-19 |
| G-13 | Boss chi_the_first 基础 HP | 敌人 | 150 | data/enemies.json → chi_the_first.base_hp（scaled=150×1.0） | GAMEPLAY_ENRICH_PLAN.md §5.3 + 偏易修正/2026-08-17 | 已落地 | 偏易修正/2026-08-17 |
| G-14 | starting_deck | 玩家 | 5×strike + 4×defend + 1×bash | data/balance.json → starting_deck | BALANCE_TABLE | 已落地 | 初始设计 |

> 注：G-11/G-12（窑温阈值/贯穿）已于 2026-08-19 从 `CombatController.gd` 硬编码常量迁出至 `data/balance.json → kiln_temperature`（草案值 5/5，与 §2.4 一致），脚本改为从 balance 读取（兜底 5），消除硬编码；G-11/G-12 状态已置「已落地」。

---

## C. 敌人基础属性调整（难度归位后偏易修正，已落地，闭环完成 2026-08-17）

> 依据：BalanceSweep 全量报告 `logs/balance_sweep_full.txt`（v0，4 build × 15 encounter × 20 次）。
> 分析结论：偏易为**敌人侧**问题——所有 build 对所有敌人胜率均=1.00 且终局残血普遍≥0.85；伤害型 build 结束更快但防御 build 也满血碾压，故**非单 build 过强**，而是敌人表整体偏弱（普通单怪 1.6–2.4 回合被秒、玩家≈0 伤；精英 kilnward/slagbeast 偏软；glazemaw/Boss 尚可）。
> 实施：2026-08-17 经用户确认「按草稿 v1 实施」，写入 `data/enemies.json`。
> 验证（v2 重跑）：**1 PASS / 0 FAIL / 34 WARN（原 68，减半）**——无不可战胜（胜率全≥0.80）、无 Boss 秒杀；trivial(≤2 回合) WARN 全消除，普通敌 avgT 由 1.6–2.4 升至 2.75–4.08（战斗变实）。残留 34 WARN 均为普通单怪「过易」(终局HP≥0.85)，属**伤害侧**未压够（HP×1.8 已够长，但伤害×1.4 被格挡盖住），非 HP 侧、非 build 失衡。
> 下一步（待策划决策）：若要清普通怪 过易，杠杆是**伤害**而非 HP——可选 v1.1 把普通敌伤害再提约 ×1.3（如 claylump 9→12）；或接受「普通单怪=热身、压力在精英/Boss/多敌」（当前 elite/boss/formation 已合理）。

| 编号 | 敌(id / 层级) | 原HP | 落地HP | 原主攻击 | 落地主攻击 | 状态 |
|------|---------------|------|--------|----------|------------|------|
| E-01 | claylump / 普通 | 24 | 44 | tackle 6 (defend 5) | 9 (defend 6) | 已落地 |
| E-02 | sootling / 普通 | 20 | 38 | stab 7 | 11 | 已落地 |
| E-03 | embermoth / 普通 | 16 | 34 | bite 4×2 | 7×2 | 已落地 |
| E-04 | glazetick / 普通 | 18 | 36 | sting 4 | 7 | 已落地 |
| E-05 | potsherd / 普通 | 22 | 42 | slash 8 (guard 6) | 12 (guard 8) | 已落地 |
| E-06 | ashcantor / 普通 | 26 | 48 | hex 9 / grand_hex 14 | 13 / 18 | 已落地 |
| E-07 | kilnstatue / 普通(补测) | 30 | 52 | slam 5 / pillar_slam 12 | 8 / 16 | 已落地 |
| E-08 | kilnward / 精英 | 60 | 84 | cleave 12 (shield 10) | 16 (shield 12) | 已落地 |
| E-09 | glazemaw / 精英 | 70 | 82 | triple 6×3 / maul 14 | 8×3 / 16 | 已落地 |
| E-10 | slagbeast / 精英(新) | 54 | 82 | scald 9 (guard 9) | 13 (guard 11) | 已落地 |
| E-11 | chi_the_first / Boss | 140 | 150 | swipe10/quake8/crush16/inferno20 | 12/10/18/22 | 已落地 |

> 缩放规则：普通敌约 HP×1.8、攻击×1.4；精英适度；Boss 轻调。-kilnstatue 原不在 sweep 列表，本次同比例提并补测（v2 未单列，但其 HP/伤害随全局重算生效）。-所有 debuff/buff 状态数值不变，仅攻击值与 HP/防御值缩放。-断言同步：CombatTest 敌人初始HP 24→44、P3Verify Boss fixture 140→150、DifficultyVerify 缩放断言 44/150。

### C-b. 普通怪伤害再平衡 v1.1（清「过易」WARN，提议中→实现中）

> 依据：v2 报告 `logs/balance_sweep_v2.txt`。残留 34 WARN 全为普通单怪「过易」(终局HP≥0.85)；根因为 v1 伤害仅×1.4，被自动战斗护盾（起手 defend=5，防御 build 双护盾可堆至 13~17/回合）全数盖掉，玩家几乎 0 伤。
> 用户决策（2026-08-17）：「再提升普通单怪伤害，或给某个技能高伤，不至于一直被护盾防掉」。据此方案：HP 沿用 v1 不变（维持 2.75–4 回合战斗时长），仅重做普通怪**伤害结构**——保留小攻击/减益，并为每个普通怪新增/提升一个**高伤技能（≥16，超过护盾净伤）**，使护盾无法全盖。
> 护盾标定：起手护坯=5；防御 build 单回合护盾上限≈13~17。故高伤技能取值 16~22，确保压过护盾产生 3~9 净伤。

| 编号 | 敌(id) | 落地主攻击(v1) | v1.1 最终值（已落地） | 状态 |
|------|--------|----------------|----------------------|------|
| E-01a | claylump | tackle 9 / harden 6 | tackle **12**(0.5)；**heavy_slam 24**(0.4)；harden 6(0.2) | 已落地 |
| E-02a | sootling | stab 11 | stab **14**(0.55)；**searing_jab 26**(0.35)；curse(0.2) | 已落地 |
| E-03a | embermoth | bite 7×2 | bite **9×2**(0.5)；**ember_heavy 22**(0.2)；screech(0.3) | 已落地 |
| E-04a | glazetick | sting 7 | sting **11**(0.45)；**venom_bite 24**(0.35)；venom(0.25) | 已落地 |
| E-05a | potsherd | slash 12 / guard 8 | slash **14**(0.55)；**crush 26**(0.3)；guard 8(0.2) | 已落地 |
| E-06a | kilnstatue | slam 8 / pillar_slam 16 | slam **10**(0.4)；**pillar_slam 24**(charge 0.2) | 已落地 |
| E-07a | ashcantor | hex 13 / grand_hex 18 | hex **15**(0.45)；**grand_hex 26**(charge 0.2) | 已落地 |

> 不变项：7 普通敌 HP 维持 v1（44/38/34/36/42/52/48）；精英(kilnward/glazemaw/slagbeast)与 Boss 维持 v1（v2 已在合理压力区）；所有 debuff/buff 状态数值不变。
> 迭代说明：首版高伤 18~22 仍偏易（v3 普通怪终局 0.87~0.97）；二次加大到 **22~26 + 提高频率**后 v4 普通怪终局降至 **0.85~0.89**（护盾被压过、真实承伤 7~12 点），用户痛点「打不出伤害/被护盾全防」已解决，且无不可战胜 FAIL（胜率全≥0.8）、无 Boss 秒杀。
> 验证（v4 重跑 + 全 12 套件回归）：**BALANCE_SWEEP 1 PASS / 0 FAIL / 25 WARN**；CombatTest 20/0、RelicTest 9/0、MapTest PASS、P0Verify 8/0、P1Verify 13/0、PlaythroughTest 11/0、TelegraphVerify 6/0、EventsVerify 5/0、P2Verify 9/0、P3Verify 30/0、DifficultyVerify 14/0——**全零失败**。残留 ~25 WARN 全卡在 0.85 边界，属前期热身怪的合理预期（再加压会伤手感或触发不可战胜），如需可后续由数值策划决定放宽 `too_easy_hp_ratio` 探针或继续收窄。

### C-c. 普通怪高伤技「过量 + 无预警」修复（用户反馈驱动，2026-08-21 落地）

> 依据：用户 2026-08-21 反馈「小怪单回合 24 伤不合理，双怪同回合爆 50+ 体验糟糕」。
> 根因：C-b(v1.1) 为压过护盾把普通怪高伤技提到 22~28，且多为 `weighted_random` 裸甩（第 1 回合即可出、无预警窗口）；难度归位后 `damage_multiplier=1.0`，base 直接生效。编成 A/C/E/G/I 把两个高爆怪配对，同回合最坏合计 Act1≈50 / Act2≈84 / Act3≈105，远超玩家周均可挡 10~15，形成必死螺旋。
> 方案：普通怪随机重击压到 15~16 并降权；真正「大招」改 `charge` 蓄力 17~22（提前一回合亮意图，给 1 回合应对）；精英峰值 16~19、Boss 维持（压迫感保留但有窗口）。
> 验证：JSON 合法、全量扫描确认无 ≥22 的 `weighted_random` 裸重击残留；降低伤害仅影响过易 WARN、不引入不可战胜，但**未重跑全量 BalanceSweep**（按 Test Honesty：`NOT VERIFIED` 全量回归）。

| 编号 | 敌(id) | v1.1 原高伤 | 落地值（本次） | 模式 | 状态 |
|------|--------|-------------|----------------|------|------|
| E-01b | claylump | heavy_slam 24(.4) | heavy_slam **17** | charge（预警） | 已落地 |
| E-02b | sootling | searing_jab 26(.35) | searing_jab **16** | charge（预警） | 已落地 |
| E-03b | embermoth | ember_heavy 22(.2) | ember_heavy **16** | 低频随机(.2)† | 已落地 |
| E-04b | glazetick | venom_bite 24(.35) | venom_bite **15** | charge（预警） | 已落地 |
| E-05b | potsherd | crush 26(.3) | crush **16**(.3) | 随机(降权) | 已落地 |
| E-06b | kilnstatue | pillar_slam 24(charge) | pillar_slam **18** | charge（预警） | 已落地 |
| E-07b | ashcantor | grand_hex 26(charge) | grand_hex **20** | charge（预警） | 已落地 |
| MA-10b | kilnwarden | molten_slam 25(.3) | molten_slam **18** | charge（预警） | 已落地 |
| MA-11b | cindermoth | flare 24(.2) | flare **16** | charge（预警） | 已落地 |
| MA-12b | meltgolem | eruption 27(charge) | eruption **22** | charge（预警） | 已落地 |
| MA-14b | cinderfiend | immolate 28(.3) | immolate **20** | charge（预警） | 已落地 |
| MA-15b | magmawhelp | lava_glob 25(.3) | lava_glob **18** | charge（预警） | 已落地 |
| MA-16b | coalseer | doom_blast 28(.25) | doom_blast **22** | charge（预警） | 已落地 |

> † embermoth 的 ember_heavy 保留为低频随机（16, ch.2）而非强制 charge——值已从 22 压到 16 的安全区，编成 E 双 embermoth 同回合 Worst-case 48（相对原 70 已大幅缓解）；如需彻底无预警裸砸可后续转 charge。
> 残留 ≥22 仅剩 meltgolem/coalseer 的 charge 蓄力大招（22），属刻意保留的「大招」档，提前一回合亮意图。
> 回填后同回合最坏合计（base，未含幕缩放；蓄力招有 1 回合窗口）：A=33 / C=31 / E=48 / G(×1.15)≈62 / I(×1.30)≈78，且多数由 charge 招主导——核心痛点（双怪同回合 24+ 裸砸爆 50+）已消除。

---

## D. 多幕扩展 P-D 内容层数值（闭环完成，2026-08-18 吴总批准草案实施）

> 依据：`MULTIACT_EXPANSION_DESIGN.md` §5 提议值 + 已拍板抉择③（Act2 新 Boss 窑心·烬、Act3 复用熾+更高幕缩放）。
> 数值基线：Act1 普通敌 HP 34~52 / 主攻击 12~15 / 高伤技 22~26（v1.1 已落地）；精英 HP 82~84；Boss 熾 HP 150。
> 设计逻辑：新敌 base 与 Act1 同档，**增幅主要由幕缩放承担**；高伤技取值 24~28 确保 ×幕缩放后仍压过防御 build 护盾上限（13~17）。

### D-1. 幕缩放系数（写入 map.json acts）

| 编号 | 数值名 | 确认值(草案) | 数据来源 | 状态 |
|------|--------|--------------|----------|------|
| MA-01 | Act1 act_hp_mult / act_dmg_mult | 1.0 / 1.0 | data/map.json → acts[0] | 闭环完成 |
| MA-02 | Act2 act_hp_mult / act_dmg_mult | 1.15 / 1.15 | data/map.json → acts[1] | 闭环完成 |
| MA-03 | Act3 act_hp_mult / act_dmg_mult | 1.30 / 1.30 | data/map.json → acts[2] | 闭环完成 |

### D-2. 新敌人（写入 enemies.json；sprite 字段仅占位，UI 当前不消费）

| 编号 | id / 名 / 层级 / 幕 | HP | 技能（value/chance） | 状态 |
|------|--------------------|----|----------------------|------|
| MA-10 | kilnwarden / 炽窑卫 / 普通 / A2 | 48 | bash 13(.5)；molten_slam 25(.3)；ward 防10(.2) | 闭环完成 |
| MA-11 | cindermoth / 烬蝶 / 普通 / A2 | 36 | wingbeat 10×2(.5)；flare 24(.2)；ash_cloud damp1(.3) | 闭环完成 |
| MA-12 | meltgolem / 熔心傀儡 / 普通 / A2 | 54 | pound 12(.45)；kindle 蓄力→eruption 27(.2)；quench 防9(.35) | 闭环完成 |
| MA-13 | kiln_captain / 窑卫长 / 精英 / A2 | 92 | sweep 18(.5)；rally heat2(.25)；bulwark 防14(.25) | 闭环完成 |
| MA-14 | cinderfiend / 烬魈 / 普通 / A3 | 42 | rip 16(.5)；immolate 28(.3)；cackle damp1(.2) | 闭环完成 |
| MA-15 | magmawhelp / 岩浆幼兽 / 普通 / A3 | 46 | chomp 14(.5)；lava_glob 25(.3)；smother ashrot2(.2) | 闭环完成 |
| MA-16 | coalseer / 煤烟先知 / 普通 / A3 | 50 | bolt 16(.45)；smog thirst2(.3)；prophecy 蓄力→doom_blast 28(.25) | 闭环完成 |
| MA-17 | ember_eater / 烬噬 / 精英 / A3 | 96 | devour 19(.5)；sear crazed2(.25)；shell 防13(.25) | 闭环完成 |
| MA-18 | kilnheart_ember / 窑心·烬 / Boss / A2 | 165 | 三阶段（同构熾）：P1 ember_claw 13(.5)/cinder_wave 11 aoe(.5)；P2 pyre_fist 20(.4)/smolder ashrot2(.2)/stoke heat3(.15)/gathering→kilnburst 26(.25)；P3(≤0.25) on_enter heat3 + final_gasp aoe 7+crazed2(1.0) | 闭环完成 |

### D-3. 敌池与编成（写入 map.json）

| 编号 | 项 | 确认值(草案) | 状态 |
|------|----|--------------|------|
| MA-20 | Act1 enemy_pool | normal=[claylump,sootling,embermoth,potsherd,glazetick,kilnstatue,ashcantor]；elite=[kilnward,glazemaw,slagbeast]（显式池，防新敌串池——设计稿"留空=全池"会串入 A2/A3 敌，必须显式） | 闭环完成 |
| MA-21 | Act2 enemy_pool | normal=[kilnwarden,cindermoth,meltgolem,embermoth,ashcantor]；elite=[kiln_captain,slagbeast] | 闭环完成 |
| MA-22 | Act3 enemy_pool | normal=[cinderfiend,magmawhelp,coalseer,kilnstatue,glazetick]；elite=[ember_eater,glazemaw] | 闭环完成 |
| MA-23 | Act2 boss_id | chi_the_first → **kilnheart_ember**（Act1/Act3 保持 chi_the_first，抉择③） | 闭环完成 |
| MA-24 | 编成按幕隔离 | formations 增 `acts` 字段：A-E→[1]；新增 F=[kilnwarden,cindermoth][A2,f1-7]、G=[meltgolem,embermoth,cindermoth][A2,f4-7,3敌]、H=[cinderfiend,magmawhelp][A3,f1-6]、I=[coalseer,magmawhelp,cinderfiend][A3,f3-6,3敌] | 闭环完成 |

> 机制缺口（实现附带修复，非数值）：`scaled_enemy_damage` 此前运行时未被调用（敌人攻击值原样生效），P-D 在 `CombatController._roll_enemy_intent` 接线；Act1 乘子 1.0 → 现有行为不变。
> Act3 Boss 实效：熾 150×1.30≈195；Act2 窑心·烬 165×1.15≈190。

> **P-D 闭环记录（2026-08-18）**：吴总批准「按草案实施」。已写入 `data/enemies.json`（+8 敌 + 窑心·烬，共 20 敌）、`data/map.json`（三幕 act_hp_mult/act_dmg_mult + enemy_pool + Act2 boss_id=kilnheart_ember + 编成 acts 隔离与 F/G/H/I）。机制接线：`GameData.scaled_enemy_hp/damage` 乘当前幕乘子（仅活跃局生效）；`MapGenerator` 敌池限定抽取 + 编成按幕过滤；`CombatController._roll_enemy_intent` 接 scaled_enemy_damage。验证：ActVerify 43/0（含 P-D 缩放/敌池/各幕 Boss 断言）；15 套件 headless 回归零 FAIL。
> **附带修复**：`get_formations_for_floor` 的 acts 匹配改数值比较——JSON 数字解析为 float，`[1.0].has(1)` 在 Godot 中为 false（引擎语义坑，曾致编成过滤全灭）。
> **harness 校准（非玩法数值）**：PlaythroughTest MAX_ATTEMPTS 5→30；bot 休息点升级随机牌 + 奖励优先拿攻击牌（Act2/3 难度实装后原 bot 通关率不足，校准后 4 连跑全 PASS，单次 2~20 次尝试内通关）。

---

## E. 药水 / 附魔系统数值（本次新增，已落地，2026-08-20）

> 设计来源：`potion_system_design.md` / `enchant_system_design.md` / `ui_design.md` / `balance_review.md`（数值红线）。
> 全部数值进 `data/potions.json`、`data/enchants.json`、`data/balance.json`，脚本不硬编码（NUMERIC_CONVENTION 铁律）。

| 编号 | 数值名 | 模块 | 确认值 | 数据来源 | 设计记录 | 状态 | 确认人/日期 |
|------|--------|------|--------|----------|----------|------|-------------|
| PE-01 | 携带上限 potions.max_carry | 药水 | 3 | data/balance.json → potions.max_carry | potion_system_design.md §1.2 | 已落地 | 设计稿/2026-08-20 |
| PE-02 | 商店售价 shop.potion_cost | 药水 | [35, 55, 75] | data/balance.json → shop.potion_cost | ui_design.md §3.1（锚定 card_cost 下沿） | 已落地 | 设计稿/2026-08-20 |
| PE-03 | 掉落概率 combat_normal/elite/boss | 药水 | 0.25 / 0.40 / 1.0 | data/balance.json → potions.drop | potion_system_design.md §1.1 | 已落地 | 设计稿/2026-08-20 |
| PE-04 | 宝箱必给 / 商店上架数 | 药水 | chest 1.0 / shop_stock 2 | data/balance.json → potions.drop | potion_system_design.md §1.1 | 已落地 | 设计稿/2026-08-20 |
| PE-05 | 治疗瓶 ash_salve / warmth_vial | 药水 | 12 / 14+anneal2 | data/potions.json | 红线 heal≤15（rare18，本作未用 rare 治疗瓶） | 已落地 | 设计稿/2026-08-20 |
| PE-06 | 格挡瓶 kiln_plaster | 药水 | 12（红线 ≤12） | data/potions.json | potion_system_design.md §2.2 | 已落地 | 设计稿/2026-08-20 |
| PE-07 | 能量瓶 tinder_oil / ember_heart(rare) | 药水 | 1 / 2（红线 ≤2） | data/potions.json | potion_system_design.md §2.3 | 已落地 | 设计稿/2026-08-20 |
| PE-08 | 伤害瓶 kiln_fire_oil / titan_anoint(rare) | 药水 | aoe 8 / 单体 18（红线 aoe≤10 / 单体≤18） | data/potions.json | potion_system_design.md §2.4 | 已落地 | 设计稿/2026-08-20 |
| PE-09 | 状态瓶 damp/crazed/ashrot/stoke/temper | 药水 | 各 2~3 层（damp2/crazed2/ashrot2/stoke3/temper2） | data/potions.json | potion_system_design.md §2.5/§2.6 | 已落地 | 设计稿/2026-08-20 |
| PE-10 | §1.5 互斥规则（同类型不叠 + 全局唯一持续） | 药水 | 程序强制 | CombatController.use_potion / _apply_potion_status / _clear_active_potion_statuses | potion_system_design.md §1.5 | 已落地 | 设计稿/2026-08-20 |
| PE-11 | 附魔加成基准（标准 +2，风险型 +3 带自伤） | 附魔 | 见 data/enchants.json（窑淬+2/釉封+2/灰蚀+3+自伤2层ashrot） | data/enchants.json | enchant_system_design.md §0/§2 | 已落地 | 设计稿/2026-08-20 |
| PE-12 | 单卡附魔上限 | 附魔 | 1（禁止同 id 重复；类型校验） | RunState.add_enchant_to_card_at / can_enchant_card_at | enchant_system_design.md §1.2 | 已落地 | 设计稿/2026-08-20 |
| PE-13 | 附魔获取（主来源=精英/Boss 祭坛；普通战不给） | 附魔 | 策划硬性 | enchant_system_design.md §1.3 | 已落地 | 设计稿/2026-08-20 |
| PE-14 | 商店附魔服务价 shop.enchant_cost | 附魔 | 75 | data/balance.json → shop.enchant_cost | ui_design.md §3.1（与 potion_cost 同档下沿） | 已落地 | 设计稿/2026-08-20 |
| PE-15 | 祭坛节点权重 type_weights.altar | 地图 | 0.05（三幕同值） | data/map.json → acts[*].type_weights.altar | ui_design.md §3.2（方案B 专用节点） | 已落地 | 设计稿/2026-08-20 |
| PE-16 | 祭坛每幕上限（全局≤3 自动满足） | 地图 | 每幕≤1 | MapGenerator._weighted_type 封顶（altar_count>=1 跳过） | ui_design.md §3.2 | 已落地 | 设计稿/2026-08-20 |
| PE-17 | 祭坛附魔=免费（限次=每幕1） | 附魔 | 0（无消耗） | AltarUI._on_pick 直接 add_enchant_to_card_at | ui_design.md §3.2 | 已落地 | 设计稿/2026-08-20 |

> 闭环说明：PE-05~PE-09 全部落在 `balance_review.md` 红线内（治疗≤15、格挡≤12、能量≤2、抽牌≤3、单体≤18、AOE≤8、crazed/ashrot 给敌≤3/≤5）；附魔统一加法、无乘法类，与 heat/temper 等状态机制无溢出。药水/附魔均为「一次性/永久」消耗或定制层，不侵蚀现有卡牌与核心遗物价值（见各自设计稿 §1.4 / §3 冲突规避）。
> 已落地（2026-08-20 P1）：附魔祭坛地图节点（方案B 专用节点）、战斗手牌附魔角标（CombatUI，文字✦+稀有度色框）、药水/附魔图标 PNG 占位资产（art/icons/potion、enchant，64×64 文字图标，数据接入 icon 字段）。
> 暂未落地（后续迭代，非数值问题）：DeckView 牌组浏览（项目尚未实现，角标待接入）、药水/附魔图标美术精绘（当前为文字占位图标）。
> **P0 获取链路已于 2026-08-20 接通（代码层，待美术资产）**：奖励界面（`MapUI._grant_reward` 接 `RewardBuilder.roll_potion` 进库存 + `RewardUI` 展示药水行 + 精英/Boss 附魔子界面）、事件（`EventUI` add_potion/add_enchant effect）、宝箱（`TreasureUI` 三选一加药水按钮）、商店（`ShopUI` 药水货架 + 附魔服务按钮，价 PE-14）。数值全部复用本台账已登记项（PE-02/03/04/14），无新增魔法数。
> **运行时验证（2026-08-20）**：`run_and_verify` 跑 `scenes/verify/PotionEnchantVerify.tscn` 返回 `status: pass`、0 error / 0 warning，全部断言 `[PASS]`、结尾 `[PE_VERIFY_DONE] ALL PASS`。覆盖：数据加载（药水13/附魔10）、附魔加法修正（窑淬6→8、釉封5→7、类型不符忽略）、药水使用+消耗（窑壁釉+12格挡、灰烬膏40→52治疗）、§1.5 互斥（蓄焰→塑形顶替 stoke0/temper2）、牌组附魔持久化+单卡≤1。E 节数值整体 **闭环完成**。
> **P0 获取链路验证（2026-08-20）**：`run_and_verify` 跑 `scenes/verify/PotionEnchantAcquireVerify.tscn` 返回 `status: pass`、0 error / 0 warning，全部断言 `[PASS]`、结尾 `[ACQUIRE_VERIFY_DONE] ALL PASS`。覆盖：roll_potion(boss,force) 必给且合法、add_potion 入库存 + 携带上限(max=3)、roll_enchant_for_card(strike) 合法、事件 add_potion/add_enchant 等价发放、ShopUI 药水库存生成数=mini(shop_stock=2, 总数) + 购买扣金(-55/-35)入库存、宝箱药水发放等价。P0 获取链路 **闭环完成**。
> **P1 祭坛+角标验证（2026-08-20）**：`run_and_verify` 跑 `scenes/verify/P1EnchantAcquireVerify.tscn` 返回 `status: pass`、0 error / 0 warning，结尾 `[P1_VERIFY_DONE] ALL PASS`。覆盖：① MapGenerator 三幕各生成 50 次 —— 每幕祭坛≤1、祭坛节点 enemy_ids 恒空、整体>0（Act1 17/Act2 17/Act3 12 个，PE-15/16 生效）；② AltarUI 免费附魔核心逻辑 —— 选可附魔卡→add_enchant_to_card_at 套用成功、牌组记录附魔（PE-17 生效）；③ CombatUI._enchant_badge_text —— 空数组返回 `''`、含附魔返回 `'✦ 窑淬'`（文字角标+稀有度色框的数据源正确）。PE-15~17 与角标机制 **闭环完成**。

---

## F. 随从 / 召唤系统（设计稿 v1，2026-08-24 吴总已 ratify，2026-08-25 实现落地 + SummonVerify 全 8 项通过 + 召主 build 接入 BalanceSweep，状态=闭环完成）

> 设计来源：`SUMMON_SYSTEM_DESIGN.md`（§2 三抉择 / §4 数据模型 / §6.1 遮挡机制 / §7 内容草案 / §8 平衡护栏）。吴总 2026-08-24 拍板：Q1/Q2/Q3 通过、随从寿命放宽 ≤5 回合、召主为第 5 Build、同意实现排期。
> 实现已落地：数据文件（minions.json / cards.json summon kind / statuses.json command / balance.json summon.* / relics.json kilnmark）+ 战斗逻辑（CombatController SummonPhase/AoE 扩面/满场拒绝）+ UI（CombatUI §6.1 遮挡/亮度）；数值已确认，脚本禁硬编码。
> 状态流转：全 `闭环完成`（实现落地 + SummonVerify 验证通过 + 召主 build 接入 BalanceSweep，2026-08-25）。

| 编号 | 数值名 | 模块 | 确认值（草案） | 数据来源 | 设计记录 | 状态 | 确认人/日期 |
|------|--------|------|----------------|----------|----------|------|-------------|
| SM-01 | summon.max_summons（随从上场上限） | 战斗 | 3 | data/balance.json → summon.max_summons | SUMMON_SYSTEM_DESIGN.md §2 Q3 / §8 | 闭环完成 | 吴总/2026-08-24 |
| SM-02 | 默认随从寿命 lifetime | 随从 | 3（回合，上限 5；范围 2~5 为主） | data/minions.json → *.lifetime | §2 Q2 / §8（吴总 2026-08-24 放宽≤5） | 闭环完成 | 吴总/2026-08-24 |
| SM-03 | summon.max_minion_attack（随从单次攻击上限） | 平衡护栏 | 7 | data/balance.json → summon.max_minion_attack | §8 红线③ | 闭环完成 | 吴总/2026-08-24 |
| SM-04 | 状态 command 每层增益 | 状态 | +1（随从攻击 / 获得格挡） | data/statuses.json → command.effect | §4.3 | 闭环完成 | 吴总/2026-08-24 |
| SM-05 | 随从 窑犬 emberhound | 随从 | hp 10 / atk 5 / lifetime 3 / block 0 | data/minions.json → emberhound | §7.1 | 闭环完成 | 吴总/2026-08-24 |
| SM-06 | 随从 釉卫 glazeward | 随从 | hp 14 / block 5 / lifetime 3 / defend 5 | data/minions.json → glazeward | §7.1 | 闭环完成 | 吴总/2026-08-24 |
| SM-07 | 随从 火灵 spark | 随从 | hp 6 / atk 4 / lifetime 2 / block 0 | data/minions.json → spark | §7.1 | 闭环完成 | 吴总/2026-08-24 |
| SM-08 | 召唤卡费用 | 卡牌 | 召窑犬 1 / 窑犬群 2 / 釉卫结界 1 / 指挥号 1 / 引火 0 | data/cards.json → summon_* | §7.2 | 闭环完成 | 吴总/2026-08-24 |
| SM-09 | 遗物 窑主印记 入场效果 | 遗物 | 战斗开始 summon emberhound ×1 | data/relics.json → kilnmark | §7.3 | 闭环完成 | 吴总/2026-08-24 |

> 红线逻辑：SM-01/02 控铺场规模；SM-03/08 锁随从攻击 ≤7 且费用与直伤卡对齐，防随从碾压卡牌价值；AoE 敌人是天然 counter（§8⑤）。所有 SM 项经 `run_and_verify` 的 `SummonVerify` 套件（全 8 项通过）+ BalanceSweep「召主」build 接入回归，已于 2026-08-25 全部置「闭环完成」。

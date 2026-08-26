import json, os, sys, shutil
sys.stdout.reconfigure(encoding='utf-8')
D = "AI_STUDIO/Design"

ENEMY = {
 "slime":("claylump","陶泥团"), "goblin":("sootling","煤灰仔"),
 "bat":("embermoth","火蛾"), "skeleton":("potsherd","陶片兵"),
 "scorpion":("glazetick","釉蛭"), "gargoyle":("kilnstatue","窑龛像"),
 "cultist":("ashcantor","灰颂者"), "orc_chief":("kilnward","陶偶将"),
 "cerberus":("glazemaw","釉裂兽"), "abyss_lord":("chi_the_first","窑主·熾"),
}
STATUS = {
 "strength":("heat","炽热"), "dexterity":("temper","塑形"),
 "vulnerable":("crazed","釉裂"), "weak":("damp","受潮"),
 "poison":("ashrot","灰蚀"), "regen":("anneal","回火"),
}
RELIC = {
 "burning_blood":("emberheart","余温炭"), "iron_fist":("bellows_glove","风箱手套"),
 "lucky_coin":("charcoal_chit","炭票袋"), "energy_core":("draft_flue","抽风口"),
 "thorn_armor":("sherd_vest","陶片背心"), "war_banner":("keeper_apron","守窑围裙"),
 "vampire_fang":("heat_siphon","汲热钳"), "first_aid":("mending_slip","补陶泥"),
 "heavy_hammer":("firewood_axe","劈薪斧"), "guardian_totem":("hearth_totem","围炉小灶"),
}
CARD_ID = {"demon_form":"molten_form", "poison_blade":"ash_blade"}
CARD_NAME = {
 "strike":"劈薪","defend":"护坯","bash":"敲釉","heavy_slash":"重劈","double_strike":"双斧",
 "cleave":"扫炭","thrust":"火钳刺","charge":"鼓风","burning_fist":"炽拳","throw_rock":"掷坯",
 "iron_wall":"窑壁","parry":"挡钳","battle_stance":"守窑式","quick_step":"绕炉","taunt":"引火",
 "bandage":"补釉","war_cry":"鼓风令","rage":"炉怒","harden":"定型","bloodlust":"嗜热",
 "burning_soul":"炽心","earthquake":"震窑","execute":"收火","unbreakable":"不裂","twin_guard":"双壁",
 "empowering":"增焰","whirlwind":"卷灰","ash_blade":"灰刃","second_wind":"回风","warlord":"大匠之姿",
 "firestorm":"火暴","molten_form":"熔身","last_stand":"末薪","berserk":"狂炉","titan_strike":"巨窑一击",
}

STATUS_ID = {k: v[0] for k, v in STATUS.items()}
ENEMY_ID  = {k: v[0] for k, v in ENEMY.items()}
RELIC_ID  = {k: v[0] for k, v in RELIC.items()}
KEYMAP = {
    "status": STATUS_ID, "status_id": STATUS_ID, "applies_status": STATUS_ID, "inflict": STATUS_ID,
    "enemy": ENEMY_ID, "enemy_id": ENEMY_ID,
    "relic": RELIC_ID, "relic_id": RELIC_ID, "starter_relic": RELIC_ID,
}

def remap(o):
    if isinstance(o, dict):
        out = {}
        for k, v in o.items():
            if isinstance(v, str) and k in KEYMAP:
                out[k] = KEYMAP[k].get(v, v)
            else:
                out[k] = remap(v)
        return out
    if isinstance(o, list):
        return [remap(x) for x in o]
    return o

def save(p, d):
    json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)

report = []

p = f"{D}/STATUS_LIST.json"; d = json.load(open(p, encoding="utf-8"))
for s in d["statuses"]:
    if s["id"] in STATUS:
        s["id"], s["name"] = STATUS[s["id"]]
        s["icon"] = "ICO_Status_" + s["id"].capitalize()
save(p, d); report.append(f"STATUS: {len(d['statuses'])} 条重命名")

p = f"{D}/ENEMY_LIST.json"; d = json.load(open(p, encoding="utf-8"))
for e in d["enemies"]:
    if e["id"] in ENEMY: e["id"], e["name"] = ENEMY[e["id"]]
    e["sprite"] = "SPR_Enemy_" + "".join(w.capitalize() for w in e["id"].split("_"))
d = remap(d); save(p, d); report.append(f"ENEMY: {len(d['enemies'])} 条重命名 + sprite 字段")

p = f"{D}/RELIC_LIST.json"; d = json.load(open(p, encoding="utf-8"))
for r in d["relics"]:
    if r["id"] in RELIC:
        r["id"], r["name"] = RELIC[r["id"]]
        r["icon"] = "ICO_Relic_" + "".join(w.capitalize() for w in r["id"].split("_"))
d = remap(d); save(p, d); report.append(f"RELIC: {len(d['relics'])} 条重命名")

p = f"{D}/CARD_LIST.json"; d = json.load(open(p, encoding="utf-8"))
miss = []
for c in d["cards"]:
    c["id"] = CARD_ID.get(c["id"], c["id"])
    if c["id"] in CARD_NAME: c["name"] = CARD_NAME[c["id"]]
    else: miss.append(c["id"])
    c["art"] = "CARD_" + "".join(w.capitalize() for w in c["id"].split("_"))
d = remap(d); save(p, d)
report.append(f"CARD: {len(d['cards'])} 条, 未映射={miss or '无'}")

for f in ("MAP_DESIGN.json", "BALANCE_TABLE.json"):
    p = f"{D}/{f}"; raw = open(p, encoding="utf-8").read()
    for m in (ENEMY, RELIC, STATUS):
        for old, (new, _) in m.items():
            raw = raw.replace(f'"{old}"', f'"{new}"')
    save(p, json.loads(raw)); report.append(f"{f}: 引用重映射完成")

os.makedirs("data", exist_ok=True)
FILEMAP = {"CARD_LIST.json":"cards.json","ENEMY_LIST.json":"enemies.json",
           "STATUS_LIST.json":"statuses.json","RELIC_LIST.json":"relics.json",
           "MAP_DESIGN.json":"map.json","BALANCE_TABLE.json":"balance.json"}
for src, dst in FILEMAP.items():
    shutil.copyfile(f"{D}/{src}", f"data/{dst}")
report.append(f"res://data/ 同步 {len(FILEMAP)} 个文件")

print("\n".join("  OK " + r for r in report))

"""Build the current art delivery tables without changing game assets.

Run from any directory: python tools/build_art_delivery.py [--check]
Manual decisions belong in art/delivery/overrides.json, never generated tables.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import html
import json
from pathlib import Path
import re
from urllib.parse import quote
import wave
import xml.etree.ElementTree as ET

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art/delivery"
IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg"}
ASSET_EXTS = IMAGE_EXTS | {".wav", ".ogg", ".gdshader", ".tres", ".ttf", ".otf"}
STYLE = "AI_Studio/Design/Art/ART_STYLE.md"
ENEMIES = "AI_Studio/Design/Art/ART_STYLE_ENEMIES.md"
VFX = "AI_Studio/Design/Art/VFX_DESIGN.md"
AUDIO = "AI_Studio/Design/Art/AUDIO_DESIGN.md"
PENDING = "待确认"
FIELDS = [
    "资产 ID", "资产类别", "用途与出现位置", "依据与参考", "美术要求", "视角与光向",
    "源图尺寸", "正式交付尺寸", "Godot 导入尺寸", "实际显示／验收尺寸", "文件格式",
    "构图与留白", "对齐与视觉大小", "内容拆分", "禁止内容", "文件命名", "生产路径",
    "引擎接入", "导入设置", "验收环境", "来源与制作资料", "当前版本与修改摘要",
    "制作与审核责任人", "当前状态",
]
QA_FIELDS = ["文件、尺寸与命名", "透明边缘与裁切", "目标尺寸与同类一致性",
             "美术风格", "Godot 编辑器与运行时", "来源与重建资料"]


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def asset_files() -> list[Path]:
    files = [p for folder in (ROOT / "art", ROOT / "themes") for p in folder.rglob("*")
             if p.is_file() and p.suffix.lower() in ASSET_EXTS and OUT not in p.parents]
    # Also inventory project-owned root icons/fonts, if any are added later.
    files += [p for p in ROOT.iterdir() if p.is_file() and p.suffix.lower() in ASSET_EXTS]
    return sorted(set(files), key=rel)


def profile(path: str) -> dict:
    """Requirements from the current category documents, never measured values as policy."""
    parts = path.split("/")
    kind = parts[1] if parts[0] == "art" else "themes"
    spec = dict(category=kind, use="具体展示位置待确认；参见静态引用清单", refs=[STYLE],
                style="遵循所属类别当前专项规范；不将玩家色板、比例强套到其他类别",
                view="沿用已批准参考；统一视角与光向的具体要求待确认",
                display="待确认：须在实际页面记录显示尺寸，不能用源图尺寸替代",
                composition="按对应参考检查主体完整性、安全边距；未有明确模板的项目待确认",
                align="按实际组件与同类参考校对；锚点／视觉大小模板待确认",
                split="动态文字、数值与交互反馈按对应 UI 组件独立提供；例外须由专项明确",
                forbidden="禁止将未批准的参考、源图或候选直接当作最终交付；禁止改变玩法规则",
                environment="实际竖屏页面；以720×1280逻辑布局及Android目标窗口复核；透明图另查深浅背景",
                extra="不适用（非序列帧）；若用于图集／材质，请查实际引用资源",
                source="待补充逐资产来源；以下元数据与相邻生产资料只作证据入口")
    if kind == "cards":
        spec.update(use="卡牌插画；运行映射以 data/cards.json 的 art 字段为准",
                    style="粗手绘墨线、简练大色块、硬边二分阴影；避免密集细线与写实微纹理",
                    display="当前卡面：手牌／拖拽外框136×212；插画在卡面中完整方形显示，插画实际像素另行核对",
                    composition="完整方形插画；按已批准对应卡牌参考保留主体／动作，不裁切图片",
                    split="插画不含卡名、费用、卡框和说明；稀有度独立标牌，不覆盖插画",
                    refs=[STYLE, "art/ui/cards/README.md", "data/cards.json"])
    elif kind == "enemies":
        spec.update(use="敌人立绘／状态图／概念或生产资料；具体敌人由数据与manifest核对",
                    refs=[ENEMIES, "art/enemies/manifest.json", "data/enemies.json"],
                    style="怪物独立v2：动漫感、low-poly式块面、低饱和多色、陶瓷与炉火；不套玩家色板／头身比",
                    composition="正式静态怪物按透明主体边界适配；匣母状态图保留共同画布配准",
                    align="精英主怪与随从主体包围盒面积约3:2，共同底线；多敌按布局安全边界限幅",
                    display="动态适配 EnemyPanel 可用区域；单体／多敌分别记录，不将1254画布当显示尺寸",
                    split="立绘不烘焙名称、血条、状态、意图及选择反馈",
                    extra="匣母状态集见 SAGGER_STATES.md；其他敌人受击由 EnemyCombatPortrait 驱动")
    elif kind == "player":
        spec.update(use="炭之郎立绘、战斗动画及生产／预览资料",
                    refs=[STYLE, VFX, "art/player/animations/manifest.json"],
                    display="2026-09-23正式槽位(32,773,208,311)，720×1280逻辑画布；保留现有人物大小与脚部遮挡",
                    align="静态、攻击、受击、倒地使用同一人物区域；按身体与脚底锚点对齐，禁止逐帧按外接框独立缩放",
                    composition="保留用户确认的底部23px与手牌区域重叠；其他非预期裁切仍须检查",
                    extra="正式攻击8帧，源1.4秒／运行0.98秒；受击30帧1秒；倒地6帧1.2秒不循环。文件身份以正式SpriteFrames与当前配置为准")
    elif kind == "npcs":
        spec.update(use="陶婆开场馈赠对话场景及生产资料",
                    refs=[STYLE, "AI_Studio/Design/World/GRANNY_KILN_DIALOGUE.md"],
                    style="简化罩袍兜帽、遮眼鼻头发只露干瘪嘴尖下巴；佝偻枯瘦，粗轮廓大色块",
                    align="玩家左、陶婆右相向，共用地面基线；陶婆坐姿小于主角",
                    split="立绘、气泡、选项与保存退出按钮分离")
    elif kind == "icons":
        spec.update(use="UI图标；具体业务映射见数据与引用",
                    style="粗手绘轮廓、大色块、简洁造型；同类一致且靠轮廓区分",
                    split="动态数值、名称与说明独立；不得把实时信息烘焙进图标")
        if "/status/" in path:
            spec.update(display="战斗32×32；专项资源基线128×128", use="战斗状态栏；层数独立显示")
        elif "/intent/" in path or "/enemy_special/" in path:
            spec.update(display="战斗42×42；专项独立图标基线128×128", use="敌人意图／特殊机制栏；每个图标独立说明")
        elif "/relic/" in path:
            spec.update(display="40px缩略图可辨认；遗物详情页实际尺寸另核对", use="遗物持有栏、商店、奖励与详情")
        elif "/rewards/" in path:
            spec.update(display="升级碎片按钮48×48；Godot导入上限128",
                        use="战后奖励升级碎片按钮", refs=[STYLE, "art/icons/rewards/README.md"],
                        source="内置image_gen，2026-09-20；当前制作要求与来源见 art/icons/rewards/README.md",
                        composition="单个主体居中，约占画布80%；真实透明，主体完整",
                        style="蓝灰陶瓷卡角、琥珀向上箭头、粗黑外轮廓、大色块与二分阴影",
                        forbidden="不画文字、数字、边框、地面投影、写实纹理或密集细裂纹")
        elif "/potion/" in path:
            spec.update(use="战斗药水槽及药水详情；data/potions.json映射",
                        refs=[STYLE, "AI_Studio/Design/Systems/POTION_SYSTEM_DESIGN.md", "scenes/combat/PotionSlot.tscn"],
                        display="战斗PotionSlot图标40×40逻辑单位（节点16,20至56,60）；详情尺寸另核对")
        elif "/app/" in path:
            spec.update(use="应用图标；project.godot／Android导出入口",
                        environment="Godot应用图标和Android安装后桌面图标；系统遮罩／裁切实机待验证",
                        display="当前Android导出槽：main192、adaptive foreground432；安装后的系统遮罩／显示尺寸须实机验收",
                        refs=[STYLE, "AI_Studio/Memory/GameIdentity.md", "project.godot", "export_presets.cfg"])
        elif "/currency/" in path:
            spec.update(use="窑口镇火种余额入口及FireseedInfo说明；与应用图标分开",
                        refs=[STYLE, "AI_Studio/Memory/GameIdentity.md", "scenes/ui/FireseedInfo.tscn"],
                        style="火种独立图标，粗手绘轮廓、大色块；余额与说明由UI独立提供")
    elif kind == "map":
        spec.update(use="地图节点／首领徽记及参考版本")
        if "/bosses/" in path:
            spec.update(refs=[STYLE, "art/map/bosses/manifest.json", "data/enemies.json"],
                        style="深蓝黑、粗犷不对称、撕裂崩碎的抽象徽记；不画怪物肖像",
                        display="Boss节点居中240×240画布", composition="当前徽记参考要求主形约占90–94%，完整不裁切",
                        split="图标与交互独立；下方不显示Boss名称或常驻机制提示")
    elif kind == "backgrounds":
        spec.update(use="主菜单、各幕战斗、城镇／院落背景及生产参考",
                    composition="背景按目标长宽比适配，记录长屏裁切及UI遮挡区域；不适用透明图标留白规则",
                    split="背景与标题、按钮、角色、HUD独立；城镇去建筑底图与功能建筑独立",
                    view="沿用各场景批准镜头；镇景固定斜俯视，主菜单仰视巨窑")
        if "/town_progression/" in path:
            spec["refs"].append("art/backgrounds/town_progression/README.md")
    elif kind == "ui":
        spec.update(use="正式UI纹理／组件与参考；具体用途见场景引用",
                    style="优先正式UI参考与专项资源规范；不套旧占位面板方案",
                    composition="按组件安全区与九宫格边距；装饰不得遮挡实际内容",
                    split="名称、实时数值、交互独立；稀有度标牌文字绘入图片为现行例外")
        if "/cards/" in path:
            spec.update(refs=[STYLE, "art/ui/cards/README.md", "art/ui/cards/rarity/README.md"],
                        display="共享卡面手牌136×212；大卡高度=宽度+76；稀有度栏48高，按实际组件复核",
                        align="卡框按主体直边内沿对齐，内容区四周12px；不按装饰尖角归一化",
                        composition="四类装饰框源1024×1536，导入长边192，九宫格28；该值不套用标牌")
        elif "/town/building_levels/" in path:
            spec.update(refs=[STYLE, "art/ui/town/building_levels/README.md", "data/town_visuals.json"],
                        use="五栋功能建筑四等级透明叠图及生产资料",
                        view="固定斜俯视，与同级镇景地面透视一致",
                        composition="正式建筑1024×1024 RGBA；四级共用裁切框、地基与尺度",
                        align="对齐同级底图与统一地基；以manifest记录的origin为参考",
                        split="功能建筑与去建筑镇景底图分离；等级仅随领取工程后切换")
        elif "/town/interior_levels/" in path:
            spec.update(refs=[STYLE, "art/ui/town/interior_levels/README.md", "data/town_visuals.json"],
                        use="各建筑等级院落近景及生产资料",
                        composition="高清1536×1024；runtime1024×683，保持原构图与比例",
                        split="上方院落近景与下方工程详情UI独立")
        elif "Pile" in path or "pile" in path:
            spec.update(refs=[STYLE, "art/ui/PILE_ICONS.md"],
                        split="牌堆图标与右下角动态数量分离，数量变化回弹，不画常驻名称")
    elif kind in {"vfx", "shaders"}:
        spec.update(refs=[VFX, "AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md"],
                    use="战斗／转场视觉反馈；参数与触发见 data/vfx.json 及静态引用",
                    split="效果主形、角色、伤害数值与HUD按当前演出分层；不得提前结算玩法",
                    environment="真实触发场景；命中时点、暂停、结束清理、减少动态及720×1280/长屏检查",
                    extra="按实际shader／动画与 data/vfx.json核对，不能按文件帧数猜测运行时长")
        if "/handdrawn/" in path:
            spec.update(refs=[VFX, "art/vfx/enchant/handdrawn/README.md", "AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md"],
                        composition="正式九张图集1536×1024，3列×2行，单帧512×512；保留绘制锚点，不逐帧重缩放",
                        extra="6帧非匀速；基础演出1.20秒，死亡收割另加0.65秒前置。命中与运行参数由配置驱动")
    elif kind == "audio":
        spec.update(refs=[AUDIO], use="音效／环境／音乐；当前映射以 data/audio.json 为准",
                    style="遵守当前音频设计及音量分类；外部素材不得记为原创",
                    view="不适用（音频）", display="不适用（音频）；目标设备听感、声道及音量另验",
                    composition="不适用（音频）", align="按触发／命中时点对齐；音乐切换与暂停恢复另验",
                    split="总音量、音效、音乐、环境独立；不将运行时调音烘焙进原文件",
                    environment="对应事件与实际Android设备试听；静音、暂停、切后台、交叉淡化与循环检查",
                    extra="循环／触发／总线见 data/audio.json 和导入文件；仅测时长不代表运行通过")
        if "/sts/" in path:
            spec.update(source="Slay the Spire 本地安装包；原始OGG/WAV字节，非本项目原创，来源与原始哈希见 art/audio/sts/manifest.json",
                        refs=[AUDIO, "art/audio/sts/manifest.json"])
        else:
            spec.update(source="旧合成方案或试听资源；保留不等于当前运行方案，逐文件来源需核对",
                        refs=[AUDIO, "art/audio/review_v1/manifest.json"])
    elif kind == "references":
        spec.update(use="视觉／构图参考，非默认生产资源", source="逐文件参考来源待核对；不得推定为本项目原创",
                    display="不适用直接运行验收；用于与生产资产并排校对")
    elif kind == "themes":
        spec.update(use="Godot主题／StyleBox／AtlasTexture配置；被场景引用不等于贴图已批准",
                    display="随消费组件变化，见具体场景", composition="以.tres中的区域、边距及主题参数为准")
    elif kind == "minions":
        spec.update(use="旧玩家召唤物目录；当前版本不做玩家召唤物，保留身份待核对",
                    refs=["AI_Studio/Memory/GameIdentity.md", STYLE])
    if path.endswith("ICO_Intent_Kiln.png"):
        spec["display"] = "窑温按状态栏32×32显示；通用意图42×42规则不直接套用本图标"
    if path.startswith("art/player/outfits/"):
        spec["use"] = "待用服装立绘；art/README.md明确为待用，未确认正式接入"
    if path.startswith("art/cards/illustrations/"):
        spec["composition"] += "；当前78张正式插画为1254×1254 RGB满幅背景，不要求透明"
    if path.startswith("art/enemies/sagger_matron/") or path.endswith("SPR_Enemy_SaggerMatron.png"):
        spec.update(refs=["AI_Studio/Design/Art/SAGGER_STATES.md", "art/enemies/manifest.json"],
                    style="匣母保留已批准原型，不随其他怪物v2重设；三座匣钵，按招式切换封匣／喷火／泄压／冷却姿态",
                    composition="共同1254×1254透明画布与原始配准；不得按各状态轮廓重新撑满画布",
                    align="专项约定统一scale0.9、脚底y1120；这是文档锚点要求，现文件包围盒与实际显示另核对",
                    view="三分之四朝左；光向沿用批准原型")
    if path.startswith("art/npcs/granny_kiln/"):
        spec.update(source="内置image_gen；2026-09-21；当前罩袍修订hooded-simplified-crone，依据prompts-v2.json；prompts.json为旧形象资料",
                    refs=[STYLE, "AI_Studio/Design/World/GRANNY_KILN_DIALOGUE.md", "art/npcs/granny_kiln/prompts-v2.json"],
                    view="源图三分之四略朝右，PreRunPreparation场景flip_h后在右侧面向玩家；光向沿用原图")
    if path.startswith("art/icons/enemy_special/") and "/source/" not in path:
        spec["source"] = "内置image_gen；source/pack.png为16格原图，prompts.json记录顺序；generate2dsprite透明切分后缩至128"
    if path.startswith("art/ui/cards/"):
        spec["source"] = "内置image_gen；来源及当前制作规范见对应卡框／稀有度README；逐图参考另见元数据"
        if Path(path).name.startswith("FRAME_") and path.endswith(".png"):
            spec["source_size"] = "1024×1536 RGBA，依据 art/ui/cards/README.md；当前交付尺寸另行实测"
    if path.startswith("art/audio/transition_"):
        spec.update(source="旧转场音频；来源待确认，未证实属于合成包", use="旧转场音频保留资料；当前使用情况见引用证据", refs=[AUDIO])
    if path.endswith("reaper_half_face_v2.png"):
        spec.update(refs=["art/vfx/enchant/reaper_half_face.md", "AI_Studio/Design/Art/ENCHANT_ATTACK_FULLSCREEN_VFX.md"],
                    composition="1024×1536 RGBA；完整角尖、真实透明；运行时镜像等比缩放",
                    split="半脸独立；全屏遮罩和红眼光束由Shader提供",
                    extra="死亡收割前置0.65秒，结束后才进入飞行命中；基于data/vfx.json")
    if path.endswith("reaper_half_face.png"):
        spec["use"] = "半脸旧版保留图；专用README明确现行使用v2，旧版不用于运行"
        spec["refs"] = ["art/vfx/enchant/reaper_half_face.md"]
    if Path(path).suffix in {".gdshader", ".tres"}:
        spec.update(view="不适用固定图像视角；实际视觉方向随消费场景",
                    composition="不适用位图留白；查资源类型、Atlas裁区／九宫格／shader参数及实际效果",
                    align="按消费节点坐标／UV／资源区域对齐；不得用纹理尺寸替代显示尺寸")
    return spec


def normalize(value: str, parent: Path) -> str | None:
    value = value.replace("\\", "/")
    if value.startswith("res://"):
        candidate = ROOT / value[6:]
    elif value.startswith(("art/", "themes/")):
        candidate = ROOT / value
    elif re.match(r"^[A-Za-z]:/", value) or value.startswith(("http:", "https:")):
        return None
    else:
        candidate = parent / value
    try:
        return rel(candidate.resolve())
    except ValueError:
        return None


def collect_evidence(paths: set[str]) -> tuple[dict, dict, dict]:
    refs, metadata, business = defaultdict(list), defaultdict(list), defaultdict(list)
    sources = [ROOT / "project.godot", ROOT / "export_presets.cfg"]
    for folder in ("scenes", "scripts", "data", "themes", "art"):
        sources += [p for p in (ROOT / folder).rglob("*") if p.is_file()
                    and p.suffix in {".gd", ".tscn", ".tres", ".gdshader", ".json"}
                    and OUT not in p.parents]
    for file in sorted(sources):
        content = read(file)
        filename = rel(file)
        is_metadata = filename.startswith("art/") and file.suffix == ".json"
        test_ref = "verify" in filename.lower() or "/tests/" in filename.lower() or "Test" in file.name
        for line_no, line in enumerate(content.splitlines(), 1):
            for value in re.findall(r'res://[^\s"\'<>]+', line):
                candidate = normalize(value, file.parent)
                if candidate in paths and not is_metadata:
                    entry = {"file": filename, "line": line_no,
                             "kind": "验证代码引用" if test_ref else "静态资源引用"}
                    if entry not in refs[candidate]:
                        refs[candidate].append(entry)
        if file.suffix != ".json":
            continue
        try:
            obj = json.loads(content)
        except ValueError:
            continue

        def walk(node, pointer="", context=None):
            context = context or {}
            if isinstance(node, dict):
                inherited = dict(context)
                # Only carry the top-level provenance, never sibling asset approval.
                if not pointer:
                    inherited.update({k: node[k] for k in ("generator", "source", "status", "version", "runtime_integrated", "tool", "date")
                                      if k in node and not isinstance(node[k], (dict, list))})
                if filename.startswith("data/"):
                    inherited.update({k: node[k] for k in ("id", "name") if k in node})
                scalar = {k: v for k, v in node.items() if not isinstance(v, (dict, list))}
                for key, value in node.items():
                    if isinstance(value, str):
                        candidate = normalize(value, file.parent)
                        if candidate in paths:
                            if is_metadata:
                                keep = {k: v for k, v in {**inherited, **scalar}.items()
                                        if k in {"id", "key", "name", "status", "version", "revision", "source", "generator",
                                                 "review_note", "approved_date", "runtime_integrated", "file", "path", "production",
                                                 "runtime_art", "runtime_map_icon", "runtime_path", "reference_source", "reference_file", "level", "generated_source", "tool", "date", "asset"}}
                                for geometry_key in ("size", "runtime_size", "origin", "alpha_bbox", "grid", "frame_duration_ticks", "frame_count"):
                                    if geometry_key in node:
                                        keep[geometry_key] = node[geometry_key]
                                metadata[candidate].append({"file": filename, "pointer": pointer + "/" + key,
                                                            "relation": key, "record": keep})
                            elif filename.startswith("data/"):
                                entry = {"file": filename, "pointer": pointer + "/" + key,
                                         "id": inherited.get("id", ""), "name": inherited.get("name", "")}
                                if entry not in business[candidate]:
                                    business[candidate].append(entry)
                                evidence = {"file": filename, "line": 0, "kind": "数据字段映射"}
                                if evidence not in refs[candidate]:
                                    refs[candidate].append(evidence)
                    walk(value, pointer + "/" + str(key), inherited)
            elif isinstance(node, list):
                for i, value in enumerate(node):
                    walk(value, pointer + "/" + str(i), context)
        walk(obj)
    # Explicitly implement only the project's documented deterministic loaders.
    # A filename resemblance alone never establishes a business mapping.
    for filename, key in (("enemies.json", "enemies"), ("statuses.json", "statuses"),
                          ("potions.json", "potions"), ("relics.json", "relics"), ("enchants.json", "enchants")):
        data_file = ROOT / "data" / filename
        if not data_file.exists():
            continue
        data = json.loads(read(data_file))
        entries = data.get(key, [])
        if not isinstance(entries, list):
            continue
        for i, entry in enumerate(entries):
            if not isinstance(entry, dict):
                continue
            candidate = None
            if key == "enemies" and entry.get("sprite"):
                candidate = "art/enemies/" + entry["sprite"] + ".png"
                field, loader = "sprite", "scripts/data/EnemyData.gd"
            elif entry.get("icon"):
                icon = entry["icon"]
                match = re.match(r"^ICO_(Status|Potion|Enchant|Relic)_", icon)
                if match:
                    candidate = "art/icons/" + match.group(1).lower() + "/" + icon + ".png"
                field, loader = "icon", "scripts/data/GameData.gd"
            if candidate in paths:
                business[candidate].append({"file": rel(data_file), "pointer": f"/{key}/{i}/{field}",
                                            "id": entry.get("id", ""), "name": entry.get("name", ""),
                                            "loader": loader, "resolution": "按现行加载器解析确定性路径"})
                refs[candidate].append({"file": rel(data_file), "line": 0, "kind": "数据字段映射（加载器拼接）"})
                refs[candidate].append({"file": loader, "line": 0, "kind": "确定性加载器"})
    # Literal dictionaries and calls used by the existing UI loaders.
    def add_code_mapping(candidate, filename, key, line, rule):
        if candidate not in paths:
            return
        refs[candidate].append({"file": filename, "line": line, "kind": "确定性代码映射"})
        business[candidate].append({"file": filename, "pointer": key, "id": key, "name": "", "resolution": rule})

    intent_file = "scripts/combat/IntentIconBar.gd"
    content = read(ROOT / intent_file)
    for constant, prefix in (("ICONS", "art/icons/intent/ICO_Intent_"),
                             ("SPECIAL_ICONS", "art/icons/enemy_special/ICO_Enemy_")):
        block = re.search(r"const " + constant + r"\s*:=\s*\{([^}]+)\}", content)
        if block:
            line = content[:block.start()].count("\n") + 1
            for key, suffix in re.findall(r'"([^"\n]+)"\s*:\s*"([^"\n]+)"', block.group(1)):
                add_code_mapping(prefix + suffix + ".png", intent_file, key, line, constant + "字典及load格式串")
    formal_file = "scripts/ui/FormalUI.gd"
    content = read(ROOT / formal_file)
    block = re.search(r"const NODE_IMAGES\s*:=\s*\{([^}]+)\}", content)
    if block:
        line = content[:block.start()].count("\n") + 1
        for key, suffix in re.findall(r'&?"([^"\n]+)"\s*:\s*"([^"\n]+)"', block.group(1)):
            for variant in (("",) if key == "rest" else ("", "_down")):
                add_code_mapping("art/ui/formal/icon_stage_" + suffix + variant + ".png", formal_file, key, line,
                                 "NODE_IMAGES；rest始终使用campfire，选中描边由Shader提供")
    block = re.search(r"var types\s*:=\s*\{([^}]+)\}", content)
    if block:
        line = content[:block.start()].count("\n") + 1
        for key, suffix in re.findall(r'&?"([^"\n]+)"\s*:\s*"([^"\n]+)"', block.group(1)):
            add_code_mapping("art/ui/cards/FRAME_" + suffix + ".png", formal_file, key, line, "card_frame类型字典及load格式串")
    for file in sources:
        if file.suffix != ".gd":
            continue
        filename = rel(file)
        content = read(file)
        pattern = r'FormalUI\.(?:texture|stone)\("([^"\n]+)"'
        if filename == formal_file:
            pattern = r'(?:FormalUI\.)?(?:texture|stone)\("([^"\n]+)"'
        for match in re.finditer(pattern, content):
            candidate = "art/ui/formal/" + match.group(1)
            if candidate in paths:
                refs[candidate].append({"file": filename, "line": content[:match.start()].count("\n") + 1,
                                        "kind": "验证代码引用" if "verify" in filename.lower() else "确定性代码映射"})
    return refs, metadata, business


def measure(file: Path) -> dict:
    result = {"bytes": file.stat().st_size, "sha256": hashlib.sha256(file.read_bytes()).hexdigest()}
    ext = file.suffix.lower()
    if ext in IMAGE_EXTS - {".svg"}:
        with Image.open(file) as im:
            result.update(width=im.width, height=im.height, mode=im.mode, format=im.format,
                          frames=getattr(im, "n_frames", 1))
            # GIF alpha/bbox applies to the first frame, not an animation QC claim.
            has_alpha = "A" in im.getbands() or "transparency" in im.info
            result["alpha_channel"] = has_alpha
            if has_alpha:
                alpha = im.convert("RGBA").getchannel("A")
                result.update(alpha_extrema=list(alpha.getextrema()), alpha_bbox=alpha.getbbox())
            if ext == ".gif":
                duration = 0
                for n in range(im.n_frames):
                    im.seek(n)
                    duration += im.info.get("duration", 0)
                result["preview_duration_ms"] = duration
    elif ext == ".svg":
        element = ET.fromstring(read(file))
        result.update(format="SVG", svg_viewbox=element.get("viewBox"),
                      svg_width=element.get("width"), svg_height=element.get("height"))
    elif ext == ".wav":
        try:
            with wave.open(str(file), "rb") as wav:
                result.update(format="WAV", sample_rate=wav.getframerate(), channels=wav.getnchannels(),
                              sample_bits=wav.getsampwidth() * 8,
                              duration_seconds=round(wav.getnframes() / wav.getframerate(), 4))
        except (wave.Error, EOFError) as exc:
            result["measurement_note"] = "WAV头信息待确认：" + str(exc)
    elif ext == ".ogg":
        result.update(format="OGG", measurement_note="时长、采样率与声道待确认；未解码试听")
    else:
        result["format"] = ext.lstrip(".")
        content = read(file)
        if ext == ".gdshader":
            result["shader_type"] = re.findall(r"shader_type\s+(\w+)", content)
            result["uniforms"] = re.findall(r"^uniform\s+[^;]+;", content, re.M)
        elif ext == ".tres":
            result["resource_type"] = re.findall(r'^\[gd_resource[^\n]*', content, re.M)
            result["regions_and_margins"] = re.findall(r'^(?:region|[a-z_]*margin[a-z_]*|atlas|texture)\s*=.*', content, re.M)
    return result


def import_params(file: Path) -> dict:
    target = Path(str(file) + ".import")
    if not target.exists():
        return {}
    return dict(re.findall(r'^([^\[\]\n=]+)=([^\n]*)$', read(target), re.M))


def size_text(m: dict) -> str:
    if "width" in m:
        return f"{m['width']} × {m['height']} px"
    if "svg_viewbox" in m:
        return f"SVG viewBox={m['svg_viewbox']}；width={m['svg_width']}，height={m['svg_height']}"
    return "不适用（非图片）"


def identity(path: str, refs: list, metadata: list) -> str:
    labels = []
    if any(r["kind"] != "验证代码引用" for r in refs):
        labels.append("存在静态资源／数据引用")
    if "/candidates/" in path:
        labels.append("候选目录（可能含已批准生产源，以逐条元数据为准）")
    if any(s in path for s in ("/source/", "_source/", "/source_", "-raw", "/palette_source/")):
        labels.append("源图／制作资料")
    if any(s in path for s in ("/reference", "/concepts/")):
        labels.append("参考／概念资料")
    if "preview" in path or path.endswith((".gif", ".jpg")):
        labels.append("名称／格式含预览特征，身份需结合引用与manifest，不能仅按文件名判为非生产")
    if path.startswith("art/audio/transition_"):
        labels.append("旧转场音频保留，来源待确认")
    elif path.startswith("art/audio/") and "/sts/" not in path:
        labels.append("旧合成／试听方案保留")
    if path.startswith("art/cards/") and not any(r["file"] == "data/cards.json" for r in refs):
        labels.append("当前data/cards.json未选用该文件")
    if path.startswith("art/minions/"):
        labels.append("旧玩家召唤物范围，当前用途待确认")
    parent = (ROOT / path).parent
    if any((p / ".gdignore").exists() for p in [parent, *parent.parents] if p == ROOT or ROOT in p.parents):
        labels.append("所在目录被.gdignore排除")
    if not labels:
        labels.append("用途待核对：未发现完整路径静态引用；可能由动态拼接加载")
    return "；".join(labels)


def nearby_docs(file: Path) -> list[str]:
    result = []
    for folder in [file.parent, *file.parent.parents]:
        if folder == ROOT or ROOT not in folder.parents:
            break
        if folder == OUT:
            continue
        for name in ("README.md", "manifest.json", "source_manifest.json", "prompts-v2.json", "prompts.json"):
            candidate = folder / name
            if candidate.exists():
                result.append(rel(candidate))
    return list(dict.fromkeys(result))


def make_record(file: Path, refs: list, metadata: list, business: list, override: dict) -> dict:
    path = rel(file)
    spec, measured, params = profile(path), measure(file), import_params(file)
    ext = file.suffix.lower()
    is_image = ext in IMAGE_EXTS
    static_size = size_text(measured)
    alpha = ""
    if "alpha_channel" in measured:
        alpha = "; Alpha=" + (str(measured.get("alpha_extrema")) if measured["alpha_channel"] else "无透明通道")
        if measured["alpha_channel"]:
            alpha += f"；非零Alpha包围盒={measured.get('alpha_bbox')}（右／下边界不含）"
        if ext == ".gif":
            alpha += "；透明统计仅首帧"
    observed = params.get("process/size_limit")
    import_size = (f"当前.import长边上限={observed}（0表示未设置上限；不是显示尺寸）" if observed is not None
                   else "未找到该文件的纹理尺寸上限；不推定引擎默认值" if is_image else "不适用（非纹理像素导入）")
    settings = "; ".join(f"{k}={params[k]}" for k in
                         ("importer", "type", "compress/mode", "mipmaps/generate", "process/fix_alpha_border",
                          "process/premult_alpha", "loop", "loop_mode", "loop_begin", "loop_end") if k in params)
    if is_image:
        settings += "；过滤实际值在消费节点／项目设置复核，不由.import推定。小图标规范为Linear、Lossless"
    named_ids = sorted({str(b["id"]) for b in business if b.get("id")})
    names = sorted({str(b["name"]) for b in business if b.get("name")})
    owned_metadata = [m for m in metadata if m["relation"] in {"file", "path", "production", "runtime_art", "runtime_map_icon", "runtime_path", "asset"}]
    provenance = []
    revisions = []
    for evidence in owned_metadata:
        record = evidence["record"]
        summary = "; ".join(f"{k}={record[k]}" for k in ("generator", "tool", "source", "generated_source", "reference_source", "reference_file") if k in record)
        if summary:
            provenance.append(f"{evidence['file']}#{evidence['pointer']}: {summary}")
        summary = "; ".join(f"{k}={record[k]}" for k in ("revision", "version", "date", "approved_date", "review_note", "status") if k in record)
        if summary:
            revisions.append(f"{evidence['file']}#{evidence['pointer']}: {summary}")
    source_description = spec["source"]
    if provenance:
        source_description = ("" if source_description.startswith("待补充逐资产来源") else source_description + "；") + "本资产字段元数据：" + "；".join(dict.fromkeys(provenance))
    integration = "；".join(dict.fromkeys(r["file"] + (f":{r['line']}" if r["line"] else "") for r in refs))
    record_fields = dict(zip(FIELDS, [
        f"目录唯一键：{path}；文件标识：{file.stem}" + ("；业务ID：" + ", ".join(named_ids) if named_ids else "；业务ID待确认／不适用"),
        spec["category"], spec["use"] + ("；数据名称：" + "、".join(names) if names else ""), "；".join(spec["refs"]), spec["style"], spec["view"],
        spec.get("source_size", "待核对原始制作源尺寸；当前文件实测=" + static_size) if is_image else "不适用（非图片）；制作源见来源资料",
        "当前文件实测=" + static_size + "；这是现状记录，不自动批准为全类规格" if is_image else "不适用像素尺寸；见文件格式及技术参数",
        import_size, spec["display"], str(measured.get("format", ext)) + (" / " + measured["mode"] if "mode" in measured else "") + alpha,
        spec["composition"], spec["align"], spec["split"], spec["forbidden"], file.name, path,
        ("静态证据：" + integration if integration else "未发现完整路径或已知加载器映射") + "；可达性与实际显示仍需运行确认",
        settings or "无独立.import；见资源文件自身参数与消费组件", spec["environment"],
        source_description,
        f"当前文件SHA-256={measured['sha256']}；" + ("历史条目记录（不等于本次审核）：" + "；".join(dict.fromkeys(revisions)) if revisions else "历史版本／变更摘要待补充"),
        "制作：Art；接入：Programmer；验收：QA；具体人员与签名待补充" if spec["category"] != "audio" else "音频制作／接入／审核人员待补充",
        identity(path, refs, metadata) + "；本次仅盘点与技术测量，人工审核待完成；运行／截图 NOT VERIFIED",
    ]))
    stale_review = False
    for key, value in override.get("fields", {}).items():
        if key not in FIELDS or not isinstance(value, str):
            raise ValueError(f"Invalid manual field {path}: {key}")
        if key == "当前状态" and override.get("reviewed_sha256") != measured["sha256"]:
            stale_review = True
        else:
            record_fields[key] = value
    qa = {k: {"result": "待检查", "evidence": "尚未进行本次人工验收"} for k in QA_FIELDS}
    qa["文件、尺寸与命名"] = {"result": "已盘点／已测量；命名合规待审核", "evidence": "实际文件、技术参数与SHA-256；不是设计验收PASS"}
    qa["Godot 编辑器与运行时"] = {"result": "NOT VERIFIED", "evidence": "本次未启动Godot或截图，不沿用历史PASS"}
    if not is_image:
        qa["透明边缘与裁切"] = {"result": "不适用图片Alpha检查", "evidence": "非图片；音频／材质／shader须在实际效果中另验"}
    for key, value in override.get("qa", {}).items():
        if key not in QA_FIELDS or not isinstance(value, dict) or not value.get("result") or not value.get("evidence"):
            raise ValueError(f"Manual QA requires a known field and evidence: {path} {key}")
        if override.get("reviewed_sha256") == measured["sha256"]:
            qa[key] = value
        else:
            stale_review = True
    if stale_review:
        record_fields["当前状态"] += "；人工验收哈希与当前文件不一致，需重新验收"
    return dict(id=path, category=spec["category"], fields=record_fields, measurement=measured,
                refs=refs, metadata=metadata, business=business, supporting_files=nearby_docs(file),
                animation_or_effect=spec["extra"], qa=qa, manual_evidence=override.get("evidence", []))


def cell(value) -> str:
    return str(value).replace("|", "\\|").replace("\n", "<br>").replace("\r", "")


def link(path: str, base: Path) -> str:
    import os
    return quote(Path(os.path.relpath(ROOT / path, base)).as_posix(), safe="/.-_")


def record_md(record: dict) -> str:
    path = record["id"]
    lines = [f"<a id=\"{record['anchor']}\"></a>", f"## {Path(path).name}", "",
             f"[打开资产]({link(path, OUT / 'tables')}) · [总目录](../README.md)", "",
             "| 字段 | 当前交付记录 |", "| --- | --- |"]
    lines += [f"| {k} | {cell(v)} |" for k, v in record["fields"].items()]
    lines += [f"| 动画／特效专项 | {cell(record['animation_or_effect'])} |", "",
              "| 检查项 | 结果 | 证据／问题 |", "| --- | --- | --- |"]
    lines += [f"| {k} | {cell(v['result'])} | {cell(v['evidence'])} |" for k, v in record["qa"].items()]
    lines += ["", "技术测量：", "", "```json", json.dumps(record["measurement"], ensure_ascii=False, indent=2), "```", "",
              "证据入口（静态引用与历史元数据均不等于本次验收通过）：", ""]
    lines += [f"- {r['kind']}：[{r['file']}]({link(r['file'], OUT / 'tables')})" + (f"，行 {r['line']}" if r["line"] else "") for r in record["refs"]]
    lines += [f"- 生产资料：[{p}]({link(p, OUT / 'tables')})" for p in record["supporting_files"]]
    if record["metadata"] or record["business"] or record["manual_evidence"]:
        lines += ["", "```json", json.dumps({"metadata": record["metadata"], "business": record["business"],
                                             "manual_evidence": record["manual_evidence"]}, ensure_ascii=False, indent=2), "```"]
    return "\n".join(lines) + "\n"


def save(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists() or read(path) != content:
        path.write_text(content, encoding="utf-8", newline="\n")


def build():
    files = asset_files()
    paths = {rel(p) for p in files}
    overrides_path = OUT / "overrides.json"
    overrides = json.loads(read(overrides_path))["assets"]
    missing_overrides = set(overrides) - paths
    if missing_overrides:
        raise ValueError(f"Manual entries reference missing files; resolve them before rebuild: {sorted(missing_overrides)}")
    refs, metadata, business = collect_evidence(paths)
    records = []
    for file in files:
        name = rel(file)
        record = make_record(file, refs[name], metadata[name], business[name], overrides.get(name, {}))
        record["anchor"] = "asset-" + hashlib.sha256(name.encode()).hexdigest()[:16]
        records.append(record)
    groups = defaultdict(list)
    for record in records:
        groups[record["category"]].append(record)
    outputs = set()
    index = ["# 《炽窑》美术资产交付目录", "", "[打开可搜索校对页](index.html) · [交付规范与模板](../../AI_Studio/Design/Art/ASSET_DELIVERY.md) · [人工确认入口](overrides.json)", "",
             f"当前覆盖 **{len(records)}** 个资产文件；每个文件都有24项交付字段、专项说明和6项验收记录。",
             "", "包含 art/ 全部图片、动画预览、shader、资源配置与音频，另含 themes/ 的资源配置及根目录图标／字体。",
             "不收录 .import/.uid 缓存、元数据JSON、脚本、ZIP、临时文件、插件和测试截图；相关生产资料作为证据链接。",
             "候选、源图、参考与旧方案全部保留登记；未发现静态引用不代表未使用，发现引用也不代表运行通过。",
             "", "此目录由 tools/build_art_delivery.py 生成。人工确认写入 overrides.json，更新后重建；不要直接编辑生成表。",
             "", "| 类别 | 文件数 | 分册 |", "| --- | ---: | --- |"]
    for category, rows in sorted(groups.items()):
        pages = []
        for offset in range(0, len(rows), 50):
            batch = rows[offset:offset + 50]
            name = f"{category}-{offset // 50 + 1:02d}.md"
            output = OUT / "tables" / name
            for record in batch:
                record["table"] = "tables/" + name
            contents = [f"# {category} 交付表 · {offset // 50 + 1}", "", "[总目录](../README.md)", "",
                        "自动生成；人工修订填 ../overrides.json。尺寸为实际测量，专项要求与现状分别记录。", ""]
            contents += [f"- [{Path(r['id']).name}](#{r['anchor']}) — `{r['id']}`" for r in batch]
            contents += ["", *[record_md(r) for r in batch]]
            save(output, "\n".join(contents))
            outputs.add(name)
            pages.append(f"[第{offset // 50 + 1}册](tables/{name})")
        index.append(f"| {category} | {len(rows)} | {' · '.join(pages)} |")
    # Only remove stale generated pages after checking their absolute location and name.
    table_root = (OUT / "tables").resolve()
    for old in table_root.glob("*.md"):
        if old.name not in outputs and old.resolve().parent == table_root and re.fullmatch(r"[a-z]+-\d+\.md", old.name):
            old.unlink()
    save(OUT / "README.md", "\n".join(index) + "\n")
    catalog = {"schema_version": 1, "coverage": dict(sorted(Counter(r["category"] for r in records).items())),
               "count": len(records), "records": records}
    save(OUT / "catalog.json", json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    template = read(ROOT / "tools/art_delivery_view.html")
    data = json.dumps(catalog, ensure_ascii=False, separators=(",", ":")).replace("<", "\\u003c").replace("\u2028", "\\u2028").replace("\u2029", "\\u2029")
    save(OUT / "index.html", template.replace("__CATALOG_JSON__", data))
    print(json.dumps({"files": len(records), "pages": len(outputs), "categories": catalog["coverage"]}, ensure_ascii=False))


def check():
    catalog = json.loads(read(OUT / "catalog.json"))
    records = catalog["records"]
    current = {rel(p): p for p in asset_files()}
    assert len({r["id"] for r in records}) == len(records), "Duplicate asset keys"
    assert set(current) == {r["id"] for r in records}, "Inventory coverage changed; rebuild required"
    assert catalog["count"] == len(records)
    assert len({r["anchor"] for r in records}) == len(records), "Duplicate document anchors"
    stale = []
    for record in records:
        assert list(record["fields"]) == FIELDS, record["id"]
        assert set(record["qa"]) == set(QA_FIELDS), record["id"]
        for value in record["fields"].values():
            assert isinstance(value, str) and value.strip(), record["id"]
        if hashlib.sha256(current[record["id"]].read_bytes()).hexdigest() != record["measurement"]["sha256"]:
            stale.append(record["id"])
        table = OUT / record["table"]
        assert table.exists() and f'id="{record["anchor"]}"' in read(table), record["id"]
        for evidence in record["refs"] + record["metadata"]:
            assert (ROOT / evidence["file"]).exists(), evidence["file"]
        for source in record["supporting_files"]:
            assert (ROOT / source).exists(), source
    assert not stale, f"Assets changed since inventory: {stale}"
    page = read(OUT / "index.html")
    match = re.search(r'<script id="catalog" type="application/json">(.*?)</script>', page, re.S)
    assert match and json.loads(match.group(1)) == catalog, "Browser data and catalog differ"
    print(f"PASS: {len(records)} assets; exact coverage, unique IDs/anchors, complete fields, current hashes, evidence links and browser data. Godot/visual/audio QA: NOT VERIFIED.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="read-only coverage/integrity check")
    args = parser.parse_args()
    check() if args.check else build()

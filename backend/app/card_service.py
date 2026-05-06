"""
v0.6.0 卡牌服务 — 预设卡牌池生成 & 抽卡（含保底系统）
"""

import json
import random
import logging
from typing import Optional
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models import PresetCard, Card, UserPityCounter
from app.archetype_data import ARCHETYPES, RARITY_CONFIG, PITY_CONFIG, RARITY_NAMES
from app.balance_service import (
    scale_stat, scale_cost, energy_value_for_rarity, energy_level_for_rarity,
)
from app.dsl_service import validate_effects

logger = logging.getLogger(__name__)

# 卡牌名称用字（中文）
_NAME_SUFFIXES = [
    "玉", "明", "华", "清", "秀", "兰", "竹", "菊", "梅", "松", "柏", "莲", "桂",
    "仁", "义", "礼", "智", "信", "勇", "忠", "孝", "诚", "善", "美", "德", "道",
    "光", "辉", "耀", "灿", "煜", "熙", "煌", "烁", "晔", "晟", "曦", "燧",
    "渊", "海", "涛", "波", "澜", "瀚", "浩", "泓", "泽", "润", "洋", "江",
    "峰", "岳", "岩", "岭", "巍", "崇", "峻", "崖", "峦", "岗",
    "风", "云", "雨", "雷", "电", "霜", "雪", "霞", "虹", "霓",
    "剑", "璋", "瑜", "琳", "瑶", "琅", "瑾", "璇", "珩", "琬",
]


def _random_name(name_template: str) -> str:
    """用随机字填充名称模板中的{name}占位符。"""
    suffix = random.choice(_NAME_SUFFIXES)
    return name_template.replace("{name}", suffix)


def generate_card_id(faction: str, rarity: str, index: int) -> str:
    """生成唯一卡牌编号 e.g. HEALTH_IRON_001"""
    return f"{faction}_{rarity}_{index:03d}"


def generate_preset_pool(db: Session):
    """从原型生成365张预设卡牌池。删除所有旧卡牌并重建。"""
    logger.info("[CardService] 开始生成预设卡牌池...")

    # 删除所有旧的预设卡牌
    deleted = db.query(PresetCard).delete()
    logger.info(f"[CardService] 已删除{deleted}张旧预设卡牌")

    all_cards = []

    for faction, archetypes in ARCHETYPES.items():
        for arch in archetypes:
            rarity = arch["rarity"]
            quota = RARITY_CONFIG[rarity]["per_faction"]
            # 每个原型平均分配配额
            same_rarity = [a for a in archetypes if a["rarity"] == rarity]
            per_arch = quota // len(same_rarity)
            extras = quota % len(same_rarity)
            my_quota = per_arch + (1 if arch is same_rarity[0] else 0)

            # 如果extras给第一个，可能会超过。简化为：每个原型用自己的配额
            # 重新计算：直接对该稀有度的原型均分
            index_in_same = same_rarity.index(arch)
            my_quota = per_arch + (1 if index_in_same < extras else 0)

            for i in range(my_quota):
                name = _random_name(random.choice(arch["name_templates"]))
                card_idx = len([c for c in all_cards if c.faction == faction and c.rarity == rarity]) + 1
                card_id_num = len([c for c in all_cards if c.faction == faction]) + 1

                # 计算属性
                stats = {}
                if arch.get("base_stats"):
                    stats = {
                        "attack": scale_stat(arch["base_stats"]["attack"], rarity),
                        "health": scale_stat(arch["base_stats"]["health"], rarity),
                    }

                effects = arch.get("base_effects", [])
                tags = arch.get("tags", [])
                cost = scale_cost(arch.get("base_cost", 1), rarity)

                card = PresetCard(
                    card_id=generate_card_id(faction, rarity, card_id_num),
                    card_type=faction,
                    mantra=arch.get("lore_template", "").replace("{name}", name),
                    energy_level=energy_level_for_rarity(rarity),
                    name=name,
                    faction=faction,
                    rarity=rarity,
                    card_type_sub=arch["card_type"],
                    cost=cost,
                    stats_json=json.dumps(stats, ensure_ascii=False) if stats else None,
                    tags_json=json.dumps(tags, ensure_ascii=False),
                    effects_json=json.dumps(effects, ensure_ascii=False),
                    lore=arch.get("lore_template", "").replace("{name}", name),
                    archetype_id=arch["archetype_id"],
                    version=1,
                    status="RELEASED",
                )
                all_cards.append(card)

    db.add_all(all_cards)
    db.commit()
    logger.info(f"[CardService] 预设卡牌池生成完成，共{len(all_cards)}张")
    return len(all_cards)


def _roll_rarity(pity_gold: int, pity_black: int) -> str:
    """投掷稀有度骰子，计入保底。"""
    # 保底判定
    if pity_black >= PITY_CONFIG["black_gold_pity"]:
        return "BLACK_GOLD"
    if pity_gold >= PITY_CONFIG["gold_pity"]:
        return "GOLD"

    roll = random.random()
    cumulative = 0.0
    for rarity, config in RARITY_CONFIG.items():
        cumulative += config["rate"]
        if roll < cumulative:
            return rarity
    return "IRON"


def draw_card_gacha(
    db: Session,
    user_id: int,
    draw_type: str,  # "FREE" or "ENERGY"
) -> Card:
    """执行一次抽卡（含保底系统）。返回新创建的Card对象。"""

    # 确保用户有保底计数器
    pity = db.query(UserPityCounter).filter(
        UserPityCounter.user_id == user_id
    ).first()

    if not pity:
        pity = UserPityCounter(
            user_id=user_id,
            pulls_since_gold=0,
            pulls_since_black_gold=0,
        )
        db.add(pity)
        db.flush()

    # 投掷稀有度
    rarity = _roll_rarity(pity.pulls_since_gold, pity.pulls_since_black_gold)

    # 从预设卡牌中筛选该稀有度且已发行的卡牌
    candidates = db.query(PresetCard).filter(
        PresetCard.rarity == rarity,
        PresetCard.status == "RELEASED",
    ).all()

    if not candidates:
        # 回退到IRON（已发行）
        candidates = db.query(PresetCard).filter(
            PresetCard.rarity == "IRON",
            PresetCard.status == "RELEASED",
        ).all()
        rarity = "IRON"

    preset = random.choice(candidates)

    # 创建用户卡牌（复制所有字段）
    import json as _json
    card = Card(
        preset_card_id=preset.id,
        card_id_ref=preset.card_id,
        card_type=preset.card_type,
        mantra=preset.mantra,
        energy_level=preset.energy_level,
        energy_value=energy_value_for_rarity(rarity),
        energy_consumed=0,
        owner_id=user_id,
        gift_status="NORMAL",
        name=preset.name,
        faction=preset.faction,
        rarity=rarity,
        card_type_sub=preset.card_type_sub,
        cost=preset.cost,
        stats_json=preset.stats_json,
        tags_json=preset.tags_json,
        effects_json=preset.effects_json,
        lore=preset.lore,
        archetype_id=preset.archetype_id,
        version=1,
        image_url=preset.image_url,
        card_width=preset.card_width,
        card_height=preset.card_height,
        image_fit=preset.image_fit or "COVER",
        margin_top=preset.margin_top or 0,
        margin_left=preset.margin_left or 0,
        margin_bottom=preset.margin_bottom or 0,
        margin_right=preset.margin_right or 0,
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(card)
    db.flush()

    # 更新保底计数器
    if rarity in ("GOLD", "BLACK_GOLD"):
        pity.pulls_since_gold = 0
    else:
        pity.pulls_since_gold += 1

    if rarity == "BLACK_GOLD":
        pity.pulls_since_black_gold = 0
    else:
        pity.pulls_since_black_gold += 1

    db.commit()
    db.refresh(card)

    logger.info(
        f"[CardService] 用户{user_id}抽到{rarity}卡牌 {card.name} "
        f"(保底: G{pity.pulls_since_gold}/BG{pity.pulls_since_black_gold})"
    )

    return card


def get_pity_counters(db: Session, user_id: int) -> UserPityCounter:
    """获取用户的保底计数器。不存在则创建。"""
    pity = db.query(UserPityCounter).filter(
        UserPityCounter.user_id == user_id
    ).first()
    if not pity:
        pity = UserPityCounter(user_id=user_id, pulls_since_gold=0, pulls_since_black_gold=0)
        db.add(pity)
        db.commit()
        db.refresh(pity)
    return pity


def synthesize_cards(
    db: Session,
    user_id: int,
    card_ids: list[int],
) -> Optional[Card]:
    """3张同阵营同稀有度卡牌 → 1张下一稀有度卡牌。返回None表示不满足条件。"""
    if len(card_ids) != 3:
        return None

    cards = db.query(Card).filter(
        Card.id.in_(card_ids),
        Card.owner_id == user_id,
        Card.gift_status == "NORMAL",
    ).all()

    if len(cards) != 3:
        return None

    # 检查同阵营同稀有度
    factions = {c.faction for c in cards}
    rarities = {c.rarity for c in cards}
    if len(factions) != 1 or len(rarities) != 1:
        return None

    faction = factions.pop()
    old_rarity = rarities.pop()

    # 确定下一稀有度
    rarity_order = ["IRON", "BRONZE", "SILVER", "GOLD", "BLACK_GOLD"]
    old_idx = rarity_order.index(old_rarity) if old_rarity in rarity_order else 0
    if old_idx >= len(rarity_order) - 1:
        return None  # 已是最高稀有度
    new_rarity = rarity_order[old_idx + 1]

    # 从预设卡牌中选择新稀有度的卡牌
    candidates = db.query(PresetCard).filter(
        PresetCard.faction == faction,
        PresetCard.rarity == new_rarity,
    ).all()

    if not candidates:
        # 回退：该阵营任何该稀有度
        candidates = db.query(PresetCard).filter(
            PresetCard.rarity == new_rarity,
        ).all()

    if not candidates:
        return None

    preset = random.choice(candidates)

    # 删除3张旧卡牌
    for c in cards:
        db.delete(c)

    # 创建新卡牌
    import json as _json
    new_card = Card(
        preset_card_id=preset.id,
        card_id_ref=preset.card_id,
        card_type=preset.card_type,
        mantra=preset.mantra,
        energy_level=preset.energy_level,
        energy_value=energy_value_for_rarity(new_rarity),
        energy_consumed=0,
        owner_id=user_id,
        gift_status="NORMAL",
        name=preset.name,
        faction=preset.faction,
        rarity=new_rarity,
        card_type_sub=preset.card_type_sub,
        cost=preset.cost,
        stats_json=preset.stats_json,
        tags_json=preset.tags_json,
        effects_json=preset.effects_json,
        lore=preset.lore,
        archetype_id=preset.archetype_id,
        version=1,
        image_url=preset.image_url,
        card_width=preset.card_width,
        card_height=preset.card_height,
        image_fit=preset.image_fit or "COVER",
        margin_top=preset.margin_top or 0,
        margin_left=preset.margin_left or 0,
        margin_bottom=preset.margin_bottom or 0,
        margin_right=preset.margin_right or 0,
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(new_card)
    db.commit()
    db.refresh(new_card)

    logger.info(f"[CardService] 合成: 3×{old_rarity} → {new_rarity} {new_card.name}")
    return new_card

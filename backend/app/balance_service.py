"""
v0.6.0 平衡性服务 — 稀有度修正、能量值计算、费用缩放
"""

import random
from app.archetype_data import RARITY_CONFIG


def rarity_multiplier(rarity: str) -> float:
    """获取稀有度的数值倍率。"""
    return RARITY_CONFIG.get(rarity, {}).get("multiplier", 1.0)


def energy_value_for_rarity(rarity: str) -> int:
    """根据稀有度生成能量值（用于旧版兼容的energy_value字段）。"""
    ranges = {
        "IRON": (1, 4),
        "BRONZE": (5, 8),
        "SILVER": (9, 16),
        "GOLD": (17, 32),
        "BLACK_GOLD": (33, 64),
    }
    lo, hi = ranges.get(rarity, (1, 4))
    return random.randint(lo, hi)


def scale_stat(base: int, rarity: str) -> int:
    """根据稀有度缩放属性值（攻击/生命）。"""
    mult = rarity_multiplier(rarity)
    return max(1, round(base * mult))


def scale_cost(base_cost: int, rarity: str) -> int:
    """根据稀有度缩放费用。高稀有度的卡牌费用更高。"""
    cost_mult = {
        "IRON": 0.8,
        "BRONZE": 1.0,
        "SILVER": 1.3,
        "GOLD": 1.6,
        "BLACK_GOLD": 2.0,
    }
    mult = cost_mult.get(rarity, 1.0)
    return max(1, round(base_cost * mult))


def energy_level_for_rarity(rarity: str) -> int:
    """稀有度映射到旧版能量等级（1-5）。"""
    return RARITY_CONFIG.get(rarity, {}).get("energy_level", 1)

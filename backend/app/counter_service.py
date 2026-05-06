"""
v0.6.0 阵营克制服务
Health > Wealth > Family > Love > Career > Health
"""

from app.archetype_data import COUNTER_MAP


def get_counter_multiplier(attacker_faction: str, defender_faction: str) -> float:
    """计算阵营克制倍率。1.5x 克制, 1.0x 中立, 0.75x 被克制。"""
    if attacker_faction == defender_faction:
        return 1.0
    counters = COUNTER_MAP.get(attacker_faction, {})
    return counters.get(defender_faction, 1.0)


def get_faction_advantage_text(attacker_faction: str, defender_faction: str) -> str:
    """返回克制关系的文字描述。"""
    mult = get_counter_multiplier(attacker_faction, defender_faction)
    if mult > 1.0:
        return f"克制（{mult}x）"
    elif mult < 1.0:
        return f"被克制（{mult}x）"
    return "中立"

"""
v0.6.0 DSL 效果服务 — 解析和验证卡牌效果定义

效果类型:
  heal, shield, damage, buff, debuff, summon, draw,
  revive, steal, combo, risk_reward, redirect, control,
  link, scaling, resource_gen, gold_multiply, bloodline,
  cost_reduce

效果JSON格式:
  {"type": "heal", "target": "self", "value": 2, "condition": "on_summon", "subtype": null}
"""

from typing import Any

VALID_EFFECT_TYPES = {
    "heal", "shield", "damage", "buff", "debuff", "summon", "draw",
    "revive", "steal", "combo", "risk_reward", "redirect", "control",
    "link", "scaling", "resource_gen", "gold_multiply", "bloodline",
    "cost_reduce",
}

VALID_TARGETS = {
    "self", "target_ally", "target_enemy", "all_allies", "all_enemies",
    "all", "random_ally", "random_enemy", "same_faction", "all_family",
    "linked_ally", "linked", "controlled_enemy", "bearer", "summoned",
    "next_card", "target_enemy_attack", "all_enemy_attacks",
}

VALID_CONDITIONS = {
    "on_summon", "on_attack", "on_death", "on_death_ally", "on_death_any",
    "on_turn_start", "on_turn_end", "on_damaged", "on_steal",
    "on_ally_buffed", "on_ally_summon", "on_any_action",
    "on_next_action", "on_family_death", "on_any_card_played",
    "on_linked", "on_success", "on_combo_3", "on_combo_5",
    "on_gold_5", "on_gold_10", "on_gold_20", "on_gold_30",
    "on_turn_5", "on_scaling_max", "faith_threshold_5", "faith_threshold_7",
    "on_controlled", None,
}

MAX_EFFECTS_PER_CARD = 6


def validate_effects(effects: list[dict[str, Any]]) -> bool:
    """验证效果列表是否合法。"""
    if not effects or not isinstance(effects, list):
        return False
    if len(effects) > MAX_EFFECTS_PER_CARD:
        return False
    for e in effects:
        if not isinstance(e, dict):
            return False
        if e.get("type") not in VALID_EFFECT_TYPES:
            return False
        if e.get("target") not in VALID_TARGETS:
            return False
        if e.get("condition") not in VALID_CONDITIONS:
            return False
        if not isinstance(e.get("value"), (int, float)):
            return False
    return True


def get_effect_description(effect: dict[str, Any]) -> str:
    """生成效果的人类可读描述。"""
    t = effect.get("type", "")
    target = effect.get("target", "self")
    value = effect.get("value", 0)
    condition = effect.get("condition")
    subtype = effect.get("subtype", "")

    target_names = {
        "self": "自己", "target_ally": "目标友方", "target_enemy": "目标敌方",
        "all_allies": "所有友方", "all_enemies": "所有敌方", "all": "所有单位",
        "random_ally": "随机友方", "random_enemy": "随机敌方",
        "same_faction": "同阵营", "all_family": "所有家人",
        "linked_ally": "链接友方", "linked": "链接单位",
        "controlled_enemy": "被控敌方", "bearer": "持有者",
        "summoned": "召唤物", "next_card": "下一张卡牌",
    }

    type_names = {
        "heal": "恢复", "shield": "护盾", "damage": "伤害",
        "buff": "增益", "debuff": "减益", "summon": "召唤",
        "draw": "抽牌", "revive": "复活", "steal": "偷取",
        "combo": "连击", "risk_reward": "风险回报",
        "redirect": "重定向", "control": "控制", "link": "链接",
        "scaling": "成长", "resource_gen": "资源生成",
        "gold_multiply": "金币倍增", "bloodline": "血脉",
        "cost_reduce": "减费",
    }

    subtype_names = {
        "attack": "攻击力", "health": "生命值", "max_health": "最大生命",
        "all": "全属性", "gold": "金币", "gold_per_turn": "每回合金币",
        "cost_reduction": "费用减免",
        "TOKEN_1_1": "1/1精灵", "TOKEN_2_2": "2/2精灵", "TOKEN_3_3": "3/3精灵",
    }

    cond_names = {
        "on_summon": "登场时", "on_attack": "攻击时", "on_death": "死亡时",
        "on_death_ally": "友方死亡时", "on_death_any": "任意死亡时",
        "on_turn_start": "回合开始时", "on_turn_end": "回合结束时",
        "on_damaged": "受伤时", "on_steal": "偷取时",
    }

    t_name = type_names.get(t, t)
    target_name = target_names.get(target, target)
    s_name = subtype_names.get(subtype, subtype)

    desc = f"{t_name} {target_name} {value}点"
    if subtype:
        desc += f" {s_name}"
    if condition and condition in cond_names:
        desc = f"{cond_names[condition]}，" + desc[0].lower() + desc[1:]
    elif condition:
        desc += f" [条件:{condition}]"

    return desc

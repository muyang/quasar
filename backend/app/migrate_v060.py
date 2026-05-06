"""
v0.6.0 数据库迁移：卡牌系统升级
- 为 preset_cards 和 cards 添加新列
- 创建 card_archetypes 表
- 创建 user_pity_counters 表
"""

import logging
from sqlalchemy import text
from app.database import engine

logger = logging.getLogger(__name__)

MIGRATIONS = [
    # preset_cards 新列
    ("ALTER TABLE preset_cards ADD COLUMN card_id TEXT", True),
    ("ALTER TABLE preset_cards ADD COLUMN name TEXT", True),
    ("ALTER TABLE preset_cards ADD COLUMN faction TEXT", True),
    ("ALTER TABLE preset_cards ADD COLUMN rarity TEXT", True),
    ("ALTER TABLE preset_cards ADD COLUMN card_type_sub TEXT", True),
    ("ALTER TABLE preset_cards ADD COLUMN cost INTEGER", True),
    ("ALTER TABLE preset_cards ADD COLUMN stats_json TEXT", True),
    ("ALTER TABLE preset_cards ADD COLUMN tags_json TEXT", True),
    ("ALTER TABLE preset_cards ADD COLUMN effects_json TEXT", True),
    ("ALTER TABLE preset_cards ADD COLUMN lore TEXT", True),
    ("ALTER TABLE preset_cards ADD COLUMN archetype_id TEXT", True),
    ("ALTER TABLE preset_cards ADD COLUMN version INTEGER DEFAULT 1", True),
    # cards 新列
    ("ALTER TABLE cards ADD COLUMN card_id_ref TEXT", True),
    ("ALTER TABLE cards ADD COLUMN name TEXT", True),
    ("ALTER TABLE cards ADD COLUMN faction TEXT", True),
    ("ALTER TABLE cards ADD COLUMN rarity TEXT", True),
    ("ALTER TABLE cards ADD COLUMN card_type_sub TEXT", True),
    ("ALTER TABLE cards ADD COLUMN cost INTEGER", True),
    ("ALTER TABLE cards ADD COLUMN stats_json TEXT", True),
    ("ALTER TABLE cards ADD COLUMN tags_json TEXT", True),
    ("ALTER TABLE cards ADD COLUMN effects_json TEXT", True),
    ("ALTER TABLE cards ADD COLUMN lore TEXT", True),
    ("ALTER TABLE cards ADD COLUMN archetype_id TEXT", True),
    ("ALTER TABLE cards ADD COLUMN version INTEGER DEFAULT 1", True),
    # messages 新列 (Part B - may already exist)
    ("ALTER TABLE messages ADD COLUMN card_id INTEGER REFERENCES cards(id)", True),
    ("ALTER TABLE messages ADD COLUMN msg_subtype TEXT", True),
    # plaza_posts 新列 (Part C / v0.6.0)
    ("ALTER TABLE plaza_posts ADD COLUMN user_nickname TEXT", True),
    # v0.7.0 卡牌布局与发行状态 — preset_cards
    ("ALTER TABLE preset_cards ADD COLUMN status TEXT NOT NULL DEFAULT 'PENDING'", True),
    ("ALTER TABLE preset_cards ADD COLUMN card_width INTEGER", True),
    ("ALTER TABLE preset_cards ADD COLUMN card_height INTEGER", True),
    ("ALTER TABLE preset_cards ADD COLUMN image_fit TEXT NOT NULL DEFAULT 'COVER'", True),
    ("ALTER TABLE preset_cards ADD COLUMN margin_top INTEGER NOT NULL DEFAULT 0", True),
    ("ALTER TABLE preset_cards ADD COLUMN margin_left INTEGER NOT NULL DEFAULT 0", True),
    ("ALTER TABLE preset_cards ADD COLUMN margin_bottom INTEGER NOT NULL DEFAULT 0", True),
    ("ALTER TABLE preset_cards ADD COLUMN margin_right INTEGER NOT NULL DEFAULT 0", True),
    # v0.7.0 卡牌布局 — cards
    ("ALTER TABLE cards ADD COLUMN card_width INTEGER", True),
    ("ALTER TABLE cards ADD COLUMN card_height INTEGER", True),
    ("ALTER TABLE cards ADD COLUMN image_fit TEXT DEFAULT 'COVER'", True),
    ("ALTER TABLE cards ADD COLUMN margin_top INTEGER NOT NULL DEFAULT 0", True),
    ("ALTER TABLE cards ADD COLUMN margin_left INTEGER NOT NULL DEFAULT 0", True),
    ("ALTER TABLE cards ADD COLUMN margin_bottom INTEGER NOT NULL DEFAULT 0", True),
    ("ALTER TABLE cards ADD COLUMN margin_right INTEGER NOT NULL DEFAULT 0", True),
    # 新表
    (
        """CREATE TABLE IF NOT EXISTS card_archetypes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            archetype_id TEXT UNIQUE NOT NULL,
            faction TEXT NOT NULL,
            rarity TEXT NOT NULL,
            card_type TEXT NOT NULL,
            name_templates_json TEXT NOT NULL,
            base_cost INTEGER NOT NULL DEFAULT 1,
            base_stats_json TEXT,
            base_effects_json TEXT,
            lore_template TEXT,
            tags_json TEXT,
            version INTEGER NOT NULL DEFAULT 1,
            is_active BOOLEAN NOT NULL DEFAULT 1
        )""",
        False,
    ),
    (
        """CREATE TABLE IF NOT EXISTS user_pity_counters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL UNIQUE REFERENCES users(id),
            pulls_since_gold INTEGER NOT NULL DEFAULT 0,
            pulls_since_black_gold INTEGER NOT NULL DEFAULT 0
        )""",
        False,
    ),
]


def run_migration_v060():
    """执行 v0.6.0 迁移。忽略列已存在的错误。"""
    logger.info("[v0.6.0] 开始数据库迁移...")
    with engine.connect() as conn:
        for sql, ignore_dup in MIGRATIONS:
            try:
                conn.execute(text(sql))
                conn.commit()
            except Exception as e:
                if ignore_dup and ("duplicate column" in str(e).lower() or "already exists" in str(e).lower()):
                    pass  # 列已存在，跳过
                else:
                    logger.warning(f"[v0.6.0] 迁移警告 ({sql[:50]}...): {e}")
    logger.info("[v0.6.0] 数据库迁移完成")

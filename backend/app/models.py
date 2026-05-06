from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, UniqueConstraint
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    nickname = Column(String, nullable=False)
    is_admin = Column(Boolean, nullable=False, default=False)
    created_at = Column(String, nullable=False)


class EnergyStone(Base):
    __tablename__ = "energy_stones"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    unique_code = Column(String, unique=True, nullable=False)  # 石头唯一编号 如 CRY-000001
    stone_type = Column(String, nullable=False)  # 类型: HEALTH/LOVE/WEALTH/CAREER/FAMILY
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # 绑定的主人ID
    current_energy = Column(Integer, nullable=False, default=10)
    death_count = Column(Integer, nullable=False, default=0)
    status = Column(String, nullable=False, default="ALIVE")
    consecutive_days = Column(Integer, nullable=False, default=0)  # 连续打卡天数
    last_charge_time = Column(String, nullable=True)
    last_check_in_date = Column(String, nullable=True)  # 上次打卡日期 YYYY-MM-DD


class CheckInRecord(Base):
    __tablename__ = "check_in_records"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    stone_id = Column(Integer, ForeignKey("energy_stones.id"), nullable=False, index=True)
    check_in_date = Column(String, nullable=False)  # YYYY-MM-DD 格式
    energy_before = Column(Integer, nullable=False)
    energy_after = Column(Integer, nullable=False)
    energy_gained = Column(Integer, nullable=False)  # 实际获得的能量值
    base_gain = Column(Integer, nullable=False)  # 基础能量值（1-5）
    multiplier = Column(Integer, nullable=False)  # 倍数
    consecutive_days = Column(Integer, nullable=False)  # 当时的连续天数
    blessing = Column(String, nullable=False)
    created_at = Column(String, nullable=False)


class TransferRecord(Base):
    __tablename__ = "transfer_records"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    from_stone_id = Column(Integer, ForeignKey("energy_stones.id"), nullable=False, index=True)
    to_stone_id = Column(Integer, ForeignKey("energy_stones.id"), nullable=False, index=True)
    energy_amount = Column(Integer, nullable=False)
    created_at = Column(String, nullable=False)


class PresetCard(Base):
    """预设卡牌池（365张卡牌）"""
    __tablename__ = "preset_cards"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    card_id = Column(String, unique=True, nullable=True)  # 唯一编号 e.g. HEALTH_IRON_001
    card_type = Column(String, nullable=False)  # HEALTH/LOVE/WEALTH/CAREER/FAMILY
    mantra = Column(String, nullable=False)  # 咒语（圣经/佛经/名人名言）
    energy_level = Column(Integer, nullable=False)  # 能量等级: 1-5
    name = Column(String, nullable=True)  # 卡牌名称
    faction = Column(String, nullable=True)  # 阵营（同card_type）
    rarity = Column(String, nullable=True)  # 稀有度: IRON/BRONZE/SILVER/GOLD/BLACK_GOLD
    card_type_sub = Column(String, nullable=True)  # 子类型: UNIT/SPELL/ITEM/RELIC
    cost = Column(Integer, nullable=True)  # 费用
    stats_json = Column(String, nullable=True)  # JSON: {"attack": N, "health": N}
    tags_json = Column(String, nullable=True)  # JSON: ["heal","faith",...]
    effects_json = Column(String, nullable=True)  # JSON DSL effect array
    lore = Column(String, nullable=True)  # 背景故事
    archetype_id = Column(String, nullable=True)  # FK → card_archetypes.archetype_id
    version = Column(Integer, nullable=False, default=1)
    image_url = Column(String, nullable=True)  # 卡牌图片URL（为空则使用默认图）
    # v0.7.0 卡牌布局与发行状态
    status = Column(String, nullable=False, default="PENDING")  # PENDING=待发行 / RELEASED=已发行
    card_width = Column(Integer, nullable=True)  # 卡牌宽度（像素）
    card_height = Column(Integer, nullable=True)  # 卡牌高度（像素）
    image_fit = Column(String, nullable=False, default="COVER")  # 图片填充: COVER/CONTAIN/FILL/CENTER/FIT_WIDTH/FIT_HEIGHT/NONE
    margin_top = Column(Integer, nullable=False, default=0)
    margin_left = Column(Integer, nullable=False, default=0)
    margin_bottom = Column(Integer, nullable=False, default=0)
    margin_right = Column(Integer, nullable=False, default=0)


class Card(Base):
    """用户持有的卡牌"""
    __tablename__ = "cards"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    preset_card_id = Column(Integer, ForeignKey("preset_cards.id"), nullable=False)  # 关联预设卡牌
    card_id_ref = Column(String, nullable=True)  # reference to preset card_id
    card_type = Column(String, nullable=False)  # HEALTH/LOVE/WEALTH/CAREER/FAMILY
    mantra = Column(String, nullable=False)  # 咒语
    energy_level = Column(Integer, nullable=False)  # 能量等级: 1-5
    energy_value = Column(Integer, nullable=False)  # 能量值
    energy_consumed = Column(Integer, nullable=False, default=0)  # 已消耗能量值
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # 所属用户
    gift_status = Column(String, nullable=False, default="NORMAL")  # NORMAL/PENDING/RECEIVED 赠送状态
    gift_from_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # 赠送者ID
    name = Column(String, nullable=True)  # 卡牌名称
    faction = Column(String, nullable=True)  # 阵营
    rarity = Column(String, nullable=True)  # 稀有度
    card_type_sub = Column(String, nullable=True)  # 子类型: UNIT/SPELL/ITEM/RELIC
    cost = Column(Integer, nullable=True)  # 费用
    stats_json = Column(String, nullable=True)  # JSON stats
    tags_json = Column(String, nullable=True)  # JSON tags
    effects_json = Column(String, nullable=True)  # JSON effects
    lore = Column(String, nullable=True)  # 背景故事
    archetype_id = Column(String, nullable=True)  # archetype reference
    version = Column(Integer, nullable=False, default=1)
    image_url = Column(String, nullable=True)  # 卡牌图片URL（从预设卡牌复制）
    # v0.7.0 卡牌布局（从预设卡牌复制）
    card_width = Column(Integer, nullable=True)
    card_height = Column(Integer, nullable=True)
    image_fit = Column(String, nullable=True, default="COVER")
    margin_top = Column(Integer, nullable=False, default=0)
    margin_left = Column(Integer, nullable=False, default=0)
    margin_bottom = Column(Integer, nullable=False, default=0)
    margin_right = Column(Integer, nullable=False, default=0)
    created_at = Column(String, nullable=False)


class UserDrawRecord(Base):
    """用户抽卡记录"""
    __tablename__ = "user_draw_records"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    draw_date = Column(String, nullable=False)  # YYYY-MM-DD
    draw_type = Column(String, nullable=False)  # FREE（打卡免费）/ ENERGY（能量消耗）
    card_id = Column(Integer, ForeignKey("cards.id"), nullable=False)
    created_at = Column(String, nullable=False)


class StoreItem(Base):
    """商店物品（水晶石、能量包等）"""
    __tablename__ = "store_items"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    item_type = Column(String, nullable=False)  # STONE / ENERGY_PACK
    name = Column(String, nullable=False)
    stone_type = Column(String, nullable=True)  # 仅STONE类型时有值
    energy_amount = Column(Integer, nullable=False, default=0)  # 能量包给的能量值
    price = Column(Integer, nullable=False)  # 价格（消耗能量点数）
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(String, nullable=False)


class Message(Base):
    """消息系统（公告/用户私信/系统消息）"""
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # null = 系统发送
    receiver_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # null = 广播/公告
    msg_type = Column(String, nullable=False)  # ANNOUNCEMENT / USER_MSG / SYSTEM
    msg_subtype = Column(String, nullable=True)  # GIFT_CARD for card gift notifications
    card_id = Column(Integer, ForeignKey("cards.id"), nullable=True)  # linked card for gift messages
    title = Column(String, nullable=False)
    content = Column(String, nullable=False)
    is_read = Column(Boolean, nullable=False, default=False)
    created_at = Column(String, nullable=False)


class PlazaPost(Base):
    """广场帖子（祈福/许愿/活动/公告）"""
    __tablename__ = "plaza_posts"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # null = 平台官方
    user_nickname = Column(String, nullable=True)  # denormalized for display
    post_type = Column(String, nullable=False)  # BLESSING / WISH / ACTIVITY / ANNOUNCEMENT
    content = Column(String, nullable=False)
    pray_count = Column(Integer, nullable=False, default=0)
    created_at = Column(String, nullable=False)


class PlazaPray(Base):
    """广场祈福记录"""
    __tablename__ = "plaza_prays"
    __table_args__ = (UniqueConstraint("post_id", "user_id"),)

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    post_id = Column(Integer, ForeignKey("plaza_posts.id"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(String, nullable=False)


class CardArchetype(Base):
    """卡牌原型（用于生成预设卡牌池）"""
    __tablename__ = "card_archetypes"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    archetype_id = Column(String, unique=True, nullable=False)  # e.g. HEALTH_IRON_HEALER
    faction = Column(String, nullable=False)  # HEALTH/LOVE/WEALTH/CAREER/FAMILY
    rarity = Column(String, nullable=False)  # IRON/BRONZE/SILVER/GOLD/BLACK_GOLD
    card_type = Column(String, nullable=False)  # UNIT/SPELL/ITEM/RELIC
    name_templates_json = Column(String, nullable=False)  # JSON array of name templates
    base_cost = Column(Integer, nullable=False, default=1)
    base_stats_json = Column(String, nullable=True)  # JSON {"attack": N, "health": N}
    base_effects_json = Column(String, nullable=True)  # JSON DSL effects array
    lore_template = Column(String, nullable=True)  # 背景故事模板
    tags_json = Column(String, nullable=True)  # JSON tags array
    version = Column(Integer, nullable=False, default=1)
    is_active = Column(Boolean, nullable=False, default=True)


class UserPityCounter(Base):
    """用户抽卡保底计数器"""
    __tablename__ = "user_pity_counters"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True, index=True)
    pulls_since_gold = Column(Integer, nullable=False, default=0)  # 距上次Gold的抽数
    pulls_since_black_gold = Column(Integer, nullable=False, default=0)  # 距上次BlackGold的抽数
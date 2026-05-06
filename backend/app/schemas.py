from pydantic import BaseModel, ConfigDict
from typing import Optional, List


class ChargeResponse(BaseModel):
    stone_id: int
    energy_before: int
    energy_after: int
    energy_gained: int
    base_gain: int
    multiplier: int
    consecutive_days: int
    blessing: str
    status: str
    free_draw_available: bool = False  # 打卡后是否获得免费抽卡机会


class StoneStatus(BaseModel):
    id: int
    unique_code: str
    stone_type: str
    owner_id: Optional[int]
    current_energy: int
    death_count: int
    status: str
    consecutive_days: int
    last_charge_time: Optional[str]


class CheckInStatusResponse(BaseModel):
    can_check_in: bool
    message: Optional[str] = None
    consecutive_days: int = 0
    next_multiplier: int = 1


class CheckInRecordResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    stone_id: int
    check_in_date: str
    energy_before: int
    energy_after: int
    energy_gained: int
    base_gain: int
    multiplier: int
    consecutive_days: int
    blessing: str


class CheckInRecordsResponse(BaseModel):
    records: List[CheckInRecordResponse]


class UserResponse(BaseModel):
    id: int
    nickname: str
    created_at: str
    stones: List[StoneStatus] = []


class UserRegisterRequest(BaseModel):
    nickname: str


class LoginByStoneRequest(BaseModel):
    unique_code: str  # 石头唯一编号


class StoneCreateRequest(BaseModel):
    user_id: int
    stone_type: str  # HEALTH/LOVE/WEALTH/CAREER/FAMILY


class StoneBindRequest(BaseModel):
    user_id: int
    unique_code: str


class TransferRequest(BaseModel):
    from_stone_id: int
    to_receiver: str  # 接收者：可以是用户ID（数字）或石头编号（字符串）
    energy_amount: int


class TransferResponse(BaseModel):
    success: bool
    from_stone_id: int
    to_stone_id: int
    to_owner_id: Optional[int]
    to_owner_nickname: Optional[str]
    energy_amount: int
    from_stone_energy: int
    to_stone_energy: int
    message: str


class StoneDetailResponse(BaseModel):
    id: int
    unique_code: str
    stone_type: str
    stone_type_name: str
    color_code: str
    owner_id: Optional[int]
    owner_nickname: Optional[str]
    current_energy: int
    energy_cap: int
    death_count: int
    status: str
    consecutive_days: int
    next_multiplier: int
    can_transfer: bool  # 是否可以转赠（有能量且未死亡）


class StoneListResponse(BaseModel):
    stones: List[StoneDetailResponse]


# ==================== 卡牌相关 Schema ====================

ENERGY_LEVELS = {
    1: {"min": 1, "max": 4, "name": "微光"},
    2: {"min": 5, "max": 8, "name": "闪烁"},
    3: {"min": 9, "max": 16, "name": "明亮"},
    4: {"min": 17, "max": 32, "name": "璀璨"},
    5: {"min": 33, "max": 64, "name": "耀目"},
}

CARD_TYPE_NAMES = {
    "HEALTH": "健康",
    "LOVE": "爱情",
    "WEALTH": "财富",
    "CAREER": "事业",
    "FAMILY": "家庭",
}

STONE_TYPES = {
    "HEALTH": {"name": "健康", "color": "green", "color_code": "#4CAF50"},
    "LOVE": {"name": "爱情", "color": "pink", "color_code": "#E91E63"},
    "WEALTH": {"name": "财富", "color": "gold", "color_code": "#FFD700"},
    "CAREER": {"name": "事业", "color": "red", "color_code": "#F44336"},
    "FAMILY": {"name": "家庭", "color": "blue", "color_code": "#2196F3"},
}

RARITY_NAMES = {
    "IRON": "赤铁",
    "BRONZE": "青铜",
    "SILVER": "白银",
    "GOLD": "黄金",
    "BLACK_GOLD": "黑金",
}

RARITY_COLORS = {
    "IRON": "#B7410E",     # 铁锈红
    "BRONZE": "#CD7F32",   # 青铜色
    "SILVER": "#A8A9AD",   # 银灰色
    "GOLD": "#FFD700",     # 黄金色
    "BLACK_GOLD": "#1C1C1A", # 黑金色
}

CARD_TYPE_SUB_NAMES = {
    "UNIT": "单位",
    "SPELL": "法术",
    "ITEM": "装备",
    "RELIC": "遗物",
}


class CardStats(BaseModel):
    attack: int = 0
    health: int = 0


class CardEffect(BaseModel):
    type: str
    target: str
    value: float
    condition: Optional[str] = None
    subtype: Optional[str] = None
    max: Optional[int] = None
    risk: Optional[float] = None


class CardResponse(BaseModel):
    id: int
    card_type: str
    card_type_name: str
    mantra: str
    energy_level: int
    energy_level_name: str
    energy_value: int
    energy_consumed: int
    remaining_energy: int
    color_code: str
    can_charge: bool
    created_at: str
    image_url: Optional[str] = None
    # v0.6.0 新字段
    card_id: Optional[str] = None
    name: Optional[str] = None
    faction: Optional[str] = None
    rarity: Optional[str] = None
    rarity_name: Optional[str] = None
    card_type_sub: Optional[str] = None
    card_type_sub_name: Optional[str] = None
    cost: Optional[int] = None
    stats: Optional[CardStats] = None
    tags: Optional[List[str]] = None
    effects: Optional[List[CardEffect]] = None
    lore: Optional[str] = None
    # v0.7.0 卡牌布局
    card_width: Optional[int] = None
    card_height: Optional[int] = None
    image_fit: str = "COVER"
    margin_top: int = 0
    margin_left: int = 0
    margin_bottom: int = 0
    margin_right: int = 0


class CardListResponse(BaseModel):
    cards: List[CardResponse]
    total: int


class DrawCardRequest(BaseModel):
    user_id: int
    draw_type: str  # FREE 或 ENERGY


class DrawCardResponse(BaseModel):
    success: bool
    card: Optional[CardResponse]
    message: str
    draw_type: str
    energy_cost: int = 0


class DrawStatusResponse(BaseModel):
    free_draws_available: int
    energy_draws_used: int
    energy_draws_remaining: int
    # v0.6.0 保底计数器
    pity_gold: int = 0
    pity_black_gold: int = 0


class ChargeCardRequest(BaseModel):
    stone_id: int


class ChargeCardResponse(BaseModel):
    success: bool
    card_id: int
    stone_id: int
    energy_charged: int
    stone_energy_after: int
    card_remaining_energy: int
    message: str


class GiftCardRequest(BaseModel):
    to_user_id: int


class GiftCardResponse(BaseModel):
    success: bool
    card_id: int
    from_user_id: int
    to_user_id: int
    to_user_nickname: Optional[str]
    message: str


class PendingCardResponse(BaseModel):
    id: int
    card_type: str
    card_type_name: str
    mantra: str
    energy_level: int
    energy_level_name: str
    energy_value: int
    remaining_energy: int
    color_code: str
    from_user_id: int
    from_user_nickname: Optional[str]
    created_at: str


class PendingCardListResponse(BaseModel):
    cards: List[PendingCardResponse]
    total: int


class AcceptCardResponse(BaseModel):
    success: bool
    card_id: int
    message: str


# ==================== 合成相关 Schema ====================

class SynthesizeRequest(BaseModel):
    user_id: int
    card_ids: List[int]  # 必须是3张同类型同等级卡牌


class SynthesizeResponse(BaseModel):
    success: bool
    card: Optional[CardResponse]
    message: str


# ==================== 收藏相关 Schema ====================

class CollectionProgress(BaseModel):
    card_type: str
    card_type_name: str
    collected: int  # 已收集的预设卡牌数
    total: int  # 该类型预设卡牌总数


class CollectionResponse(BaseModel):
    collections: List[CollectionProgress]


# ==================== 商店相关 Schema ====================

class StoreItemResponse(BaseModel):
    id: int
    item_type: str
    name: str
    stone_type: Optional[str]
    energy_amount: int
    price: int
    is_active: bool


class StoreItemListResponse(BaseModel):
    items: List[StoreItemResponse]


class PurchaseRequest(BaseModel):
    user_id: int
    item_id: int


class PurchaseResponse(BaseModel):
    success: bool
    item_name: str
    energy_deducted: int
    user_total_energy: int
    message: str


# ==================== 消息相关 Schema ====================

class MessageResponse(BaseModel):
    id: int
    msg_type: str
    msg_subtype: Optional[str] = None  # GIFT_CARD etc.
    title: str
    content: str
    sender_id: Optional[int]
    sender_nickname: Optional[str]
    is_read: bool
    created_at: str
    card_info: Optional[PendingCardResponse] = None  # populated for GIFT_CARD messages


class MessageListResponse(BaseModel):
    messages: List[MessageResponse]
    total: int
    unread_count: int


class SendMessageRequest(BaseModel):
    sender_id: int
    receiver_id: int
    title: str
    content: str


# ==================== 广场相关 Schema ====================

class PlazaPostResponse(BaseModel):
    id: int
    user_id: Optional[int]
    user_nickname: Optional[str]
    post_type: str
    tag: Optional[str] = None  # v0.7.0: HEALTH/LOVE/WEALTH/CAREER/FAMILY
    total_energy_received: int = 0  # v0.7.0: sum of energy_value from all gifters
    content: str
    pray_count: int
    has_prayed: bool
    created_at: str


class PlazaPostListResponse(BaseModel):
    posts: List[PlazaPostResponse]
    total: int


class CreatePostRequest(BaseModel):
    user_id: int
    post_type: str  # BLESSING / WISH
    tag: Optional[str] = None  # v0.7.0: HEALTH/LOVE/WEALTH/CAREER/FAMILY
    content: str


class CreateActivityRequest(BaseModel):
    content: str


class GiftEnergyResponse(BaseModel):
    success: bool
    pray_count: int
    energy_gifted: int = 1
    from_stone_id: int
    to_stone_id: int
    message: str


class PlazaGifterInfo(BaseModel):
    user_id: int
    user_nickname: Optional[str]
    energy_value: int
    created_at: str


class PrayResponse(BaseModel):
    success: bool
    pray_count: int
    message: str


# ==================== v0.6.0 原型管理 Schema ====================


class ArchetypeResponse(BaseModel):
    id: int
    archetype_id: str
    faction: str
    rarity: str
    card_type: str
    name_templates_json: str
    base_cost: int
    base_stats_json: Optional[str] = None
    base_effects_json: Optional[str] = None
    lore_template: Optional[str] = None
    tags_json: Optional[str] = None
    version: int
    is_active: bool


class ArchetypeListResponse(BaseModel):
    archetypes: List[ArchetypeResponse]
    total: int


class ArchetypeCreateRequest(BaseModel):
    archetype_id: str
    faction: str
    rarity: str
    card_type: str
    name_templates_json: str  # JSON array string
    base_cost: int = 1
    base_stats_json: Optional[str] = None
    base_effects_json: Optional[str] = None
    lore_template: Optional[str] = None
    tags_json: Optional[str] = None


class ArchetypeUpdateRequest(BaseModel):
    faction: Optional[str] = None
    rarity: Optional[str] = None
    card_type: Optional[str] = None
    name_templates_json: Optional[str] = None
    base_cost: Optional[int] = None
    base_stats_json: Optional[str] = None
    base_effects_json: Optional[str] = None
    lore_template: Optional[str] = None
    tags_json: Optional[str] = None
    is_active: Optional[bool] = None


# ==================== 管理后台 Schema ====================

class AdminLoginRequest(BaseModel):
    admin_token: str


class AdminLoginResponse(BaseModel):
    success: bool
    message: str


class PresetCardManageResponse(BaseModel):
    id: int
    card_type: str
    mantra: str
    energy_level: int
    image_url: Optional[str] = None
    # v0.6.0 fields
    card_id: Optional[str] = None
    name: Optional[str] = None
    faction: Optional[str] = None
    rarity: Optional[str] = None
    card_type_sub: Optional[str] = None
    cost: Optional[int] = None
    stats_json: Optional[str] = None
    tags_json: Optional[str] = None
    # v0.7.0 layout + status
    status: str = "PENDING"
    card_width: Optional[int] = None
    card_height: Optional[int] = None
    image_fit: str = "COVER"
    margin_top: int = 0
    margin_left: int = 0
    margin_bottom: int = 0
    margin_right: int = 0


class PresetCardManageListResponse(BaseModel):
    cards: List[PresetCardManageResponse]
    total: int


class PresetCardCreateRequest(BaseModel):
    card_type: str  # HEALTH/LOVE/WEALTH/CAREER/FAMILY
    mantra: str
    energy_level: int  # 1-5
    image_url: Optional[str] = None
    # v0.7.0
    status: str = "PENDING"
    card_width: Optional[int] = None
    card_height: Optional[int] = None
    image_fit: str = "COVER"
    margin_top: int = 0
    margin_left: int = 0
    margin_bottom: int = 0
    margin_right: int = 0
    # v0.7.0 card metadata
    card_type_sub: Optional[str] = None
    cost: Optional[int] = None
    stats_json: Optional[str] = None
    tags_json: Optional[str] = None


class PresetCardUpdateRequest(BaseModel):
    card_type: Optional[str] = None
    mantra: Optional[str] = None
    energy_level: Optional[int] = None
    image_url: Optional[str] = None
    # v0.7.0
    status: Optional[str] = None
    card_width: Optional[int] = None
    card_height: Optional[int] = None
    image_fit: Optional[str] = None
    margin_top: Optional[int] = None
    margin_left: Optional[int] = None
    margin_bottom: Optional[int] = None
    margin_right: Optional[int] = None
    # v0.7.0 card metadata
    card_type_sub: Optional[str] = None
    cost: Optional[int] = None
    stats_json: Optional[str] = None
    tags_json: Optional[str] = None


class StoreItemCreateRequest(BaseModel):
    item_type: str
    name: str
    stone_type: Optional[str] = None
    energy_amount: int = 0
    price: int


class AnnouncementRequest(BaseModel):
    title: str
    content: str
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
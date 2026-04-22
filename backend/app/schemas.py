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


STONE_TYPES = {
    "HEALTH": {"name": "健康", "color": "green", "color_code": "#4CAF50"},
    "LOVE": {"name": "爱情", "color": "pink", "color_code": "#E91E63"},
    "WEALTH": {"name": "财富", "color": "gold", "color_code": "#FFD700"},
    "CAREER": {"name": "事业", "color": "red", "color_code": "#F44336"},
    "FAMILY": {"name": "家庭", "color": "blue", "color_code": "#2196F3"},
}
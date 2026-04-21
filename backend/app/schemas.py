from pydantic import BaseModel
from typing import Optional, List


class ChargeResponse(BaseModel):
    stone_id: int
    energy_before: int
    energy_after: int
    energy_gained: int
    blessing: str
    status: str


class StoneStatus(BaseModel):
    id: int
    user_id: int
    current_energy: int
    death_count: int
    status: str
    last_charge_time: Optional[str]


class CheckInStatusResponse(BaseModel):
    can_check_in: bool
    message: Optional[str] = None


class CheckInRecordResponse(BaseModel):
    id: int
    stone_id: int
    check_in_date: str
    energy_before: int
    energy_after: int
    blessing: str

    class Config:
        from_attributes = True


class CheckInRecordsResponse(BaseModel):
    records: List[CheckInRecordResponse]

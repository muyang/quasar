import random
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import EnergyStone, CheckInRecord
from app.schemas import ChargeResponse, CheckInStatusResponse, CheckInRecordResponse, CheckInRecordsResponse

router = APIRouter(prefix="/api/stone", tags=["stone"])

# 加权随机：越小的数值权重越高，模拟"小幅度充能更常见"
CHARGE_WEIGHTS = [(1, 30), (2, 25), (3, 20), (4, 15), (5, 10)]
_CHARGE_VALUES = [v for v, _ in CHARGE_WEIGHTS]
_CHARGE_WEIGHT_VALUES = [w for _, w in CHARGE_WEIGHTS]

ENERGY_CAP = 100

# 治愈祝福语列表
BLESSINGS = [
    "每一丝能量，都在悄悄缝补你的疲惫。",
    "石头感受到了你的温度，它正在变得更强。",
    "今天的你，比昨天又多了一份光芒。",
    "慢慢来，能量总会一点一点攒起来。",
    "你的坚持，石头都记得。",
    "充能完毕，愿温柔与你同在。",
    "每一次触碰，都是对生活的热爱。",
    "能量已汇入石头，愿你好梦。",
    "世界很大，但你有一颗发光的石头。",
    "辛苦了，让石头替你把疲惫存起来。",
]


def _weighted_random_charge() -> int:
    """返回加权随机的充能增量（1~5）。"""
    return random.choices(_CHARGE_VALUES, weights=_CHARGE_WEIGHT_VALUES, k=1)[0]


def _random_blessing() -> str:
    return random.choice(BLESSINGS)


def _get_today_date() -> str:
    """返回 UTC 今日日期字符串 YYYY-MM-DD。"""
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _has_checked_in_today(stone: EnergyStone, db: Session) -> bool:
    """判断石头今日是否已打卡。"""
    today = _get_today_date()
    record = db.query(CheckInRecord).filter(
        CheckInRecord.stone_id == stone.id,
        CheckInRecord.check_in_date == today
    ).first()
    return record is not None


@router.post("/{stone_id}/charge", response_model=ChargeResponse)
def charge_stone(stone_id: int, db: Session = Depends(get_db)):
    stone = db.query(EnergyStone).filter(EnergyStone.id == stone_id).first()
    if not stone:
        raise HTTPException(status_code=404, detail="石头不存在")

    if stone.status == "DEAD":
        raise HTTPException(status_code=400, detail="石头已枯竭，无法充能")

    # 检查今日是否已打卡
    if _has_checked_in_today(stone, db):
        raise HTTPException(status_code=400, detail="今日已充能，请明天再来吧")

    energy_before = stone.current_energy
    gain = _weighted_random_charge()
    energy_after = min(energy_before + gain, ENERGY_CAP)
    stone.current_energy = energy_after
    stone.last_charge_time = datetime.now(timezone.utc).isoformat()

    blessing = _random_blessing()
    today = _get_today_date()

    # 创建打卡记录
    check_in_record = CheckInRecord(
        stone_id=stone.id,
        check_in_date=today,
        energy_before=energy_before,
        energy_after=energy_after,
        blessing=blessing,
        created_at=datetime.now(timezone.utc).isoformat()
    )
    db.add(check_in_record)

    db.commit()
    db.refresh(stone)

    return ChargeResponse(
        stone_id=stone.id,
        energy_before=energy_before,
        energy_after=energy_after,
        energy_gained=energy_after - energy_before,
        blessing=blessing,
        status=stone.status,
    )


@router.get("/{stone_id}/check-in-status", response_model=CheckInStatusResponse)
def get_check_in_status(stone_id: int, db: Session = Depends(get_db)):
    """获取今日打卡状态。"""
    stone = db.query(EnergyStone).filter(EnergyStone.id == stone_id).first()
    if not stone:
        raise HTTPException(status_code=404, detail="石头不存在")

    if stone.status == "DEAD":
        return CheckInStatusResponse(
            can_check_in=False,
            message="石头已枯竭，无法充能"
        )

    if _has_checked_in_today(stone, db):
        return CheckInStatusResponse(
            can_check_in=False,
            message="今日已充能，明天再来吧"
        )

    return CheckInStatusResponse(can_check_in=True)


@router.get("/{stone_id}/records", response_model=CheckInRecordsResponse)
def get_check_in_records(stone_id: int, db: Session = Depends(get_db)):
    """获取打卡记录列表。"""
    stone = db.query(EnergyStone).filter(EnergyStone.id == stone_id).first()
    if not stone:
        raise HTTPException(status_code=404, detail="石头不存在")

    records = db.query(CheckInRecord).filter(
        CheckInRecord.stone_id == stone_id
    ).order_by(CheckInRecord.check_in_date.desc()).all()

    return CheckInRecordsResponse(
        records=[
            CheckInRecordResponse(
                id=r.id,
                stone_id=r.stone_id,
                check_in_date=r.check_in_date,
                energy_before=r.energy_before,
                energy_after=r.energy_after,
                blessing=r.blessing
            )
            for r in records
        ]
    )

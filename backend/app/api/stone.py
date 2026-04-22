import random
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import EnergyStone, CheckInRecord, User, TransferRecord
from app.schemas import (
    ChargeResponse, CheckInStatusResponse, CheckInRecordResponse, CheckInRecordsResponse,
    UserResponse, UserRegisterRequest, StoneCreateRequest, StoneBindRequest,
    TransferRequest, TransferResponse, StoneDetailResponse, StoneListResponse,
    StoneStatus, STONE_TYPES
)

router = APIRouter(prefix="/api", tags=["api"])

# 基础能量值加权随机：越小的数值权重越高
CHARGE_WEIGHTS = [(1, 30), (2, 25), (3, 20), (4, 15), (5, 10)]
_CHARGE_VALUES = [v for v, _ in CHARGE_WEIGHTS]
_CHARGE_WEIGHT_VALUES = [w for _, w in CHARGE_WEIGHTS]

ENERGY_CAP = 100
MAX_MULTIPLIER = 9  # 最大倍数
MAX_TRANSFER_AMOUNT = 81  # 单次转赠最大值


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
    "连续打卡，能量翻倍！坚持就是胜利。",
    "你的能量正在积蓄，明天会更强。",
]


def _weighted_random_charge() -> int:
    """返回加权随机的充能增量（1~5）。"""
    return random.choices(_CHARGE_VALUES, weights=_CHARGE_WEIGHT_VALUES, k=1)[0]


def _random_blessing() -> str:
    return random.choice(BLESSINGS)


def _get_today_date() -> str:
    """返回 UTC 今日日期字符串 YYYY-MM-DD。"""
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _get_yesterday_date() -> str:
    """返回 UTC 昨日日期字符串 YYYY-MM-DD。"""
    return (datetime.now(timezone.utc) - timedelta(days=1)).strftime("%Y-%m-%d")


# 石头类型前缀映射
STONE_TYPE_PREFIX = {
    "HEALTH": "H",    # 健康 - HRY
    "LOVE": "L",      # 爱情 - LRY
    "WEALTH": "W",    # 财富 - WRY
    "CAREER": "C",    # 事业 - CRY
    "FAMILY": "F",    # 家庭 - FRY
}


def _generate_unique_code(db: Session, stone_type: str) -> str:
    """生成石头唯一编号，不同类型用不同字母开头。"""
    prefix = STONE_TYPE_PREFIX.get(stone_type, "C")
    # 获取该类型石头的最后一个编号
    last_stone = db.query(EnergyStone).filter(
        EnergyStone.stone_type == stone_type
    ).order_by(EnergyStone.id.desc()).first()

    if last_stone:
        # 从现有编号提取数字部分
        try:
            last_code = last_stone.unique_code
            last_num = int(last_code.split('-')[1])
            next_num = last_num + 1
        except:
            next_num = 1
    else:
        next_num = 1

    return f"{prefix}RY-{next_num:06d}"


def _calculate_multiplier(consecutive_days: int) -> int:
    """计算能量倍数。第1天=1，第N天=N，最多9倍。"""
    return min(consecutive_days, MAX_MULTIPLIER)


def _has_checked_in_today(stone: EnergyStone, db: Session) -> bool:
    """判断石头今日是否已打卡。"""
    today = _get_today_date()
    record = db.query(CheckInRecord).filter(
        CheckInRecord.stone_id == stone.id,
        CheckInRecord.check_in_date == today
    ).first()
    return record is not None


def _update_consecutive_days(stone: EnergyStone) -> int:
    """更新并返回连续打卡天数。"""
    today = _get_today_date()
    yesterday = _get_yesterday_date()

    if stone.last_check_in_date == yesterday:
        # 连续打卡
        stone.consecutive_days += 1
    elif stone.last_check_in_date == today:
        # 今天已经打卡过，保持原值
        pass
    else:
        # 中断，重置为第1天
        stone.consecutive_days = 1

    return stone.consecutive_days


# ==================== 用户接口 ====================

@router.post("/user/register", response_model=UserResponse)
def register_user(request: UserRegisterRequest, db: Session = Depends(get_db)):
    """用户注册，返回唯一ID。"""
    user = User(
        nickname=request.nickname,
        created_at=datetime.now(timezone.utc).isoformat()
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    return UserResponse(
        id=user.id,
        nickname=user.nickname,
        created_at=user.created_at,
        stones=[]
    )


@router.get("/user/{user_id}", response_model=UserResponse)
def get_user(user_id: int, db: Session = Depends(get_db)):
    """获取用户信息及其所有石头。"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    stones = db.query(EnergyStone).filter(EnergyStone.owner_id == user_id).all()
    stone_list = [
        StoneStatus(
            id=s.id,
            unique_code=s.unique_code,
            stone_type=s.stone_type,
            owner_id=s.owner_id,
            current_energy=s.current_energy,
            death_count=s.death_count,
            status=s.status,
            consecutive_days=s.consecutive_days,
            last_charge_time=s.last_charge_time
        )
        for s in stones
    ]

    return UserResponse(
        id=user.id,
        nickname=user.nickname,
        created_at=user.created_at,
        stones=stone_list
    )


# ==================== 石头接口 ====================

@router.post("/stone/create", response_model=StoneDetailResponse)
def create_stone(request: StoneCreateRequest, db: Session = Depends(get_db)):
    """创建新石头（模拟购买）。"""
    if request.stone_type not in STONE_TYPES:
        raise HTTPException(status_code=400, detail="无效的石头类型")

    user = db.query(User).filter(User.id == request.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    unique_code = _generate_unique_code(db, request.stone_type)
    stone = EnergyStone(
        unique_code=unique_code,
        stone_type=request.stone_type,
        owner_id=request.user_id,
        current_energy=10,
        consecutive_days=0
    )
    db.add(stone)
    db.commit()
    db.refresh(stone)

    type_info = STONE_TYPES[stone.stone_type]
    return StoneDetailResponse(
        id=stone.id,
        unique_code=stone.unique_code,
        stone_type=stone.stone_type,
        stone_type_name=type_info["name"],
        color_code=type_info["color_code"],
        owner_id=stone.owner_id,
        owner_nickname=user.nickname,
        current_energy=stone.current_energy,
        energy_cap=ENERGY_CAP,
        death_count=stone.death_count,
        status=stone.status,
        consecutive_days=stone.consecutive_days,
        next_multiplier=1,
        can_transfer=stone.current_energy > 0 and stone.status == "ALIVE"
    )


@router.post("/stone/bind", response_model=StoneDetailResponse)
def bind_stone(request: StoneBindRequest, db: Session = Depends(get_db)):
    """绑定已有石头到用户。"""
    user = db.query(User).filter(User.id == request.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    stone = db.query(EnergyStone).filter(EnergyStone.unique_code == request.unique_code).first()
    if not stone:
        raise HTTPException(status_code=404, detail="石头不存在")

    if stone.owner_id:
        raise HTTPException(status_code=400, detail="该石头已被其他人绑定")

    stone.owner_id = request.user_id
    db.commit()
    db.refresh(stone)

    type_info = STONE_TYPES[stone.stone_type]
    multiplier = _calculate_multiplier(stone.consecutive_days + 1)

    return StoneDetailResponse(
        id=stone.id,
        unique_code=stone.unique_code,
        stone_type=stone.stone_type,
        stone_type_name=type_info["name"],
        color_code=type_info["color_code"],
        owner_id=stone.owner_id,
        owner_nickname=user.nickname,
        current_energy=stone.current_energy,
        energy_cap=ENERGY_CAP,
        death_count=stone.death_count,
        status=stone.status,
        consecutive_days=stone.consecutive_days,
        next_multiplier=multiplier,
        can_transfer=stone.current_energy > 0 and stone.status == "ALIVE"
    )


@router.get("/stone/{stone_id}", response_model=StoneDetailResponse)
def get_stone_detail(stone_id: int, db: Session = Depends(get_db)):
    """获取石头完整详情。"""
    stone = db.query(EnergyStone).filter(EnergyStone.id == stone_id).first()
    if not stone:
        raise HTTPException(status_code=404, detail="石头不存在")

    type_info = STONE_TYPES[stone.stone_type]

    owner_nickname = None
    if stone.owner_id:
        user = db.query(User).filter(User.id == stone.owner_id).first()
        owner_nickname = user.nickname if user else None

    # 计算下次打卡的倍数
    multiplier = _calculate_multiplier(stone.consecutive_days + 1)

    return StoneDetailResponse(
        id=stone.id,
        unique_code=stone.unique_code,
        stone_type=stone.stone_type,
        stone_type_name=type_info["name"],
        color_code=type_info["color_code"],
        owner_id=stone.owner_id,
        owner_nickname=owner_nickname,
        current_energy=stone.current_energy,
        energy_cap=ENERGY_CAP,
        death_count=stone.death_count,
        status=stone.status,
        consecutive_days=stone.consecutive_days,
        next_multiplier=multiplier,
        can_transfer=stone.current_energy > 0 and stone.status == "ALIVE"
    )


@router.get("/stone/{stone_id}/check-in-status", response_model=CheckInStatusResponse)
def get_check_in_status(stone_id: int, db: Session = Depends(get_db)):
    """获取今日打卡状态。"""
    stone = db.query(EnergyStone).filter(EnergyStone.id == stone_id).first()
    if not stone:
        raise HTTPException(status_code=404, detail="石头不存在")

    if stone.status == "DEAD":
        return CheckInStatusResponse(
            can_check_in=False,
            message="石头已枯竭，无法充能",
            consecutive_days=stone.consecutive_days,
            next_multiplier=0
        )

    if _has_checked_in_today(stone, db):
        return CheckInStatusResponse(
            can_check_in=False,
            message="今日已充能，明天再来吧",
            consecutive_days=stone.consecutive_days,
            next_multiplier=0
        )

    # 计算下次打卡的倍数
    next_days = stone.consecutive_days + 1 if stone.last_check_in_date == _get_yesterday_date() else 1
    multiplier = _calculate_multiplier(next_days)

    return CheckInStatusResponse(
        can_check_in=True,
        consecutive_days=stone.consecutive_days,
        next_multiplier=multiplier
    )


@router.post("/stone/{stone_id}/charge", response_model=ChargeResponse)
def charge_stone(stone_id: int, db: Session = Depends(get_db)):
    stone = db.query(EnergyStone).filter(EnergyStone.id == stone_id).first()
    if not stone:
        raise HTTPException(status_code=404, detail="石头不存在")

    if stone.status == "DEAD":
        raise HTTPException(status_code=400, detail="石头已枯竭，无法充能")

    if _has_checked_in_today(stone, db):
        raise HTTPException(status_code=400, detail="今日已充能，请明天再来吧")

    # 更新连续打卡天数
    consecutive_days = _update_consecutive_days(stone)
    multiplier = _calculate_multiplier(consecutive_days)

    # 计算能量增量
    base_gain = _weighted_random_charge()
    total_gain = base_gain * multiplier
    total_gain = min(total_gain, ENERGY_CAP - stone.current_energy)  # 不能超过上限

    energy_before = stone.current_energy
    energy_after = min(energy_before + total_gain, ENERGY_CAP)
    stone.current_energy = energy_after
    stone.last_charge_time = datetime.now(timezone.utc).isoformat()
    stone.last_check_in_date = _get_today_date()

    blessing = _random_blessing()
    today = _get_today_date()

    # 创建打卡记录
    check_in_record = CheckInRecord(
        stone_id=stone.id,
        check_in_date=today,
        energy_before=energy_before,
        energy_after=energy_after,
        energy_gained=energy_after - energy_before,
        base_gain=base_gain,
        multiplier=multiplier,
        consecutive_days=consecutive_days,
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
        base_gain=base_gain,
        multiplier=multiplier,
        consecutive_days=consecutive_days,
        blessing=blessing,
        status=stone.status,
    )


@router.get("/stone/{stone_id}/records", response_model=CheckInRecordsResponse)
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
                energy_gained=r.energy_gained,
                base_gain=r.base_gain,
                multiplier=r.multiplier,
                consecutive_days=r.consecutive_days,
                blessing=r.blessing
            )
            for r in records
        ]
    )


# ==================== 转赠接口 ====================

@router.post("/stone/transfer", response_model=TransferResponse)
def transfer_energy(request: TransferRequest, db: Session = Depends(get_db)):
    """转赠能量。支持接收者为用户ID或石头编号。"""
    from_stone = db.query(EnergyStone).filter(EnergyStone.id == request.from_stone_id).first()
    if not from_stone:
        raise HTTPException(status_code=404, detail="发送方石头不存在")

    # 解析接收者：尝试作为用户ID或石头编号
    to_stone = None
    to_owner = None

    # 尝试解析为用户ID（纯数字）
    user_id = int(request.to_receiver) if request.to_receiver.isdigit() else None
    if user_id:
        # 查找该用户同类型的第一颗可用石头
        to_owner = db.query(User).filter(User.id == user_id).first()
        if not to_owner:
            raise HTTPException(status_code=404, detail="接收者用户不存在")

        to_stone = db.query(EnergyStone).filter(
            EnergyStone.owner_id == user_id,
            EnergyStone.stone_type == from_stone.stone_type,
            EnergyStone.status == "ALIVE"
        ).order_by(EnergyStone.current_energy.desc()).first()

        if not to_stone:
            type_name = STONE_TYPES[from_stone.stone_type]["name"]
            raise HTTPException(
                status_code=400,
                detail=f"接收者没有【{type_name}】类型的可用水晶"
            )
    else:
        # 作为石头编号查询
        to_stone = db.query(EnergyStone).filter(
            EnergyStone.unique_code == request.to_receiver.upper()
        ).first()
        if not to_stone:
            raise HTTPException(status_code=404, detail="接收者水晶不存在")

        if to_stone.owner_id:
            to_owner = db.query(User).filter(User.id == to_stone.owner_id).first()

    # 验证条件
    if from_stone.status == "DEAD":
        raise HTTPException(status_code=400, detail="发送方水晶已枯竭")

    if to_stone.status == "DEAD":
        raise HTTPException(status_code=400, detail="接收方水晶已枯竭")

    if from_stone.stone_type != to_stone.stone_type:
        from_type_name = STONE_TYPES[from_stone.stone_type]["name"]
        to_type_name = STONE_TYPES[to_stone.stone_type]["name"]
        raise HTTPException(
            status_code=400,
            detail=f"类型不匹配：你的水晶是【{from_type_name}】，接收方水晶是【{to_type_name}】，只能向同类型水晶转赠能量"
        )

    if from_stone.id == to_stone.id:
        raise HTTPException(status_code=400, detail="不能向自己转赠")

    if request.energy_amount < 1:
        raise HTTPException(status_code=400, detail="转赠能量最小为1")

    if request.energy_amount > MAX_TRANSFER_AMOUNT:
        raise HTTPException(status_code=400, detail=f"单次转赠最大值为{MAX_TRANSFER_AMOUNT}")

    if request.energy_amount > from_stone.current_energy:
        raise HTTPException(status_code=400, detail="转赠能量不能超过当前能量值")

    # 执行转赠
    from_energy_before = from_stone.current_energy
    to_energy_before = to_stone.current_energy

    from_stone.current_energy -= request.energy_amount
    to_stone.current_energy = min(to_stone.current_energy + request.energy_amount, ENERGY_CAP)

    # 创建转赠记录
    transfer_record = TransferRecord(
        from_stone_id=from_stone.id,
        to_stone_id=to_stone.id,
        energy_amount=request.energy_amount,
        created_at=datetime.now(timezone.utc).isoformat()
    )
    db.add(transfer_record)
    db.commit()
    db.refresh(from_stone)
    db.refresh(to_stone)

    # 构建接收者显示名称
    receiver_name = to_owner.nickname if to_owner else to_stone.unique_code

    return TransferResponse(
        success=True,
        from_stone_id=from_stone.id,
        to_stone_id=to_stone.id,
        to_owner_id=to_stone.owner_id,
        to_owner_nickname=to_owner.nickname if to_owner else None,
        energy_amount=request.energy_amount,
        from_stone_energy=from_stone.current_energy,
        to_stone_energy=to_stone.current_energy,
        message=f"成功向 {receiver_name} 转赠 {request.energy_amount} 点能量"
    )


@router.get("/stone/code/{unique_code}", response_model=StoneDetailResponse)
def get_stone_by_code(unique_code: str, db: Session = Depends(get_db)):
    """通过编号获取石头详情。"""
    stone = db.query(EnergyStone).filter(EnergyStone.unique_code == unique_code.upper()).first()
    if not stone:
        raise HTTPException(status_code=404, detail="石头不存在")

    type_info = STONE_TYPES[stone.stone_type]
    owner_nickname = None
    if stone.owner_id:
        user = db.query(User).filter(User.id == stone.owner_id).first()
        owner_nickname = user.nickname if user else None

    multiplier = _calculate_multiplier(stone.consecutive_days + 1)

    return StoneDetailResponse(
        id=stone.id,
        unique_code=stone.unique_code,
        stone_type=stone.stone_type,
        stone_type_name=type_info["name"],
        color_code=type_info["color_code"],
        owner_id=stone.owner_id,
        owner_nickname=owner_nickname,
        current_energy=stone.current_energy,
        energy_cap=ENERGY_CAP,
        death_count=stone.death_count,
        status=stone.status,
        consecutive_days=stone.consecutive_days,
        next_multiplier=multiplier,
        can_transfer=stone.current_energy > 0 and stone.status == "ALIVE"
    )


@router.get("/user/{user_id}/stones", response_model=StoneListResponse)
def get_user_stones(user_id: int, db: Session = Depends(get_db)):
    """获取用户的所有石头。"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    stones = db.query(EnergyStone).filter(EnergyStone.owner_id == user_id).all()

    stone_list = []
    for s in stones:
        type_info = STONE_TYPES[s.stone_type]
        multiplier = _calculate_multiplier(s.consecutive_days + 1)
        stone_list.append(StoneDetailResponse(
            id=s.id,
            unique_code=s.unique_code,
            stone_type=s.stone_type,
            stone_type_name=type_info["name"],
            color_code=type_info["color_code"],
            owner_id=s.owner_id,
            owner_nickname=user.nickname,
            current_energy=s.current_energy,
            energy_cap=ENERGY_CAP,
            death_count=s.death_count,
            status=s.status,
            consecutive_days=s.consecutive_days,
            next_multiplier=multiplier,
            can_transfer=s.current_energy > 0 and s.status == "ALIVE"
        ))

    return StoneListResponse(stones=stone_list)
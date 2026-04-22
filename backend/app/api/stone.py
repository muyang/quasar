import random
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import EnergyStone, CheckInRecord, User, TransferRecord, Card, UserDrawRecord, PresetCard
from app.schemas import (
    ChargeResponse, CheckInStatusResponse, CheckInRecordResponse, CheckInRecordsResponse,
    UserResponse, UserRegisterRequest, LoginByStoneRequest, StoneCreateRequest, StoneBindRequest,
    TransferRequest, TransferResponse, StoneDetailResponse, StoneListResponse,
    StoneStatus, STONE_TYPES, ENERGY_LEVELS, CARD_TYPE_NAMES,
    CardResponse, CardListResponse, DrawCardRequest, DrawCardResponse, DrawStatusResponse,
    ChargeCardRequest, ChargeCardResponse, GiftCardRequest, GiftCardResponse,
    PendingCardResponse, PendingCardListResponse, AcceptCardResponse
)

router = APIRouter(prefix="/api", tags=["api"])

# 基础能量值加权随机：越小的数值权重越高
CHARGE_WEIGHTS = [(1, 30), (2, 25), (3, 20), (4, 15), (5, 10)]
_CHARGE_VALUES = [v for v, _ in CHARGE_WEIGHTS]
_CHARGE_WEIGHT_VALUES = [w for _, w in CHARGE_WEIGHTS]

ENERGY_CAP = 100
MAX_MULTIPLIER = 9
MAX_TRANSFER_AMOUNT = 81
MAX_ENERGY_DRAWS_PER_DAY = 3  # 每天最多能量消耗抽卡次数
ENERGY_DRAW_COST = 3  # 每次能量消耗抽卡需要3点能量


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

# 咒语库（每种类型预设咒语）
MANTRAS = {
    "HEALTH": [
        "身体是灵魂的殿堂，珍爱它。",
        "健康是最大的财富，守护它。",
        "每一次呼吸都是生命的礼物。",
        "强健的体魄承载无限的可能。",
        "健康之路，始于足下。",
        "身心合一，方得自在。",
        "养生之道，顺应自然。",
        "运动是生命的源泉。",
        "静心养气，身心调和。",
        "健康的身体是幸福的基石。",
        "善待身体，它会回馈你。",
        "活力充沛，精神焕发。",
        "清晨阳光，滋养身心。",
        "饮食有节，起居有常。",
        "心如止水，身如松柏。",
    ],
    "LOVE": [
        "爱是永恒的光芒，照亮前路。",
        "心中有爱，万物皆美。",
        "真诚的爱无需言语表达。",
        "爱让世界变得温柔美好。",
        "爱是最好的治愈良药。",
        "被爱包围，心无所惧。",
        "爱是生命最美的诗篇。",
        "爱的力量超越一切障碍。",
        "珍惜眼前人，善待心中爱。",
        "爱是连接灵魂的桥梁。",
        "懂得爱的人最幸福。",
        "爱是无条件的接纳。",
        "心中有爱，手中有光。",
        "爱让平凡变得不凡。",
        "爱是最好的修行。",
    ],
    "WEALTH": [
        "财富如流水，善用则长流。",
        "富足的心灵胜过富足的口袋。",
        "勤劳是财富的种子。",
        "知足常乐，财富自来。",
        "财富是努力的回报。",
        "善用财富，造福他人。",
        "理财有道，致富有望。",
        "节俭是财富的基石。",
        "投资未来，收获希望。",
        "财富自由，心灵自由。",
        "开源节流，细水长流。",
        "创造价值，获取财富。",
        "智慧理财，稳健增值。",
        "财富不是目的，是工具。",
        "勤劳致富，诚信守富。",
    ],
    "CAREER": [
        "努力是成功的基石，坚持是胜利的关键。",
        "专注当下，成就未来。",
        "每一步努力都值得记录。",
        "成功源于日复一日的坚持。",
        "事业的巅峰始于脚下的每一步。",
        "敬业乐业，事业必成。",
        "目标清晰，行动坚定。",
        "突破自我，超越极限。",
        "专注的力量无可阻挡。",
        "今天付出，明天收获。",
        "追求卓越，成就非凡。",
        "热爱工作，享受过程。",
        "计划周详，执行果断。",
        "学习不止，进步不息。",
        "专注一事，做到极致。",
    ],
    "FAMILY": [
        "家和万事兴，和谐是最大的福气。",
        "家人是最温暖的港湾。",
        "陪伴是最长情的告白。",
        "家庭和睦，万事顺遂。",
        "亲情是最珍贵的财富。",
        "善待家人，善待自己。",
        "沟通是家庭的桥梁。",
        "理解是家庭的基石。",
        "家是心灵的归宿。",
        "珍惜团聚时光。",
        "家人支持是最大的力量。",
        "和睦相处，彼此尊重。",
        "家是爱的起点。",
        "传承家风，延续美德。",
        "家人健康是最大的心愿。",
    ],
}


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
    "HEALTH": "H",
    "LOVE": "L",
    "WEALTH": "W",
    "CAREER": "C",
    "FAMILY": "F",
}


def _generate_unique_code(db: Session, stone_type: str) -> str:
    """生成石头唯一编号，不同类型用不同字母开头。"""
    prefix = STONE_TYPE_PREFIX.get(stone_type, "C")
    last_stone = db.query(EnergyStone).filter(
        EnergyStone.stone_type == stone_type
    ).order_by(EnergyStone.id.desc()).first()

    if last_stone:
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
        stone.consecutive_days += 1
    elif stone.last_check_in_date == today:
        pass
    else:
        stone.consecutive_days = 1

    return stone.consecutive_days


def _generate_energy_value(level: int) -> int:
    """根据能量等级生成随机能量值。"""
    level_info = ENERGY_LEVELS[level]
    return random.randint(level_info["min"], level_info["max"])


def _get_card_color_code(card_type: str) -> str:
    """获取卡牌颜色代码。"""
    return STONE_TYPES.get(card_type, {}).get("color_code", "#4CAF50")


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


@router.post("/user/login-by-stone", response_model=UserResponse)
def login_by_stone(request: LoginByStoneRequest, db: Session = Depends(get_db)):
    """通过石头编号登录。扫描二维码/NFC后调用此接口。"""
    stone = db.query(EnergyStone).filter(
        EnergyStone.unique_code == request.unique_code.upper()
    ).first()

    if not stone:
        raise HTTPException(status_code=404, detail="石头不存在")

    if not stone.owner_id:
        raise HTTPException(status_code=400, detail="该石头未绑定用户，请先注册新账户")

    user = db.query(User).filter(User.id == stone.owner_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    stones = db.query(EnergyStone).filter(EnergyStone.owner_id == user.id).all()
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
    """创建新石头（模拟购买）。每种类型用户只能拥有一个。"""
    if request.stone_type not in STONE_TYPES:
        raise HTTPException(status_code=400, detail="无效的石头类型")

    user = db.query(User).filter(User.id == request.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    # 检查用户是否已有该类型石头
    existing_stone = db.query(EnergyStone).filter(
        EnergyStone.owner_id == request.user_id,
        EnergyStone.stone_type == request.stone_type
    ).first()

    if existing_stone:
        type_name = STONE_TYPES[request.stone_type]["name"]
        raise HTTPException(
            status_code=400,
            detail=f"您已拥有【{type_name}】类型的水晶，每种类型只能购买一个"
        )

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

    # 检查用户是否已有该类型石头
    existing_stone = db.query(EnergyStone).filter(
        EnergyStone.owner_id == request.user_id,
        EnergyStone.stone_type == stone.stone_type
    ).first()

    if existing_stone:
        type_name = STONE_TYPES[stone.stone_type]["name"]
        raise HTTPException(
            status_code=400,
            detail=f"您已拥有【{type_name}】类型的水晶，无法绑定同类型石头"
        )

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

    next_days = stone.consecutive_days + 1 if stone.last_check_in_date == _get_yesterday_date() else 1
    multiplier = _calculate_multiplier(next_days)

    return CheckInStatusResponse(
        can_check_in=True,
        consecutive_days=stone.consecutive_days,
        next_multiplier=multiplier
    )


@router.post("/stone/{stone_id}/charge", response_model=ChargeResponse)
def charge_stone(stone_id: int, db: Session = Depends(get_db)):
    """石头充能（打卡）。充能成功后获得免费抽卡机会。"""
    stone = db.query(EnergyStone).filter(EnergyStone.id == stone_id).first()
    if not stone:
        raise HTTPException(status_code=404, detail="石头不存在")

    if stone.status == "DEAD":
        raise HTTPException(status_code=400, detail="石头已枯竭，无法充能")

    if _has_checked_in_today(stone, db):
        raise HTTPException(status_code=400, detail="今日已充能，请明天再来吧")

    consecutive_days = _update_consecutive_days(stone)
    multiplier = _calculate_multiplier(consecutive_days)

    base_gain = _weighted_random_charge()
    total_gain = base_gain * multiplier
    total_gain = min(total_gain, ENERGY_CAP - stone.current_energy)

    energy_before = stone.current_energy
    energy_after = min(energy_before + total_gain, ENERGY_CAP)
    stone.current_energy = energy_after
    stone.last_charge_time = datetime.now(timezone.utc).isoformat()
    stone.last_check_in_date = _get_today_date()

    blessing = _random_blessing()
    today = _get_today_date()

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

    # 判断是否获得免费抽卡机会（今日首次打卡）
    free_draw_available = True

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
        free_draw_available=free_draw_available
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

    to_stone = None
    to_owner = None

    user_id = int(request.to_receiver) if request.to_receiver.isdigit() else None
    if user_id:
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
        to_stone = db.query(EnergyStone).filter(
            EnergyStone.unique_code == request.to_receiver.upper()
        ).first()
        if not to_stone:
            raise HTTPException(status_code=404, detail="接收者水晶不存在")

        if to_stone.owner_id:
            to_owner = db.query(User).filter(User.id == to_stone.owner_id).first()

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

    from_stone.current_energy -= request.energy_amount
    to_stone.current_energy = min(to_stone.current_energy + request.energy_amount, ENERGY_CAP)

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


@router.post("/stone/code/{unique_code}/bind-new-user", response_model=UserResponse)
def bind_stone_to_new_user(unique_code: str, request: UserRegisterRequest, db: Session = Depends(get_db)):
    """为未绑定的石头创建新用户并绑定（新用户首次登录流程）。"""
    stone = db.query(EnergyStone).filter(EnergyStone.unique_code == unique_code.upper()).first()
    if not stone:
        raise HTTPException(status_code=404, detail="石头不存在")

    if stone.owner_id:
        raise HTTPException(status_code=400, detail="该石头已被其他用户绑定，请使用其他石头编号")

    # 创建新用户
    new_user = User(
        nickname=request.nickname,
        created_at=datetime.now(timezone.utc).isoformat()
    )
    db.add(new_user)
    db.flush()  # 获取用户ID

    # 绑定石头到新用户
    stone.owner_id = new_user.id
    db.commit()
    db.refresh(new_user)

    # 返回用户信息和石头列表
    stones = db.query(EnergyStone).filter(EnergyStone.owner_id == new_user.id).all()
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
        id=new_user.id,
        nickname=new_user.nickname,
        created_at=new_user.created_at,
        stones=stone_list
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


# ==================== 卡牌接口 ====================

@router.get("/user/{user_id}/draw-status", response_model=DrawStatusResponse)
def get_draw_status(user_id: int, db: Session = Depends(get_db)):
    """获取用户今日抽卡状态。"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    today = _get_today_date()

    # 今日打卡获得的免费抽卡次数（每个石头打卡一次获得一次免费抽卡）
    user_stones = db.query(EnergyStone).filter(
        EnergyStone.owner_id == user_id,
        EnergyStone.status == "ALIVE"
    ).all()

    free_draws_available = 0
    for stone in user_stones:
        if _has_checked_in_today(stone, db):
            free_draws_available += 1

    # 查看今日已使用的免费抽卡次数
    free_draws_used = db.query(UserDrawRecord).filter(
        UserDrawRecord.user_id == user_id,
        UserDrawRecord.draw_date == today,
        UserDrawRecord.draw_type == "FREE"
    ).count()

    free_draws_available -= free_draws_used
    free_draws_available = max(0, free_draws_available)

    # 今日已使用的能量抽卡次数
    energy_draws_used = db.query(UserDrawRecord).filter(
        UserDrawRecord.user_id == user_id,
        UserDrawRecord.draw_date == today,
        UserDrawRecord.draw_type == "ENERGY"
    ).count()

    energy_draws_remaining = MAX_ENERGY_DRAWS_PER_DAY - energy_draws_used

    return DrawStatusResponse(
        free_draws_available=free_draws_available,
        energy_draws_used=energy_draws_used,
        energy_draws_remaining=energy_draws_remaining
    )


@router.post("/card/draw", response_model=DrawCardResponse)
def draw_card(request: DrawCardRequest, db: Session = Depends(get_db)):
    """抽卡。draw_type: FREE（打卡免费）或 ENERGY（消耗能量）。"""
    user = db.query(User).filter(User.id == request.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    today = _get_today_date()

    # 检查抽卡条件
    if request.draw_type == "FREE":
        # 检查是否有免费抽卡次数
        free_draws_used = db.query(UserDrawRecord).filter(
            UserDrawRecord.user_id == request.user_id,
            UserDrawRecord.draw_date == today,
            UserDrawRecord.draw_type == "FREE"
        ).count()

        user_stones = db.query(EnergyStone).filter(
            EnergyStone.owner_id == request.user_id,
            EnergyStone.status == "ALIVE"
        ).all()

        free_draws_total = 0
        for stone in user_stones:
            if _has_checked_in_today(stone, db):
                free_draws_total += 1

        if free_draws_used >= free_draws_total:
            raise HTTPException(status_code=400, detail="今日免费抽卡次数已用完")

    elif request.draw_type == "ENERGY":
        # 检查能量消耗抽卡次数
        energy_draws_used = db.query(UserDrawRecord).filter(
            UserDrawRecord.user_id == request.user_id,
            UserDrawRecord.draw_date == today,
            UserDrawRecord.draw_type == "ENERGY"
        ).count()

        if energy_draws_used >= MAX_ENERGY_DRAWS_PER_DAY:
            raise HTTPException(status_code=400, detail=f"今日能量抽卡次数已达上限（{MAX_ENERGY_DRAWS_PER_DAY}次）")

        # 检查用户是否有足够能量（从任意石头扣除）
        user_stones = db.query(EnergyStone).filter(
            EnergyStone.owner_id == request.user_id,
            EnergyStone.status == "ALIVE"
        ).all()

        total_energy = sum(s.current_energy for s in user_stones)
        if total_energy < ENERGY_DRAW_COST:
            raise HTTPException(status_code=400, detail=f"能量不足，抽卡需要{ENERGY_DRAW_COST}点能量")

        # 从能量最高的石头扣除能量
        stone = db.query(EnergyStone).filter(
            EnergyStone.owner_id == request.user_id,
            EnergyStone.status == "ALIVE",
            EnergyStone.current_energy >= ENERGY_DRAW_COST
        ).order_by(EnergyStone.current_energy.desc()).first()

        if stone:
            stone.current_energy -= ENERGY_DRAW_COST
    else:
        raise HTTPException(status_code=400, detail="无效的抽卡类型")

    # 从预设卡牌池随机抽取一张
    preset_cards = db.query(PresetCard).all()
    if not preset_cards:
        raise HTTPException(status_code=500, detail="卡牌池未初始化")

    # 按能量等级加权：低级别概率高，高级别概率低
    level_weights = {1: 40, 2: 30, 3: 20, 4: 8, 5: 2}
    weighted_cards = []
    for card in preset_cards:
        weight = level_weights.get(card.energy_level, 10)
        weighted_cards.extend([card] * weight)

    selected_preset = random.choice(weighted_cards)

    # 创建用户卡牌
    energy_value = _generate_energy_value(selected_preset.energy_level)
    new_card = Card(
        preset_card_id=selected_preset.id,
        card_type=selected_preset.card_type,
        mantra=selected_preset.mantra,
        energy_level=selected_preset.energy_level,
        energy_value=energy_value,
        energy_consumed=0,
        owner_id=request.user_id,
        created_at=datetime.now(timezone.utc).isoformat()
    )
    db.add(new_card)
    db.flush()  # 先flush获取ID

    # 记录抽卡
    draw_record = UserDrawRecord(
        user_id=request.user_id,
        draw_date=today,
        draw_type=request.draw_type,
        card_id=new_card.id,
        created_at=datetime.now(timezone.utc).isoformat()
    )
    db.add(draw_record)

    db.commit()
    db.refresh(new_card)

    type_name = CARD_TYPE_NAMES.get(new_card.card_type, "未知")
    level_name = ENERGY_LEVELS.get(new_card.energy_level, {}).get("name", "未知")

    return DrawCardResponse(
        success=True,
        card=CardResponse(
            id=new_card.id,
            card_type=new_card.card_type,
            card_type_name=type_name,
            mantra=new_card.mantra,
            energy_level=new_card.energy_level,
            energy_level_name=level_name,
            energy_value=new_card.energy_value,
            energy_consumed=new_card.energy_consumed,
            remaining_energy=new_card.energy_value - new_card.energy_consumed,
            color_code=_get_card_color_code(new_card.card_type),
            can_charge=True,
            created_at=new_card.created_at
        ),
        message=f"抽到一张【{type_name}】{level_name}级卡牌！",
        draw_type=request.draw_type,
        energy_cost=ENERGY_DRAW_COST if request.draw_type == "ENERGY" else 0
    )


@router.get("/user/{user_id}/cards", response_model=CardListResponse)
def get_user_cards(user_id: int, db: Session = Depends(get_db)):
    """获取用户的所有卡牌（已接收的）。"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    # 查询已接收的卡牌（排除PENDING状态）
    cards = db.query(Card).filter(
        Card.owner_id == user_id,
        Card.gift_status != "PENDING"
    ).order_by(Card.created_at.desc()).all()

    # 获取用户拥有的石头类型，用于判断卡牌是否可充值
    user_stone_types = set()
    user_stones = db.query(EnergyStone).filter(
        EnergyStone.owner_id == user_id,
        EnergyStone.status == "ALIVE"
    ).all()
    for stone in user_stones:
        user_stone_types.add(stone.stone_type)

    card_list = []
    for c in cards:
        remaining = c.energy_value - c.energy_consumed
        type_name = CARD_TYPE_NAMES.get(c.card_type, "未知")
        level_name = ENERGY_LEVELS.get(c.energy_level, {}).get("name", "未知")

        # 检查是否可充值：有剩余能量 + 用户有匹配类型石头
        can_charge = remaining > 0 and c.card_type in user_stone_types

        card_list.append(CardResponse(
            id=c.id,
            card_type=c.card_type,
            card_type_name=type_name,
            mantra=c.mantra,
            energy_level=c.energy_level,
            energy_level_name=level_name,
            energy_value=c.energy_value,
            energy_consumed=c.energy_consumed,
            remaining_energy=remaining,
            color_code=_get_card_color_code(c.card_type),
            can_charge=can_charge,
            created_at=c.created_at
        ))

    return CardListResponse(cards=card_list, total=len(card_list))


@router.post("/card/{card_id}/charge", response_model=ChargeCardResponse)
def charge_card_to_stone(card_id: int, request: ChargeCardRequest, db: Session = Depends(get_db)):
    """将卡牌能量充值到石头。"""
    card = db.query(Card).filter(Card.id == card_id).first()
    if not card:
        raise HTTPException(status_code=404, detail="卡牌不存在")

    stone = db.query(EnergyStone).filter(EnergyStone.id == request.stone_id).first()
    if not stone:
        raise HTTPException(status_code=404, detail="石头不存在")

    # 检查类型匹配
    if card.card_type != stone.stone_type:
        card_type_name = CARD_TYPE_NAMES.get(card.card_type, "未知")
        stone_type_name = STONE_TYPES.get(stone.stone_type, {}).get("name", "未知")
        raise HTTPException(
            status_code=400,
            detail=f"类型不匹配：卡牌是【{card_type_name}】，石头是【{stone_type_name}】"
        )

    # 检查卡牌剩余能量
    remaining_energy = card.energy_value - card.energy_consumed
    if remaining_energy <= 0:
        raise HTTPException(status_code=400, detail="卡牌能量已耗尽")

    # 检查石头状态
    if stone.status == "DEAD":
        raise HTTPException(status_code=400, detail="石头已枯竭")

    # 检查石头归属
    if card.owner_id != stone.owner_id:
        raise HTTPException(status_code=400, detail="只能向自己的石头充值能量")

    # 执行充值
    charge_amount = min(remaining_energy, ENERGY_CAP - stone.current_energy)
    stone.current_energy += charge_amount
    card.energy_consumed += charge_amount

    db.commit()
    db.refresh(stone)
    db.refresh(card)

    card_remaining = card.energy_value - card.energy_consumed

    return ChargeCardResponse(
        success=True,
        card_id=card.id,
        stone_id=stone.id,
        energy_charged=charge_amount,
        stone_energy_after=stone.current_energy,
        card_remaining_energy=card_remaining,
        message=f"成功充值{charge_amount}点能量到石头，卡牌剩余{card_remaining}点能量"
    )


@router.post("/card/{card_id}/gift", response_model=GiftCardResponse)
def gift_card(card_id: int, request: GiftCardRequest, db: Session = Depends(get_db)):
    """赠送卡牌给其他用户（发送后等待接收确认）。"""
    card = db.query(Card).filter(Card.id == card_id).first()
    if not card:
        raise HTTPException(status_code=404, detail="卡牌不存在")

    # 检查当前用户是否拥有这张卡牌
    if card.owner_id is None:
        raise HTTPException(status_code=400, detail="该卡牌无主人，无法赠送")

    to_user = db.query(User).filter(User.id == request.to_user_id).first()
    if not to_user:
        raise HTTPException(status_code=404, detail="接收用户不存在")

    if card.owner_id == request.to_user_id:
        raise HTTPException(status_code=400, detail="不能赠送给自己")

    # 检查卡牌状态
    if card.gift_status == "PENDING":
        raise HTTPException(status_code=400, detail="该卡牌正在等待被接收，无法再次赠送")

    # 检查卡牌是否有剩余能量
    remaining = card.energy_value - card.energy_consumed
    if remaining <= 0:
        raise HTTPException(status_code=400, detail="卡牌能量已耗尽，无法赠送")

    # 记录赠送者并设置等待状态
    from_user_id = card.owner_id
    card.owner_id = request.to_user_id
    card.gift_from_id = from_user_id
    card.gift_status = "PENDING"
    db.commit()
    db.refresh(card)

    return GiftCardResponse(
        success=True,
        card_id=card.id,
        from_user_id=from_user_id,
        to_user_id=request.to_user_id,
        to_user_nickname=to_user.nickname,
        message=f"卡牌已发送给 {to_user.nickname}，等待对方确认接收"
    )


@router.get("/user/{user_id}/pending-cards", response_model=PendingCardListResponse)
def get_pending_cards(user_id: int, db: Session = Depends(get_db)):
    """获取待接收的卡牌消息。"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    # 查询待接收的卡牌（owner_id=user_id且gift_status=PENDING）
    pending_cards = db.query(Card).filter(
        Card.owner_id == user_id,
        Card.gift_status == "PENDING"
    ).all()

    result = []
    for card in pending_cards:
        remaining = card.energy_value - card.energy_consumed
        type_name = CARD_TYPE_NAMES.get(card.card_type, "未知")
        level_name = ENERGY_LEVELS.get(card.energy_level, {}).get("name", "未知")

        # 获取赠送者昵称
        from_nickname = None
        if card.gift_from_id:
            from_user = db.query(User).filter(User.id == card.gift_from_id).first()
            from_nickname = from_user.nickname if from_user else None

        result.append(PendingCardResponse(
            id=card.id,
            card_type=card.card_type,
            card_type_name=type_name,
            mantra=card.mantra,
            energy_level=card.energy_level,
            energy_level_name=level_name,
            energy_value=card.energy_value,
            remaining_energy=remaining,
            color_code=_get_card_color_code(card.card_type),
            from_user_id=card.gift_from_id or 0,
            from_user_nickname=from_nickname,
            created_at=card.created_at
        ))

    return PendingCardListResponse(cards=result, total=len(result))


@router.post("/card/{card_id}/accept", response_model=AcceptCardResponse)
def accept_card(card_id: int, user_id: int, db: Session = Depends(get_db)):
    """确认接收卡牌。"""
    card = db.query(Card).filter(Card.id == card_id).first()
    if not card:
        raise HTTPException(status_code=404, detail="卡牌不存在")

    if card.owner_id != user_id:
        raise HTTPException(status_code=400, detail="这张卡牌不是发送给您的")

    if card.gift_status != "PENDING":
        raise HTTPException(status_code=400, detail="该卡牌不在待接收状态")

    # 确认接收
    card.gift_status = "RECEIVED"
    db.commit()
    db.refresh(card)

    type_name = CARD_TYPE_NAMES.get(card.card_type, "未知")
    level_name = ENERGY_LEVELS.get(card.energy_level, {}).get("name", "未知")

    return AcceptCardResponse(
        success=True,
        card_id=card.id,
        message=f"已成功接收【{type_name}】{level_name}级卡牌"
    )


@router.get("/card/{card_id}")
def get_card_detail(card_id: int, db: Session = Depends(get_db)):
    """获取卡牌详情。"""
    card = db.query(Card).filter(Card.id == card_id).first()
    if not card:
        raise HTTPException(status_code=404, detail="卡牌不存在")

    remaining = card.energy_value - card.energy_consumed
    type_name = CARD_TYPE_NAMES.get(card.card_type, "未知")
    level_name = ENERGY_LEVELS.get(card.energy_level, {}).get("name", "未知")

    # 检查用户是否拥有匹配类型石头
    user_stone_types = set()
    if card.owner_id:
        user_stones = db.query(EnergyStone).filter(
            EnergyStone.owner_id == card.owner_id,
            EnergyStone.status == "ALIVE"
        ).all()
        for stone in user_stones:
            user_stone_types.add(stone.stone_type)

    can_charge = remaining > 0 and card.card_type in user_stone_types

    return CardResponse(
        id=card.id,
        card_type=card.card_type,
        card_type_name=type_name,
        mantra=card.mantra,
        energy_level=card.energy_level,
        energy_level_name=level_name,
        energy_value=card.energy_value,
        energy_consumed=card.energy_consumed,
        remaining_energy=remaining,
        color_code=_get_card_color_code(card.card_type),
        can_charge=can_charge,
        created_at=card.created_at
    )
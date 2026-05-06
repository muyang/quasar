import json as _json
import random
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.database import get_db
from app.models import EnergyStone, CheckInRecord, User, TransferRecord, Card, UserDrawRecord, PresetCard, StoreItem, Message, PlazaPost, PlazaPray
from app.schemas import (
    ChargeResponse, CheckInStatusResponse, CheckInRecordResponse, CheckInRecordsResponse,
    UserResponse, UserRegisterRequest, LoginByStoneRequest, StoneCreateRequest, StoneBindRequest,
    TransferRequest, TransferResponse, StoneDetailResponse, StoneListResponse,
    StoneStatus, STONE_TYPES, ENERGY_LEVELS, CARD_TYPE_NAMES,
    CardResponse, CardListResponse, DrawCardRequest, DrawCardResponse, DrawStatusResponse,
    ChargeCardRequest, ChargeCardResponse, GiftCardRequest, GiftCardResponse,
    PendingCardResponse, PendingCardListResponse, AcceptCardResponse,
    SynthesizeRequest, SynthesizeResponse, CollectionProgress, CollectionResponse,
    StoreItemResponse, StoreItemListResponse, PurchaseRequest, PurchaseResponse,
    MessageResponse, MessageListResponse, SendMessageRequest,
    PlazaPostResponse, PlazaPostListResponse, CreatePostRequest, PrayResponse,
    GiftEnergyResponse, PlazaGifterInfo,
    CardStats, CardEffect, RARITY_NAMES, CARD_TYPE_SUB_NAMES,
)
from app.card_service import draw_card_gacha, get_pity_counters, synthesize_cards as svc_synthesize

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


def _build_card_response(c: Card) -> CardResponse:
    """构建CardResponse，包含v0.6.0新字段。"""
    remaining = c.energy_value - c.energy_consumed
    type_name = CARD_TYPE_NAMES.get(c.card_type, "未知")
    level_name = ENERGY_LEVELS.get(c.energy_level, {}).get("name", "未知")
    rarity_name = RARITY_NAMES.get(c.rarity) if c.rarity else None
    card_type_sub_name = CARD_TYPE_SUB_NAMES.get(c.card_type_sub) if c.card_type_sub else None

    stats = None
    if c.stats_json:
        try:
            s = _json.loads(c.stats_json)
            stats = CardStats(attack=s.get("attack", 0), health=s.get("health", 0))
        except Exception:
            pass

    tags = None
    if c.tags_json:
        try:
            tags = _json.loads(c.tags_json)
        except Exception:
            pass

    effects = None
    if c.effects_json:
        try:
            eff_list = _json.loads(c.effects_json)
            effects = [CardEffect(**e) for e in eff_list]
        except Exception:
            pass

    return CardResponse(
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
        can_charge=remaining > 0,
        created_at=c.created_at,
        image_url=c.image_url,
        card_id=c.card_id_ref,
        name=c.name,
        faction=c.faction,
        rarity=c.rarity,
        rarity_name=rarity_name,
        card_type_sub=c.card_type_sub,
        card_type_sub_name=card_type_sub_name,
        cost=c.cost,
        stats=stats,
        tags=tags,
        effects=effects,
        lore=c.lore,
        card_width=c.card_width,
        card_height=c.card_height,
        image_fit=c.image_fit or "COVER",
        margin_top=c.margin_top or 0,
        margin_left=c.margin_left or 0,
        margin_bottom=c.margin_bottom or 0,
        margin_right=c.margin_right or 0,
    )


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

    # v0.6.0 获取保底计数器
    pity = get_pity_counters(db, user_id)

    return DrawStatusResponse(
        free_draws_available=free_draws_available,
        energy_draws_used=energy_draws_used,
        energy_draws_remaining=energy_draws_remaining,
        pity_gold=pity.pulls_since_gold,
        pity_black_gold=pity.pulls_since_black_gold,
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

    # v0.6.0 使用抽卡系统（含保底）
    try:
        new_card = draw_card_gacha(db, request.user_id, request.draw_type)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"抽卡失败: {e}")

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

    rarity_cn = RARITY_NAMES.get(new_card.rarity, "") if new_card.rarity else ""
    type_name = CARD_TYPE_NAMES.get(new_card.card_type, "未知")

    return DrawCardResponse(
        success=True,
        card=_build_card_response(new_card),
        message=f"抽到{rarity_cn}卡牌【{type_name}】{new_card.name or '未知卡牌'}！",
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
        cr = _build_card_response(c)
        # 检查是否可充值：需要同类型石头
        cr.can_charge = cr.remaining_energy > 0 and c.card_type in user_stone_types
        card_list.append(cr)

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
    db.flush()  # 先flush获取更新状态

    # 为接收者创建一条私信通知
    from_user = db.query(User).filter(User.id == from_user_id).first()
    type_name = CARD_TYPE_NAMES.get(card.card_type, "未知")
    level_name = ENERGY_LEVELS.get(card.energy_level, {}).get("name", "未知")
    gift_msg = Message(
        sender_id=from_user_id,
        receiver_id=request.to_user_id,
        msg_type="USER_MSG",
        msg_subtype="GIFT_CARD",
        title=f"{from_user.nickname if from_user else '用户'} 赠送了一张卡牌",
        content=f"【{type_name}】{level_name}级卡牌\n{card.mantra}",
        card_id=card.id,
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(gift_msg)
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

    cr = _build_card_response(card)

    # 检查用户是否拥有匹配类型石头
    if card.owner_id:
        user_stone_types = {s.stone_type for s in db.query(EnergyStone).filter(
            EnergyStone.owner_id == card.owner_id,
            EnergyStone.status == "ALIVE",
        ).all()}
        cr.can_charge = cr.remaining_energy > 0 and card.card_type in user_stone_types

    return cr


# ==================== 卡牌合成 ====================

@router.post("/card/synthesize", response_model=SynthesizeResponse)
def synthesize_cards(request: SynthesizeRequest, db: Session = Depends(get_db)):
    """v0.6.0 合成：3张同阵营同稀有度卡牌 → 1张下一稀有度卡牌。"""
    new_card = svc_synthesize(db, request.user_id, request.card_ids)
    if new_card is None:
        raise HTTPException(status_code=400, detail="合成失败：需要3张同阵营同稀有度卡牌，且未达最高稀有度")

    rarity_cn = RARITY_NAMES.get(new_card.rarity, "") if new_card.rarity else ""

    return SynthesizeResponse(
        success=True,
        card=_build_card_response(new_card),
        message=f"合成成功！获得{rarity_cn}卡牌【{new_card.name or '未知'}】",
    )


# ==================== 卡牌收藏 ====================

@router.get("/user/{user_id}/collection", response_model=CollectionResponse)
def get_collection(user_id: int, db: Session = Depends(get_db)):
    """获取用户卡牌收藏进度（按类型统计已收集的预设卡牌）。"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    collections = []
    for card_type in ["HEALTH", "LOVE", "WEALTH", "CAREER", "FAMILY"]:
        total = db.query(PresetCard).filter(PresetCard.card_type == card_type).count()
        collected = len(set(
        c.preset_card_id for c in db.query(Card.preset_card_id).filter(
            Card.owner_id == user_id,
            Card.card_type == card_type,
            Card.gift_status != "PENDING",
        ).all()
    ))
        type_name = CARD_TYPE_NAMES.get(card_type, "未知")
        collections.append(CollectionProgress(card_type=card_type, card_type_name=type_name, collected=collected, total=total))

    return CollectionResponse(collections=collections)


# ==================== 商店接口 ====================

@router.get("/store/items", response_model=StoreItemListResponse)
def get_store_items(db: Session = Depends(get_db)):
    """获取可购买的商店物品列表。"""
    items = db.query(StoreItem).filter(StoreItem.is_active == True).order_by(StoreItem.id).all()
    return StoreItemListResponse(
        items=[StoreItemResponse(id=i.id, item_type=i.item_type, name=i.name, stone_type=i.stone_type, energy_amount=i.energy_amount, price=i.price, is_active=i.is_active) for i in items]
    )


@router.post("/store/purchase", response_model=PurchaseResponse)
def purchase_item(request: PurchaseRequest, db: Session = Depends(get_db)):
    """购买商店物品（消耗能量）。"""
    user = db.query(User).filter(User.id == request.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    item = db.query(StoreItem).filter(StoreItem.id == request.item_id, StoreItem.is_active == True).first()
    if not item:
        raise HTTPException(status_code=404, detail="物品不存在或已下架")

    # 计算用户总能量
    user_stones = db.query(EnergyStone).filter(
        EnergyStone.owner_id == request.user_id,
        EnergyStone.status == "ALIVE",
    ).all()
    total_energy = sum(s.current_energy for s in user_stones)

    if total_energy < item.price:
        raise HTTPException(status_code=400, detail=f"能量不足，需要{ item.price}点能量，当前{total_energy}点")

    # 从能量最高的石头扣除
    remaining_cost = item.price
    stones_sorted = sorted(user_stones, key=lambda s: s.current_energy, reverse=True)
    for stone in stones_sorted:
        if remaining_cost <= 0:
            break
        deduct = min(stone.current_energy, remaining_cost)
        stone.current_energy -= deduct
        remaining_cost -= deduct

    # 根据物品类型处理
    if item.item_type == "STONE" and item.stone_type:
        existing = db.query(EnergyStone).filter(
            EnergyStone.owner_id == request.user_id,
            EnergyStone.stone_type == item.stone_type,
        ).first()
        if existing:
            raise HTTPException(status_code=400, detail="您已拥有该类型水晶")
        unique_code = _generate_unique_code(db, item.stone_type)
        new_stone = EnergyStone(
            unique_code=unique_code,
            stone_type=item.stone_type,
            owner_id=request.user_id,
            current_energy=10,
            consecutive_days=0,
        )
        db.add(new_stone)
    elif item.item_type == "ENERGY_PACK":
        if user_stones:
            user_stones[0].current_energy = min(user_stones[0].current_energy + item.energy_amount, ENERGY_CAP)

    db.commit()

    new_total = sum(s.current_energy for s in db.query(EnergyStone).filter(
        EnergyStone.owner_id == request.user_id, EnergyStone.status == "ALIVE"
    ).all())

    return PurchaseResponse(
        success=True,
        item_name=item.name,
        energy_deducted=item.price,
        user_total_energy=new_total,
        message=f"成功购买{item.name}",
    )


# ==================== 消息接口 ====================

@router.get("/user/{user_id}/messages", response_model=MessageListResponse)
def get_messages(user_id: int, msg_type: str = None, db: Session = Depends(get_db)):
    """获取用户消息列表。msg_type可选: ANNOUNCEMENT/USER_MSG/SYSTEM。"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    q = db.query(Message).filter(
        (Message.receiver_id == user_id) | ((Message.receiver_id == None) & (Message.msg_type == "ANNOUNCEMENT"))
    )
    if msg_type:
        q = q.filter(Message.msg_type == msg_type)
    msgs = q.order_by(Message.created_at.desc()).all()

    unread = db.query(Message).filter(
        (Message.receiver_id == user_id) | ((Message.receiver_id == None) & (Message.msg_type == "ANNOUNCEMENT")),
        Message.is_read == False,
    ).count()

    result = []
    for m in msgs:
        sender_nickname = None
        if m.sender_id:
            s = db.query(User).filter(User.id == m.sender_id).first()
            sender_nickname = s.nickname if s else None

        # 如果是卡牌赠送消息，附带卡牌信息
        card_info = None
        if m.msg_subtype == "GIFT_CARD" and m.card_id:
            card = db.query(Card).filter(Card.id == m.card_id).first()
            if card and card.gift_status == "PENDING":
                type_name = CARD_TYPE_NAMES.get(card.card_type, "未知")
                level_name = ENERGY_LEVELS.get(card.energy_level, {}).get("name", "未知")
                remaining = card.energy_value - card.energy_consumed
                from_nickname = None
                if card.gift_from_id:
                    from_user = db.query(User).filter(User.id == card.gift_from_id).first()
                    from_nickname = from_user.nickname if from_user else None
                card_info = PendingCardResponse(
                    id=card.id, card_type=card.card_type,
                    card_type_name=type_name, mantra=card.mantra,
                    energy_level=card.energy_level, energy_level_name=level_name,
                    energy_value=card.energy_value, remaining_energy=remaining,
                    color_code=_get_card_color_code(card.card_type),
                    from_user_id=card.gift_from_id or 0,
                    from_user_nickname=from_nickname,
                    created_at=card.created_at,
                )

        result.append(MessageResponse(
            id=m.id, msg_type=m.msg_type, msg_subtype=m.msg_subtype,
            title=m.title, content=m.content,
            sender_id=m.sender_id, sender_nickname=sender_nickname,
            is_read=m.is_read, created_at=m.created_at,
            card_info=card_info,
        ))

    return MessageListResponse(messages=result, total=len(result), unread_count=unread)


@router.post("/message/send", response_model=MessageResponse)
def send_message(request: SendMessageRequest, db: Session = Depends(get_db)):
    """发送用户私信。"""
    sender = db.query(User).filter(User.id == request.sender_id).first()
    receiver = db.query(User).filter(User.id == request.receiver_id).first()
    if not sender or not receiver:
        raise HTTPException(status_code=404, detail="用户不存在")
    if request.sender_id == request.receiver_id:
        raise HTTPException(status_code=400, detail="不能给自己发消息")

    msg = Message(
        sender_id=request.sender_id,
        receiver_id=request.receiver_id,
        msg_type="USER_MSG",
        title=request.title,
        content=request.content,
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)

    return MessageResponse(
        id=msg.id, msg_type=msg.msg_type, title=msg.title, content=msg.content,
        sender_id=msg.sender_id, sender_nickname=sender.nickname,
        is_read=False, created_at=msg.created_at,
    )


@router.post("/message/{message_id}/read")
def mark_message_read(message_id: int, user_id: int, db: Session = Depends(get_db)):
    """标记消息为已读。"""
    msg = db.query(Message).filter(Message.id == message_id).first()
    if not msg:
        raise HTTPException(status_code=404, detail="消息不存在")
    msg.is_read = True
    db.commit()
    return {"success": True}


@router.get("/announcements")
def get_announcements(db: Session = Depends(get_db)):
    """获取公告列表（从广场帖子中筛选 ANNOUNCEMENT 类型）。"""
    posts = db.query(PlazaPost).filter(
        PlazaPost.post_type == "ANNOUNCEMENT"
    ).order_by(PlazaPost.created_at.desc()).all()
    return {
        "posts": [{
            "id": p.id, "user_id": p.user_id, "user_nickname": p.user_nickname or "平台",
            "post_type": p.post_type, "content": p.content,
            "pray_count": p.pray_count, "created_at": p.created_at,
        } for p in posts],
        "total": len(posts),
    }


# ==================== 广场接口 ====================

@router.get("/plaza/posts", response_model=PlazaPostListResponse)
def get_plaza_posts(
    post_type: str = None,
    user_id: int = None,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
):
    """获取广场帖子列表。post_type可选: BLESSING/WISH/ACTIVITY/ANNOUNCEMENT。"""
    q = db.query(PlazaPost)
    if post_type:
        q = q.filter(PlazaPost.post_type == post_type)
    posts = q.order_by(PlazaPost.created_at.desc()).offset(skip).limit(limit).all()

    result = []
    for p in posts:
        user_nickname = p.user_nickname
        if p.user_id and not user_nickname:
            u = db.query(User).filter(User.id == p.user_id).first()
            user_nickname = u.nickname if u else None
        has_prayed = False
        if user_id:
            has_prayed = db.query(PlazaPray).filter(
                PlazaPray.post_id == p.id, PlazaPray.user_id == user_id
            ).first() is not None
        # v0.7.0: compute total energy received
        energy_sum = db.query(func.coalesce(func.sum(PlazaPray.energy_value), 0)).filter(
            PlazaPray.post_id == p.id
        ).scalar()
        result.append(PlazaPostResponse(
            id=p.id, user_id=p.user_id, user_nickname=user_nickname,
            post_type=p.post_type, tag=p.tag,
            total_energy_received=energy_sum or 0,
            content=p.content,
            pray_count=p.pray_count, has_prayed=has_prayed,
            created_at=p.created_at,
        ))

    return PlazaPostListResponse(posts=result, total=len(result))


@router.post("/plaza/post", response_model=PlazaPostResponse)
def create_plaza_post(request: CreatePostRequest, db: Session = Depends(get_db)):
    """创建祈福或许愿帖子（v0.7.0: 可选tag用于能量赠送）。"""
    if request.post_type not in ("BLESSING", "WISH"):
        raise HTTPException(status_code=400, detail="帖子类型无效")
    if request.tag and request.tag not in ("HEALTH", "LOVE", "WEALTH", "CAREER", "FAMILY"):
        raise HTTPException(status_code=400, detail="无效的能量标签")
    user = db.query(User).filter(User.id == request.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    post = PlazaPost(
        user_id=request.user_id,
        user_nickname=user.nickname,
        post_type=request.post_type,
        tag=request.tag,
        content=request.content,
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(post)
    db.commit()
    db.refresh(post)

    return PlazaPostResponse(
        id=post.id, user_id=post.user_id, user_nickname=user.nickname,
        post_type=post.post_type, tag=post.tag,
        total_energy_received=0,
        content=post.content,
        pray_count=0, has_prayed=False, created_at=post.created_at,
    )


@router.post("/plaza/post/{post_id}/pray", response_model=PrayResponse)
def pray_post(post_id: int, user_id: int, db: Session = Depends(get_db)):
    """为广场帖子祈福（每人限1次）—— v0.7.0 保留兼容，实际逻辑已迁移至 gift_energy_to_post。"""
    return _gift_energy(post_id, user_id, 1, db)


@router.post("/plaza/post/{post_id}/gift", response_model=GiftEnergyResponse)
def gift_energy_to_post(post_id: int, user_id: int, energy_value: int = 1, db: Session = Depends(get_db)):
    """v0.7.0: 赠送能量给广场帖子。从赠送者对应tag能量石扣除，充入发帖者对应tag能量石。
    跨维度等价兑换（如健康能量赠爱情帖子 → 健康石-1，发帖者爱情石+1）。"""
    return _gift_energy(post_id, user_id, energy_value, db)


def _gift_energy(post_id: int, user_id: int, energy_value: int, db: Session):
    """核心赠送逻辑：扣除赠送者能量 → 充入发帖者能量石。"""
    if energy_value < 1:
        raise HTTPException(status_code=400, detail="赠送能量至少为1")

    post = db.query(PlazaPost).filter(PlazaPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="帖子不存在")

    if post.user_id == user_id:
        raise HTTPException(status_code=400, detail="不能给自己的帖子赠送能量")

    # 获取赠送者信息
    giver = db.query(User).filter(User.id == user_id).first()
    if not giver:
        raise HTTPException(status_code=404, detail="赠送者不存在")

    existing = db.query(PlazaPray).filter(
        PlazaPray.post_id == post_id, PlazaPray.user_id == user_id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="您已为该帖子赠送过能量")

    # 帖子tag（发帖者想要充能的类型），默认用帖子类型或第一个
    target_tag = post.tag

    # 查找赠送者有能量的存活石（优先匹配tag，否则任意存活石）
    from_stone = None
    if target_tag:
        from_stone = db.query(EnergyStone).filter(
            EnergyStone.owner_id == user_id,
            EnergyStone.stone_type == target_tag,
            EnergyStone.status == "ALIVE",
            EnergyStone.current_energy >= energy_value,
        ).first()
    if not from_stone:
        # fallback: 任意存活石且有能量
        from_stone = db.query(EnergyStone).filter(
            EnergyStone.owner_id == user_id,
            EnergyStone.status == "ALIVE",
            EnergyStone.current_energy >= energy_value,
        ).order_by(EnergyStone.current_energy.desc()).first()
    if not from_stone:
        raise HTTPException(status_code=400, detail="能量不足，无法赠送")

    # 扣除赠送者能量
    from_stone.current_energy -= energy_value
    from_stone_id = from_stone.id

    # 查找发帖者对应tag的能量石（如果帖子有tag）充入
    to_stone_id = 0
    if post.user_id and target_tag:
        to_stone = db.query(EnergyStone).filter(
            EnergyStone.owner_id == post.user_id,
            EnergyStone.stone_type == target_tag,
            EnergyStone.status == "ALIVE",
        ).first()
        if to_stone:
            to_stone.current_energy = min(to_stone.current_energy + energy_value, ENERGY_CAP)
            to_stone_id = to_stone.id

    # 创建赠送记录
    pray = PlazaPray(
        post_id=post_id,
        user_id=user_id,
        energy_value=energy_value,
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    post.pray_count += 1
    db.add(pray)
    db.commit()

    tag_name = CARD_TYPE_NAMES.get(target_tag, "") if target_tag else ""
    msg = f"成功赠送{energy_value}点能量" + (f"至发帖者的{tag_name}能量石" if to_stone_id else "")

    return GiftEnergyResponse(
        success=True,
        pray_count=post.pray_count,
        energy_gifted=energy_value,
        from_stone_id=from_stone_id,
        to_stone_id=to_stone_id,
        message=msg,
    )


@router.get("/plaza/post/{post_id}/gifters")
def get_post_gifters(post_id: int, db: Session = Depends(get_db)):
    """v0.7.0: 获取帖子赠送者列表。"""
    post = db.query(PlazaPost).filter(PlazaPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="帖子不存在")

    prays = db.query(PlazaPray).filter(
        PlazaPray.post_id == post_id
    ).order_by(PlazaPray.created_at.desc()).all()

    gifters = []
    for p in prays:
        nickname = None
        u = db.query(User).filter(User.id == p.user_id).first()
        if u:
            nickname = u.nickname
        gifters.append(PlazaGifterInfo(
            user_id=p.user_id,
            user_nickname=nickname,
            energy_value=p.energy_value,
            created_at=p.created_at,
        ))

    return {"gifters": [g.model_dump() for g in gifters], "total": len(gifters)}
import os
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Header, UploadFile, File
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User, PresetCard, StoreItem, Message, PlazaPost, CardArchetype
from app.schemas import (
    AdminLoginRequest, AdminLoginResponse,
    PresetCardManageResponse, PresetCardManageListResponse,
    PresetCardCreateRequest, PresetCardUpdateRequest,
    StoreItemResponse, StoreItemListResponse, StoreItemCreateRequest,
    AnnouncementRequest, CreateActivityRequest,
    ArchetypeResponse, ArchetypeListResponse,
    ArchetypeCreateRequest, ArchetypeUpdateRequest,
)
from app.card_service import generate_preset_pool

router = APIRouter(prefix="/api/admin", tags=["admin"])

ADMIN_TOKEN = os.environ.get("ADMIN_TOKEN", "quasar-admin-2024")


def _verify_admin(x_admin_token: str = Header(...)):
    if x_admin_token != ADMIN_TOKEN:
        raise HTTPException(status_code=403, detail="管理员验证失败")
    return True


def _build_preset_response(c):
    return PresetCardManageResponse(
        id=c.id, card_type=c.card_type, mantra=c.mantra,
        energy_level=c.energy_level, image_url=c.image_url,
        card_id=c.card_id, name=c.name, faction=c.faction,
        rarity=c.rarity, card_type_sub=c.card_type_sub,
        cost=c.cost, tags_json=c.tags_json,
        status=c.status,
        card_width=c.card_width, card_height=c.card_height,
        image_fit=c.image_fit,
        margin_top=c.margin_top, margin_left=c.margin_left,
        margin_bottom=c.margin_bottom, margin_right=c.margin_right,
    )


@router.post("/login", response_model=AdminLoginResponse)
def admin_login(request: AdminLoginRequest):
    if request.admin_token == ADMIN_TOKEN:
        return AdminLoginResponse(success=True, message="管理员登录成功")
    raise HTTPException(status_code=403, detail="管理员验证失败")


# ==================== 预设卡牌管理 ====================

@router.get("/preset-cards", response_model=PresetCardManageListResponse)
def list_preset_cards(
    card_type: str = None,
    energy_level: int = None,
    faction: str = None,
    rarity: str = None,
    status: str = None,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    q = db.query(PresetCard)
    if card_type:
        q = q.filter(PresetCard.card_type == card_type)
    if energy_level:
        q = q.filter(PresetCard.energy_level == energy_level)
    if faction:
        q = q.filter(PresetCard.faction == faction)
    if rarity:
        q = q.filter(PresetCard.rarity == rarity)
    if status:
        q = q.filter(PresetCard.status == status)
    total = q.count()
    cards = q.order_by(PresetCard.id).offset(skip).limit(limit).all()
    return PresetCardManageListResponse(
        cards=[PresetCardManageResponse(
            id=c.id, card_type=c.card_type, mantra=c.mantra,
            energy_level=c.energy_level, image_url=c.image_url,
            card_id=c.card_id, name=c.name, faction=c.faction,
            rarity=c.rarity, card_type_sub=c.card_type_sub,
            cost=c.cost, tags_json=c.tags_json,
            status=c.status,
            card_width=c.card_width, card_height=c.card_height,
            image_fit=c.image_fit,
            margin_top=c.margin_top, margin_left=c.margin_left,
            margin_bottom=c.margin_bottom, margin_right=c.margin_right,
        ) for c in cards],
        total=total,
    )


@router.post("/preset-cards", response_model=PresetCardManageResponse)
def create_preset_card(
    request: PresetCardCreateRequest,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    if request.card_type not in ("HEALTH", "LOVE", "WEALTH", "CAREER", "FAMILY"):
        raise HTTPException(status_code=400, detail="无效的卡牌类型")
    if request.energy_level < 1 or request.energy_level > 5:
        raise HTTPException(status_code=400, detail="能量等级必须在1-5之间")
    card = PresetCard(
        card_type=request.card_type, mantra=request.mantra,
        energy_level=request.energy_level, image_url=request.image_url,
        status=request.status,
        card_width=request.card_width, card_height=request.card_height,
        image_fit=request.image_fit,
        margin_top=request.margin_top, margin_left=request.margin_left,
        margin_bottom=request.margin_bottom, margin_right=request.margin_right,
    )
    db.add(card)
    db.commit()
    db.refresh(card)
    return _build_preset_response(card)


@router.put("/preset-cards/{card_id}", response_model=PresetCardManageResponse)
def update_preset_card(
    card_id: int,
    request: PresetCardUpdateRequest,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    card = db.query(PresetCard).filter(PresetCard.id == card_id).first()
    if not card:
        raise HTTPException(status_code=404, detail="卡牌不存在")
    if request.card_type is not None:
        if request.card_type not in ("HEALTH", "LOVE", "WEALTH", "CAREER", "FAMILY"):
            raise HTTPException(status_code=400, detail="无效的卡牌类型")
        card.card_type = request.card_type
    if request.mantra is not None:
        card.mantra = request.mantra
    if request.energy_level is not None:
        if request.energy_level < 1 or request.energy_level > 5:
            raise HTTPException(status_code=400, detail="能量等级必须在1-5之间")
        card.energy_level = request.energy_level
    if request.image_url is not None:
        card.image_url = request.image_url
    # v0.7.0 layout + status
    if request.status is not None:
        card.status = request.status
    if request.card_width is not None:
        card.card_width = request.card_width
    if request.card_height is not None:
        card.card_height = request.card_height
    if request.image_fit is not None:
        card.image_fit = request.image_fit
    if request.margin_top is not None:
        card.margin_top = request.margin_top
    if request.margin_left is not None:
        card.margin_left = request.margin_left
    if request.margin_bottom is not None:
        card.margin_bottom = request.margin_bottom
    if request.margin_right is not None:
        card.margin_right = request.margin_right
    db.commit()
    db.refresh(card)
    return _build_preset_response(card)


@router.delete("/preset-cards/{card_id}")
def delete_preset_card(
    card_id: int,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    card = db.query(PresetCard).filter(PresetCard.id == card_id).first()
    if not card:
        raise HTTPException(status_code=404, detail="卡牌不存在")
    db.delete(card)
    db.commit()
    return {"success": True, "message": "卡牌已删除"}


# ==================== 商店物品管理 ====================

@router.get("/store-items", response_model=StoreItemListResponse)
def list_store_items(
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    items = db.query(StoreItem).order_by(StoreItem.id).all()
    return StoreItemListResponse(
        items=[StoreItemResponse(id=i.id, item_type=i.item_type, name=i.name, stone_type=i.stone_type, energy_amount=i.energy_amount, price=i.price, is_active=i.is_active) for i in items]
    )


@router.post("/store-items", response_model=StoreItemResponse)
def create_store_item(
    request: StoreItemCreateRequest,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    if request.item_type not in ("STONE", "ENERGY_PACK"):
        raise HTTPException(status_code=400, detail="物品类型无效")
    if request.price < 0:
        raise HTTPException(status_code=400, detail="价格不能为负数")
    item = StoreItem(
        item_type=request.item_type,
        name=request.name,
        stone_type=request.stone_type,
        energy_amount=request.energy_amount,
        price=request.price,
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return StoreItemResponse(id=item.id, item_type=item.item_type, name=item.name, stone_type=item.stone_type, energy_amount=item.energy_amount, price=item.price, is_active=item.is_active)


@router.put("/store-items/{item_id}", response_model=StoreItemResponse)
def update_store_item(
    item_id: int,
    request: StoreItemCreateRequest,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    item = db.query(StoreItem).filter(StoreItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="物品不存在")
    item.item_type = request.item_type
    item.name = request.name
    item.stone_type = request.stone_type
    item.energy_amount = request.energy_amount
    item.price = request.price
    db.commit()
    db.refresh(item)
    return StoreItemResponse(id=item.id, item_type=item.item_type, name=item.name, stone_type=item.stone_type, energy_amount=item.energy_amount, price=item.price, is_active=item.is_active)


@router.delete("/store-items/{item_id}")
def delete_store_item(
    item_id: int,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    item = db.query(StoreItem).filter(StoreItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="物品不存在")
    db.delete(item)
    db.commit()
    return {"success": True, "message": "物品已删除"}


# ==================== 广场管理（公告+活动+帖子管理） ====================

@router.post("/announcements")
def send_announcement(
    request: AnnouncementRequest,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    """发布公告（作为广场帖子，post_type=ANNOUNCEMENT）。"""
    post = PlazaPost(
        user_id=None,
        user_nickname="平台公告",
        post_type="ANNOUNCEMENT",
        content=f"【{request.title}】{request.content}",
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(post)
    db.commit()
    db.refresh(post)
    return {"success": True, "post_id": post.id, "message": "公告已发布到广场"}


@router.post("/activities")
def create_activity(
    request: CreateActivityRequest,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    """管理员创建平台活动（作为广场帖子，post_type=ACTIVITY）。"""
    post = PlazaPost(
        user_id=None,
        user_nickname="平台活动",
        post_type="ACTIVITY",
        content=request.content,
        created_at=datetime.now(timezone.utc).isoformat(),
    )
    db.add(post)
    db.commit()
    db.refresh(post)
    return {"success": True, "post_id": post.id, "message": "活动已发布到广场"}


@router.get("/plaza-posts")
def list_plaza_posts(
    post_type: str = None,
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    """管理员查看所有广场帖子（可筛选类型，可分页）。"""
    q = db.query(PlazaPost)
    if post_type:
        q = q.filter(PlazaPost.post_type == post_type)
    total = q.count()
    posts = q.order_by(PlazaPost.created_at.desc()).offset(skip).limit(limit).all()
    return {
        "posts": [{
            "id": p.id, "user_id": p.user_id, "user_nickname": p.user_nickname,
            "post_type": p.post_type, "content": p.content,
            "pray_count": p.pray_count, "created_at": p.created_at,
        } for p in posts],
        "total": total,
    }


@router.delete("/plaza-posts/{post_id}")
def delete_plaza_post(
    post_id: int,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    """管理员删除任意广场帖子。"""
    post = db.query(PlazaPost).filter(PlazaPost.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="帖子不存在")
    db.delete(post)
    db.commit()
    return {"success": True, "message": "帖子已删除"}


# ==================== 用户管理（简化） ====================

@router.get("/users")
def list_users(
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    users = db.query(User).order_by(User.id).all()
    return {
        "users": [{"id": u.id, "nickname": u.nickname, "is_admin": u.is_admin, "created_at": u.created_at} for u in users],
        "total": len(users),
    }


# ==================== 文件上传 ====================

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "webp", "gif"}
MAX_UPLOAD_SIZE = 5 * 1024 * 1024  # 5 MB


@router.post("/upload-image")
async def upload_image(
    file: UploadFile = File(...),
    _: bool = Depends(_verify_admin),
):
    """上传卡牌图片，返回静态文件URL。"""
    ext = file.filename.split(".")[-1].lower() if "." in (file.filename or "") else ""
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"不支持的文件类型: .{ext}，允许: {', '.join(ALLOWED_EXTENSIONS)}")

    contents = await file.read()
    if len(contents) > MAX_UPLOAD_SIZE:
        raise HTTPException(status_code=400, detail="文件大小超过5MB限制")

    os.makedirs("static/cards", exist_ok=True)
    unique_name = f"{uuid.uuid4().hex[:12]}.{ext}"
    filepath = os.path.join("static/cards", unique_name)
    with open(filepath, "wb") as f:
        f.write(contents)

    url = f"/static/cards/{unique_name}"
    return {"success": True, "url": url, "filename": file.filename}


# ==================== v0.6.0 原型管理 & 卡牌池生成 ====================


@router.get("/archetypes", response_model=ArchetypeListResponse)
def list_archetypes(
    faction: str = None,
    rarity: str = None,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    q = db.query(CardArchetype)
    if faction:
        q = q.filter(CardArchetype.faction == faction)
    if rarity:
        q = q.filter(CardArchetype.rarity == rarity)
    archetypes = q.order_by(CardArchetype.id).all()
    return ArchetypeListResponse(
        archetypes=[ArchetypeResponse(
            id=a.id, archetype_id=a.archetype_id, faction=a.faction,
            rarity=a.rarity, card_type=a.card_type,
            name_templates_json=a.name_templates_json, base_cost=a.base_cost,
            base_stats_json=a.base_stats_json, base_effects_json=a.base_effects_json,
            lore_template=a.lore_template, tags_json=a.tags_json,
            version=a.version, is_active=a.is_active,
        ) for a in archetypes],
        total=len(archetypes),
    )


@router.post("/archetypes", response_model=ArchetypeResponse)
def create_archetype(
    request: ArchetypeCreateRequest,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    a = CardArchetype(
        archetype_id=request.archetype_id,
        faction=request.faction,
        rarity=request.rarity,
        card_type=request.card_type,
        name_templates_json=request.name_templates_json,
        base_cost=request.base_cost,
        base_stats_json=request.base_stats_json,
        base_effects_json=request.base_effects_json,
        lore_template=request.lore_template,
        tags_json=request.tags_json,
    )
    db.add(a)
    db.commit()
    db.refresh(a)
    return ArchetypeResponse(
        id=a.id, archetype_id=a.archetype_id, faction=a.faction,
        rarity=a.rarity, card_type=a.card_type,
        name_templates_json=a.name_templates_json, base_cost=a.base_cost,
        base_stats_json=a.base_stats_json, base_effects_json=a.base_effects_json,
        lore_template=a.lore_template, tags_json=a.tags_json,
        version=a.version, is_active=a.is_active,
    )


@router.put("/archetypes/{archetype_id}", response_model=ArchetypeResponse)
def update_archetype(
    archetype_id: int,
    request: ArchetypeUpdateRequest,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    a = db.query(CardArchetype).filter(CardArchetype.id == archetype_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="原型不存在")
    for field in ["faction", "rarity", "card_type", "name_templates_json",
                   "base_stats_json", "base_effects_json", "lore_template", "tags_json"]:
        val = getattr(request, field, None)
        if val is not None:
            setattr(a, field, val)
    if request.base_cost is not None:
        a.base_cost = request.base_cost
    if request.is_active is not None:
        a.is_active = request.is_active
    db.commit()
    db.refresh(a)
    return ArchetypeResponse(
        id=a.id, archetype_id=a.archetype_id, faction=a.faction,
        rarity=a.rarity, card_type=a.card_type,
        name_templates_json=a.name_templates_json, base_cost=a.base_cost,
        base_stats_json=a.base_stats_json, base_effects_json=a.base_effects_json,
        lore_template=a.lore_template, tags_json=a.tags_json,
        version=a.version, is_active=a.is_active,
    )


@router.delete("/archetypes/{archetype_id}")
def delete_archetype(
    archetype_id: int,
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    a = db.query(CardArchetype).filter(CardArchetype.id == archetype_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="原型不存在")
    db.delete(a)
    db.commit()
    return {"success": True, "message": "原型已删除"}


@router.post("/preset-cards/generate")
def regenerate_preset_pool(
    db: Session = Depends(get_db),
    _: bool = Depends(_verify_admin),
):
    """重新从原型生成365张预设卡牌池（会删除所有旧卡牌）。"""
    count = generate_preset_pool(db)
    return {"success": True, "total": count, "message": f"已重新生成{count}张预设卡牌"}

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import get_db
from app.main import app
from app.models import (
    Base, User, EnergyStone, PresetCard, Card,
    StoreItem, Message, PlazaPost, PlazaPray
)

SQLALCHEMY_DATABASE_URL = "sqlite:///./test_energy_stone.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_database():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


_counter = 0


def _create_user(nickname="testuser", is_admin=False) -> User:
    global _counter
    _counter += 1
    db = TestingSessionLocal()
    user = User(nickname=f"{nickname}_{_counter}", is_admin=is_admin, created_at="2025-01-01T00:00:00")
    db.add(user)
    db.commit()
    db.refresh(user)
    db.close()
    return user


def _create_stone(user_id, stone_type="HEALTH", energy=50) -> EnergyStone:
    global _counter
    _counter += 1
    db = TestingSessionLocal()
    stone = EnergyStone(
        unique_code=f"HRY-TEST{ _counter:06d}",
        stone_type=stone_type,
        owner_id=user_id,
        current_energy=energy,
        status="ALIVE",
    )
    db.add(stone)
    db.commit()
    db.refresh(stone)
    db.close()
    return stone


def _create_preset_card(card_type="HEALTH", level=2, mantra="测试咒语", rarity="IRON") -> PresetCard:
    db = TestingSessionLocal()
    card = PresetCard(
        card_type=card_type, mantra=mantra, energy_level=level,
        name="测试卡牌", faction=card_type, rarity=rarity,
        card_type_sub="UNIT", cost=1,
        tags_json='["test"]', effects_json='[{"type":"heal","target":"self","value":1}]',
    )
    db.add(card)
    db.commit()
    db.refresh(card)
    db.close()
    return card


def _create_card(user_id, card_type="HEALTH", level=2, energy_value=10, rarity="IRON") -> Card:
    global _counter
    _counter += 1
    preset = _create_preset_card(card_type, level, rarity=rarity)
    db = TestingSessionLocal()
    card = Card(
        preset_card_id=preset.id, card_type=card_type, mantra=preset.mantra,
        energy_level=level, energy_value=energy_value, energy_consumed=0,
        owner_id=user_id, created_at="2025-01-01T00:00:00",
        name=preset.name, faction=preset.faction, rarity=preset.rarity,
        card_type_sub=preset.card_type_sub, cost=preset.cost,
        stats_json=preset.stats_json, tags_json=preset.tags_json,
        effects_json=preset.effects_json,
    )
    db.add(card)
    db.commit()
    db.refresh(card)
    db.close()
    return card


# ==================== Synthesis Tests ====================

def test_synthesize_three_same_cards():
    """3张同阵营同稀有度卡牌合成1张高一级稀有度卡牌。"""
    user = _create_user()
    c1 = _create_card(user.id, "HEALTH", 2, 10, rarity="IRON")
    c2 = _create_card(user.id, "HEALTH", 2, 10, rarity="IRON")
    c3 = _create_card(user.id, "HEALTH", 2, 10, rarity="IRON")
    # Need preset cards for BRONZE rarity (next after IRON)
    _create_preset_card("HEALTH", 3, "高级咒语", rarity="BRONZE")

    resp = client.post("/api/card/synthesize", json={
        "user_id": user.id, "card_ids": [c1.id, c2.id, c3.id]
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["card"]["rarity"] == "BRONZE"
    assert data["card"]["card_type"] == "HEALTH"


def test_synthesize_wrong_count():
    """合成需要恰好3张卡牌。"""
    user = _create_user()
    c1 = _create_card(user.id, "HEALTH", 2, 10)
    resp = client.post("/api/card/synthesize", json={
        "user_id": user.id, "card_ids": [c1.id]
    })
    assert resp.status_code == 400


def test_synthesize_different_types_rejected():
    """不同阵营卡牌不能合成。"""
    user = _create_user()
    c1 = _create_card(user.id, "HEALTH", 2, 10, rarity="IRON")
    c2 = _create_card(user.id, "HEALTH", 2, 10, rarity="IRON")
    c3 = _create_card(user.id, "LOVE", 2, 10, rarity="IRON")

    resp = client.post("/api/card/synthesize", json={
        "user_id": user.id, "card_ids": [c1.id, c2.id, c3.id]
    })
    assert resp.status_code == 400
    assert "同阵营" in resp.json()["detail"]


def test_synthesize_level_cap():
    """BLACK_GOLD卡牌无法继续合成（已是最高稀有度）。"""
    user = _create_user()
    c1 = _create_card(user.id, "HEALTH", 5, 40, rarity="BLACK_GOLD")
    c2 = _create_card(user.id, "HEALTH", 5, 40, rarity="BLACK_GOLD")
    c3 = _create_card(user.id, "HEALTH", 5, 40, rarity="BLACK_GOLD")

    resp = client.post("/api/card/synthesize", json={
        "user_id": user.id, "card_ids": [c1.id, c2.id, c3.id]
    })
    assert resp.status_code == 400
    assert "未达最高稀有度" in resp.json()["detail"]


# ==================== Message Tests ====================

def test_send_user_message():
    """用户之间发送私信。"""
    u1 = _create_user("alice")
    u2 = _create_user("bob")
    resp = client.post("/api/message/send", json={
        "sender_id": u1.id, "receiver_id": u2.id,
        "title": "Hello", "content": "你好！"
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["title"] == "Hello"
    assert data["msg_type"] == "USER_MSG"
    assert data["sender_nickname"] == u1.nickname


def test_get_user_inbox():
    """获取用户消息列表。"""
    u1 = _create_user("alice")
    u2 = _create_user("bob")
    client.post("/api/message/send", json={
        "sender_id": u2.id, "receiver_id": u1.id,
        "title": "Test", "content": "Hello"
    })
    resp = client.get(f"/api/user/{u1.id}/messages")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 1
    assert data["unread_count"] == 1


def test_mark_message_read():
    """标记消息已读。"""
    u1 = _create_user("alice")
    u2 = _create_user("bob")
    r = client.post("/api/message/send", json={
        "sender_id": u2.id, "receiver_id": u1.id,
        "title": "Test", "content": "Hello"
    })
    msg_id = r.json()["id"]
    resp = client.post(f"/api/message/{msg_id}/read?user_id={u1.id}")
    assert resp.status_code == 200
    assert resp.json()["success"] is True


# ==================== Plaza Tests ====================

def test_create_blessing_post():
    """创建祈福帖子。"""
    user = _create_user()
    resp = client.post("/api/plaza/post", json={
        "user_id": user.id, "post_type": "BLESSING",
        "content": "愿世界和平"
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["post_type"] == "BLESSING"
    assert data["pray_count"] == 0


def test_pray_post():
    """为帖子祈福。"""
    user = _create_user()
    post_resp = client.post("/api/plaza/post", json={
        "user_id": user.id, "post_type": "WISH", "content": "心想事成"
    })
    post_id = post_resp.json()["id"]

    u2 = _create_user("prayer")
    resp = client.post(f"/api/plaza/post/{post_id}/pray?user_id={u2.id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["pray_count"] == 1


def test_cannot_pray_twice():
    """同一用户不能重复祈福。"""
    user = _create_user()
    post_resp = client.post("/api/plaza/post", json={
        "user_id": user.id, "post_type": "WISH", "content": "祈祷"
    })
    post_id = post_resp.json()["id"]

    u2 = _create_user("prayer")
    client.post(f"/api/plaza/post/{post_id}/pray?user_id={u2.id}")
    resp = client.post(f"/api/plaza/post/{post_id}/pray?user_id={u2.id}")
    assert resp.status_code == 400
    assert "已" in resp.json()["detail"]


def test_list_plaza_posts():
    """获取广场帖子列表。"""
    user = _create_user()
    client.post("/api/plaza/post", json={
        "user_id": user.id, "post_type": "BLESSING", "content": "test1"
    })
    client.post("/api/plaza/post", json={
        "user_id": user.id, "post_type": "WISH", "content": "test2"
    })
    resp = client.get("/api/plaza/posts")
    assert resp.status_code == 200
    assert resp.json()["total"] == 2


# ==================== Store Tests ====================

def test_list_store_items():
    """获取商店物品列表。"""
    db = TestingSessionLocal()
    item = StoreItem(
        item_type="ENERGY_PACK", name="小能量包",
        energy_amount=20, price=10, is_active=True,
        created_at="2025-01-01T00:00:00",
    )
    db.add(item)
    db.commit()
    db.close()

    resp = client.get("/api/store/items")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["items"]) >= 1


def test_purchase_energy_pack():
    """购买能量包。"""
    user = _create_user()
    _create_stone(user.id, "HEALTH", 50)

    db = TestingSessionLocal()
    item = StoreItem(
        item_type="ENERGY_PACK", name="小能量包",
        energy_amount=20, price=10, is_active=True,
        created_at="2025-01-01T00:00:00",
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    db.close()

    resp = client.post("/api/store/purchase", json={
        "user_id": user.id, "item_id": item.id
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["energy_deducted"] == 10


# ==================== Collection Tests ====================

def test_get_collection():
    """获取收藏进度。"""
    user = _create_user()
    _create_preset_card("HEALTH", 1, "咒语1")
    _create_preset_card("HEALTH", 2, "咒语2")
    _create_card(user.id, "HEALTH", 1, 10)

    resp = client.get(f"/api/user/{user.id}/collection")
    assert resp.status_code == 200
    data = resp.json()
    health = [c for c in data["collections"] if c["card_type"] == "HEALTH"][0]
    assert health["collected"] >= 1
    assert health["total"] >= 2


# ==================== Admin Tests ====================

ADMIN_HEADERS = {"X-Admin-Token": "quasar-admin-2024"}


def test_admin_login_success():
    """管理员登录成功。"""
    resp = client.post("/api/admin/login", json={"admin_token": "quasar-admin-2024"})
    assert resp.status_code == 200
    assert resp.json()["success"] is True


def test_admin_login_fail():
    """错误的管理员token被拒绝。"""
    resp = client.post("/api/admin/login", json={"admin_token": "wrong"})
    assert resp.status_code == 403


def test_admin_create_preset_card():
    """管理员创建预设卡牌。"""
    resp = client.post("/api/admin/preset-cards", json={
        "card_type": "HEALTH", "mantra": "测试咒语", "energy_level": 3,
    }, headers=ADMIN_HEADERS)
    assert resp.status_code == 200
    data = resp.json()
    assert data["card_type"] == "HEALTH"
    assert data["energy_level"] == 3


def test_admin_list_preset_cards():
    """管理员查看预设卡牌列表。"""
    _create_preset_card("HEALTH", 1, "咒语A")
    resp = client.get("/api/admin/preset-cards", headers=ADMIN_HEADERS)
    assert resp.status_code == 200
    assert resp.json()["total"] >= 1


def test_admin_send_announcement():
    """管理员发送公告。"""
    _create_user("alice")
    _create_user("bob")
    resp = client.post("/api/admin/announcements", json={
        "title": "维护通知", "content": "系统将于今晚升级"
    }, headers=ADMIN_HEADERS)
    assert resp.status_code == 200
    assert resp.json()["success"] is True

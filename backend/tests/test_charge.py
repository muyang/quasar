import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import get_db
from app.main import app
from app.models import EnergyStone, Base

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
    """为每个测试创建全新表结构。"""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


_counter = 0


def _create_stone(**kwargs) -> EnergyStone:
    db = TestingSessionLocal()
    global _counter
    _counter += 1
    stone = EnergyStone(
        unique_code=kwargs.get("unique_code", f"CRY-TEST{_counter:06d}"),
        stone_type=kwargs.get("stone_type", "HEALTH"),
        owner_id=kwargs.get("owner_id", None),
        current_energy=kwargs.get("current_energy", 10),
        death_count=kwargs.get("death_count", 0),
        status=kwargs.get("status", "ALIVE"),
        consecutive_days=kwargs.get("consecutive_days", 0),
        last_charge_time=kwargs.get("last_charge_time"),
        last_check_in_date=kwargs.get("last_check_in_date"),
    )
    db.add(stone)
    db.commit()
    db.refresh(stone)
    db.close()
    return stone


def test_charge_alive_stone():
    """正常存活石头的充能。"""
    stone = _create_stone(current_energy=50)
    resp = client.post(f"/api/stone/{stone.id}/charge")
    assert resp.status_code == 200
    data = resp.json()
    assert data["stone_id"] == stone.id
    assert data["energy_before"] == 50
    assert data["status"] == "ALIVE"
    assert data["blessing"]


def test_charge_caps_at_100():
    """充能后能量不超过上限 100。"""
    stone = _create_stone(current_energy=98)
    resp = client.post(f"/api/stone/{stone.id}/charge")
    assert resp.status_code == 200
    data = resp.json()
    assert data["energy_after"] <= 100


def test_charge_dead_stone_rejected():
    """已枯竭的石头不能充能。"""
    stone = _create_stone(status="DEAD", current_energy=0)
    resp = client.post(f"/api/stone/{stone.id}/charge")
    assert resp.status_code == 400
    assert "枯竭" in resp.json()["detail"]


def test_charge_nonexistent_stone():
    """不存在的石头返回 404。"""
    resp = client.post("/api/stone/99999/charge")
    assert resp.status_code == 404


def test_charge_updates_last_charge_time():
    """充能后 last_charge_time 被更新。"""
    stone = _create_stone(last_charge_time=None)
    resp = client.post(f"/api/stone/{stone.id}/charge")
    assert resp.status_code == 200
    assert resp.json()["stone_id"] == stone.id

    # 从数据库确认
    db = TestingSessionLocal()
    updated = db.query(EnergyStone).filter(EnergyStone.id == stone.id).first()
    assert updated.last_charge_time is not None
    db.close()


def test_charge_weighted_random_distribution():
    """多次充能验证基础增量分布——全部在 1~5 之间。"""
    for _ in range(50):
        stone = _create_stone(current_energy=10)
        resp = client.post(f"/api/stone/{stone.id}/charge")
        assert resp.status_code == 200
        data = resp.json()
        # 基础能量值在 1-5 之间
        assert 1 <= data["base_gain"] <= 5


def test_consecutive_days_multiplier():
    """测试连续打卡倍数。"""
    # 第1天，倍数应为1
    stone = _create_stone(consecutive_days=0, last_check_in_date=None)
    resp = client.post(f"/api/stone/{stone.id}/charge")
    assert resp.status_code == 200
    data = resp.json()
    assert data["consecutive_days"] == 1
    assert data["multiplier"] == 1

    # 第2天，倍数应为2
    from datetime import datetime, timezone, timedelta
    yesterday = (datetime.now(timezone.utc) - timedelta(days=1)).strftime("%Y-%m-%d")
    stone2 = _create_stone(consecutive_days=1, last_check_in_date=yesterday)
    resp2 = client.post(f"/api/stone/{stone2.id}/charge")
    assert resp2.status_code == 200
    data2 = resp2.json()
    assert data2["consecutive_days"] == 2
    assert data2["multiplier"] == 2
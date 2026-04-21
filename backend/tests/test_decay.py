import pytest
from datetime import datetime, timezone, timedelta

from app.database import get_db
from app.decay import run_daily_decay
from app.main import app
from app.models import EnergyStone, Base

from tests.test_charge import (
    TestingSessionLocal,
    override_get_db,
    client,
    _create_stone,
    setup_database,  # noqa: F401
)


def _charge_and_get_today_stone(**kwargs) -> EnergyStone:
    """创建一颗石头并充能，使其 last_charge_time 为今天 UTC。"""
    stone = _create_stone(**kwargs)
    resp = client.post(f"/api/stone/{stone.id}/charge")
    assert resp.status_code == 200
    db = TestingSessionLocal()
    fresh = db.query(EnergyStone).filter(EnergyStone.id == stone.id).first()
    db.close()
    return fresh


def _run_decay():
    db = TestingSessionLocal()
    run_daily_decay(db)
    db.close()


def test_decay_no_charge_today():
    """当天未充能的石头应衰减 3 点。"""
    stone = _create_stone(current_energy=50, last_charge_time=None)
    _run_decay()

    db = TestingSessionLocal()
    updated = db.query(EnergyStone).filter(EnergyStone.id == stone.id).first()
    assert updated.current_energy == 47
    db.close()


def test_no_decay_if_charged_today():
    """当天已充能的石头不应衰减。"""
    stone = _charge_and_get_today_stone(current_energy=50)
    initial_energy = stone.current_energy
    _run_decay()

    db = TestingSessionLocal()
    updated = db.query(EnergyStone).filter(EnergyStone.id == stone.id).first()
    assert updated.current_energy == initial_energy
    db.close()


def test_death_reset_when_energy_drops_to_zero():
    """能量耗尽后 death_count 增加，若 < 3 则重置为 5。"""
    stone = _create_stone(current_energy=2, last_charge_time=None)
    _run_decay()

    db = TestingSessionLocal()
    updated = db.query(EnergyStone).filter(EnergyStone.id == stone.id).first()
    assert updated.death_count == 1
    assert updated.current_energy == 5  # 保留火种
    assert updated.status == "ALIVE"
    db.close()


def test_final_death_when_death_count_reaches_3():
    """death_count >= 3 时石头死亡，能量清零。"""
    stone = _create_stone(
        current_energy=2, last_charge_time=None, death_count=2
    )
    _run_decay()

    db = TestingSessionLocal()
    updated = db.query(EnergyStone).filter(EnergyStone.id == stone.id).first()
    assert updated.status == "DEAD"
    assert updated.current_energy == 0
    assert updated.death_count == 3
    db.close()


def test_dead_stone_skipped_by_decay():
    """已死亡的石头不应被衰减任务处理。"""
    stone = _create_stone(
        current_energy=0, status="DEAD", death_count=3, last_charge_time=None
    )
    _run_decay()

    db = TestingSessionLocal()
    updated = db.query(EnergyStone).filter(EnergyStone.id == stone.id).first()
    assert updated.status == "DEAD"
    assert updated.current_energy == 0
    db.close()


def test_decay_old_timestamp_not_today():
    """last_charge_time 是昨天或更早的石头应衰减。"""
    yesterday = (datetime.now(timezone.utc) - timedelta(days=1)).isoformat()
    stone = _create_stone(current_energy=30, last_charge_time=yesterday)
    _run_decay()

    db = TestingSessionLocal()
    updated = db.query(EnergyStone).filter(EnergyStone.id == stone.id).first()
    assert updated.current_energy == 27
    db.close()


def test_decay_multiple_stones_in_one_run():
    """多颗石头同时衰减，各自独立计算。"""
    stone_a = _create_stone(current_energy=10, last_charge_time=None)
    stone_b = _create_stone(current_energy=3, last_charge_time=None)
    stone_c = _charge_and_get_today_stone(current_energy=50)
    initial_energy = stone_c.current_energy

    _run_decay()

    db = TestingSessionLocal()
    a = db.query(EnergyStone).filter(EnergyStone.id == stone_a.id).first()
    b = db.query(EnergyStone).filter(EnergyStone.id == stone_b.id).first()
    c = db.query(EnergyStone).filter(EnergyStone.id == stone_c.id).first()

    # a: 10 - 3 = 7 (alive, death_count 0)
    assert a.current_energy == 7
    assert a.death_count == 0
    assert a.status == "ALIVE"

    # b: 3 - 3 = 0 -> death_count=1, reset to 5
    assert b.death_count == 1
    assert b.current_energy == 5
    assert b.status == "ALIVE"

    # c: charged today, no decay (use actual energy after charge)
    assert c.current_energy == initial_energy
    assert c.death_count == 0

    db.close()

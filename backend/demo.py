#!/usr/bin/env python3
"""演示能量石 API 功能"""
import httpx
import time

BASE_URL = "http://localhost:8000"

def create_stone_via_db():
    """直接通过数据库创建石头"""
    import sys
    sys.path.insert(0, '/Users/mac/Repos/quasar/backend')
    from app.database import SessionLocal
    from app.models import EnergyStone

    db = SessionLocal()
    # 清理旧数据
    db.query(EnergyStone).delete()
    db.commit()

    stone = EnergyStone(
        user_id=1,
        current_energy=10,
        death_count=0,
        status="ALIVE",
        last_charge_time=None
    )
    db.add(stone)
    db.commit()
    db.refresh(stone)
    stone_id = stone.id
    db.close()
    return stone_id

def charge_stone(stone_id: int):
    """调用充能 API"""
    resp = httpx.post(f"{BASE_URL}/api/stone/{stone_id}/charge")
    if resp.status_code == 200:
        data = resp.json()
        print(f"\n{'='*50}")
        print(f"  ✨ 充能成功!")
        print(f"{'='*50}")
        print(f"  石头 ID: {data['stone_id']}")
        print(f"  能量变化: {data['energy_before']} → {data['energy_after']}")
        print(f"  本次增量: +{data['energy_gained']}")
        print(f"  当前状态: {data['status']}")
        print(f"\n  💬 祝福语:")
        print(f"  「{data['blessing']}」")
        print(f"{'='*50}\n")
        return data
    else:
        print(f"充能失败: {resp.json()}")
        return None

def main():
    print("\n🌟 能量石 API 演示\n")
    print("正在创建新石头...")
    stone_id = create_stone_via_db()
    print(f"石头创建成功，ID: {stone_id}\n")

    print("开始模拟充能（3次）...\n")
    for i in range(3):
        print(f"--- 第 {i+1} 次充能 ---")
        charge_stone(stone_id)
        time.sleep(0.5)

    print("\n演示完成!\n")

if __name__ == "__main__":
    main()
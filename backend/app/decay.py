import logging
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models import EnergyStone

logger = logging.getLogger(__name__)

ENERGY_CAP = 100
DECAY_AMOUNT = 3
RESET_ENERGY = 5
MAX_DEATH_COUNT = 3


def _today_in_last_charge(stone: EnergyStone) -> bool:
    """判断石头的 last_charge_time 是否在 UTC 今天。"""
    if not stone.last_charge_time:
        return False
    try:
        charge_dt = datetime.fromisoformat(stone.last_charge_time)
        now = datetime.now(timezone.utc)
        return (
            charge_dt.year == now.year
            and charge_dt.month == now.month
            and charge_dt.day == now.day
        )
    except (ValueError, TypeError):
        return False


def run_daily_decay(db: Session = None):
    """
    每日零点定时任务：
    - 扫描所有 ALIVE 状态的石头
    - 若当天未充能，则扣除 DECAY_AMOUNT 点能量
    - 若扣除后能量 <= 0，death_count + 1
      - death_count < 3：能量重置为 RESET_ENERGY
      - death_count >= 3：状态变为 DEAD，能量清零
    """
    logger.info("[Decay] 开始执行每日衰减任务")
    if db is None:
        db: Session = SessionLocal()
        should_close = True
    else:
        should_close = False
    try:
        alive_stones = db.query(EnergyStone).filter(
            EnergyStone.status == "ALIVE"
        ).all()
        logger.info(f"[Decay] 共扫描到 {len(alive_stones)} 颗存活石头")

        decayed_count = 0
        for stone in alive_stones:
            if _today_in_last_charge(stone):
                logger.info(
                    f"[Decay] 石头 {stone.id} 今日已充能，跳过衰减"
                )
                continue

            stone.current_energy -= DECAY_AMOUNT
            decayed_count += 1
            logger.info(
                f"[Decay] 石头 {stone.id} 未充能，能量 {stone.current_energy + DECAY_AMOUNT} -> {stone.current_energy}"
            )

            # 死亡判定
            if stone.current_energy <= 0:
                stone.death_count += 1
                logger.info(
                    f"[Decay] 石头 {stone.id} 能量耗尽，枯竭次数 +1 -> {stone.death_count}"
                )

                if stone.death_count < MAX_DEATH_COUNT:
                    stone.current_energy = RESET_ENERGY
                    logger.info(
                        f"[Decay] 石头 {stone.id} 保留火种，能量重置为 {RESET_ENERGY}"
                    )
                else:
                    stone.status = "DEAD"
                    stone.current_energy = 0
                    logger.warning(
                        f"[Decay] 石头 {stone.id} 达到最大枯竭次数 ({MAX_DEATH_COUNT})，已死亡"
                    )

        db.commit()
        logger.info(
            f"[Decay] 衰减任务完成，共衰减 {decayed_count} 颗石头"
        )
    except Exception:
        db.rollback()
        logger.exception("[Decay] 衰减任务执行失败，已回滚")
        raise
    finally:
        if should_close:
            db.close()

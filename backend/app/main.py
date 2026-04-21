import logging

from fastapi import FastAPI
from apscheduler.schedulers.asyncio import AsyncIOScheduler

from app.api.stone import router as stone_router
from app.database import engine
from app.models import Base
from app.decay import run_daily_decay

logger = logging.getLogger(__name__)

# 创建数据库表
Base.metadata.create_all(bind=engine)

app = FastAPI(title="能量石 Energy Stone API", version="0.1.0")

app.include_router(stone_router)

# 定时任务调度器：每日凌晨 00:00 执行衰减逻辑
scheduler = AsyncIOScheduler()
scheduler.add_job(
    run_daily_decay,
    trigger="cron",
    hour=0,
    minute=0,
    id="daily_decay",
    replace_existing=True,
)


@app.on_event("startup")
def start_scheduler():
    scheduler.start()
    logger.info("[Scheduler] 每日衰减定时任务已启动 (00:00 UTC)")


@app.on_event("shutdown")
def shutdown_scheduler():
    scheduler.shutdown()
    logger.info("[Scheduler] 定时任务调度器已关闭")


@app.get("/health")
def health_check():
    return {"status": "ok"}

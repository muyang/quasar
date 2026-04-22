import logging
import random

from fastapi import FastAPI
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy.orm import Session

from app.api.stone import router as stone_router
from app.database import engine, SessionLocal
from app.models import Base, PresetCard
from app.decay import run_daily_decay

logger = logging.getLogger(__name__)

# 咒语库（用于生成预设卡牌）
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

# 创建数据库表
Base.metadata.create_all(bind=engine)

app = FastAPI(title="能量石 Energy Stone API", version="0.3.0")

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


def _init_preset_cards():
    """初始化365张预设卡牌池。"""
    db: Session = SessionLocal()
    try:
        # 检查是否已初始化
        existing_count = db.query(PresetCard).count()
        if existing_count >= 365:
            logger.info(f"[Init] 预设卡牌池已存在，共{existing_count}张")
            return

        logger.info("[Init] 开始生成预设卡牌池...")

        # 能量等级分布权重：低级别多，高级别少
        level_weights = {1: 40, 2: 30, 3: 20, 4: 8, 5: 2}

        # 5种类型各生成73张
        cards_to_create = []
        card_types = ["HEALTH", "LOVE", "WEALTH", "CAREER", "FAMILY"]

        for card_type in card_types:
            mantras = MANTRAS.get(card_type, MANTRAS["HEALTH"])
            for i in range(73):
                # 按权重随机选择能量等级
                level = random.choices(
                    list(level_weights.keys()),
                    weights=list(level_weights.values()),
                    k=1
                )[0]

                # 随机选择咒语
                mantra = random.choice(mantras)

                cards_to_create.append(PresetCard(
                    card_type=card_type,
                    mantra=mantra,
                    energy_level=level
                ))

        db.add_all(cards_to_create)
        db.commit()
        logger.info(f"[Init] 预设卡牌池生成完成，共{len(cards_to_create)}张")

    except Exception as e:
        logger.error(f"[Init] 预设卡牌池生成失败: {e}")
        db.rollback()
    finally:
        db.close()


@app.on_event("startup")
def startup():
    """启动时初始化预设卡牌池和定时任务。"""
    _init_preset_cards()
    scheduler.start()
    logger.info("[Scheduler] 每日衰减定时任务已启动 (00:00 UTC)")


@app.on_event("shutdown")
def shutdown_scheduler():
    scheduler.shutdown()
    logger.info("[Scheduler] 定时任务调度器已关闭")


@app.get("/health")
def health_check():
    return {"status": "ok", "version": "0.3.0"}

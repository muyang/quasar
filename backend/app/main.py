import logging
import random
from datetime import datetime, timezone

from fastapi import FastAPI, Depends
from fastapi.staticfiles import StaticFiles
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy.orm import Session

from app.api.stone import router as stone_router
from app.api.admin import router as admin_router
from app.admin_pages import router as admin_pages_router
from app.database import engine, SessionLocal, get_db
from app.models import Base, PresetCard, User, EnergyStone, CardArchetype
from app.decay import run_daily_decay
from app.migrate_v060 import run_migration_v060

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

# v0.6.0 迁移：添加新列和新表
run_migration_v060()

app = FastAPI(title="能量石 Energy Stone API", version="0.6.0")

app.include_router(stone_router)
app.include_router(admin_router)
app.include_router(admin_pages_router)

# 静态文件服务（上传的卡牌图片等）
app.mount("/static", StaticFiles(directory="static"), name="static")

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


def _seed_archetypes():
    """从 archetype_data.py 导入原型到 card_archetypes 表。"""
    import json
    from app.archetype_data import ARCHETYPES
    db: Session = SessionLocal()
    try:
        existing = db.query(CardArchetype).count()
        if existing >= 65:
            logger.info(f"[Init] 卡牌原型已存在，共{existing}个")
            return

        logger.info("[Init] 开始导入卡牌原型数据...")
        count = 0
        for faction, archetypes in ARCHETYPES.items():
            for arch in archetypes:
                aid = arch["archetype_id"]
                # 检查是否已存在
                if db.query(CardArchetype).filter(CardArchetype.archetype_id == aid).first():
                    continue
                a = CardArchetype(
                    archetype_id=aid,
                    faction=arch["faction"],
                    rarity=arch["rarity"],
                    card_type=arch["card_type"],
                    name_templates_json=json.dumps(arch["name_templates"], ensure_ascii=False),
                    base_cost=arch.get("base_cost", 1),
                    base_stats_json=json.dumps(arch.get("base_stats"), ensure_ascii=False) if arch.get("base_stats") else None,
                    base_effects_json=json.dumps(arch.get("base_effects"), ensure_ascii=False),
                    lore_template=arch.get("lore_template"),
                    tags_json=json.dumps(arch.get("tags", []), ensure_ascii=False),
                )
                db.add(a)
                count += 1
        db.commit()
        logger.info(f"[Init] 卡牌原型导入完成，共{count}个")
    except Exception as e:
        logger.error(f"[Init] 导入原型失败: {e}")
        db.rollback()
    finally:
        db.close()


def _init_preset_cards():
    """初始化365张预设卡牌池。"""
    from app.card_service import generate_preset_pool
    db: Session = SessionLocal()
    try:
        # 检查是否已初始化
        existing_count = db.query(PresetCard).count()
        if existing_count >= 365:
            logger.info(f"[Init] 预设卡牌池已存在，共{existing_count}张")
            return

        logger.info("[Init] 开始生成预设卡牌池...")
        count = generate_preset_pool(db)
        logger.info(f"[Init] 预设卡牌池生成完成，共{count}张")

    except Exception as e:
        logger.error(f"[Init] 预设卡牌池生成失败: {e}")
        db.rollback()
    finally:
        db.close()


def _seed_admin():
    """确保至少存在一个管理员用户。"""
    db: Session = SessionLocal()
    try:
        admin = db.query(User).filter(User.is_admin == True).first()
        if not admin:
            admin_user = User(
                nickname="管理员",
                is_admin=True,
                created_at=datetime.now(timezone.utc).isoformat(),
            )
            db.add(admin_user)
            db.commit()
            db.refresh(admin_user)
            logger.info(f"[Init] 已创建默认管理员用户 (id={admin_user.id})")
    except Exception as e:
        logger.error(f"[Init] 创建管理员失败: {e}")
        db.rollback()
    finally:
        db.close()


def _seed_test_data():
    """创建测试用户和水晶，方便开发测试。"""
    db: Session = SessionLocal()
    try:
        # 检查是否已有普通用户（非管理员）
        regular_count = db.query(User).filter(User.is_admin == False).count()
        if regular_count >= 3:
            logger.info(f"[Init] 测试用户已存在，共{regular_count}位")
            return

        logger.info("[Init] 开始创建测试数据...")
        now = datetime.now(timezone.utc).isoformat()

        test_users = [
            User(nickname="测试用户A", is_admin=False, created_at=now),
            User(nickname="测试用户B", is_admin=False, created_at=now),
            User(nickname="测试用户C", is_admin=False, created_at=now),
        ]
        db.add_all(test_users)
        db.commit()
        for u in test_users:
            db.refresh(u)

        stone_types = ["HEALTH", "LOVE", "WEALTH", "CAREER", "FAMILY"]
        stone_idx = 0
        for user in test_users:
            for st in stone_types:
                stone_idx += 1
                stone = EnergyStone(
                    unique_code=f"TST-{stone_idx:06d}",
                    stone_type=st,
                    owner_id=user.id,
                    current_energy=50,
                    status="ALIVE",
                    consecutive_days=0,
                )
                db.add(stone)
        db.commit()

        logger.info(f"[Init] 测试数据创建完成: {len(test_users)}位用户, {stone_idx}颗水晶")
        for u in test_users:
            logger.info(f"[Init]   用户: id={u.id}, nickname={u.nickname}")
        stones = db.query(EnergyStone).filter(EnergyStone.unique_code.like("TST-%")).order_by(EnergyStone.id).all()
        for s in stones:
            logger.info(f"[Init]   水晶: {s.unique_code} (id={s.id}, type={s.stone_type}, owner={s.owner_id})")
    except Exception as e:
        logger.error(f"[Init] 创建测试数据失败: {e}")
        db.rollback()
    finally:
        db.close()


@app.on_event("startup")
def startup():
    """启动时初始化预设卡牌池和管理员。"""
    _seed_archetypes()
    _init_preset_cards()
    _seed_admin()
    _seed_test_data()
    scheduler.start()
    logger.info("[Scheduler] 每日衰减定时任务已启动 (00:00 UTC)")


@app.on_event("shutdown")
def shutdown_scheduler():
    scheduler.shutdown()
    logger.info("[Scheduler] 定时任务调度器已关闭")


@app.get("/health")
def health_check():
    return {"status": "ok", "version": "0.6.0"}


@app.get("/")
def root():
    return {
        "app": "能量石 Energy Stone API",
        "version": "0.6.0",
        "docs": "/docs",
        "health": "/health",
    }


@app.get("/api/test-data")
def test_data(db: Session = Depends(get_db)):
    """返回测试数据：用户列表和水晶编号。"""
    users = db.query(User).order_by(User.id).all()
    stones = db.query(EnergyStone).order_by(EnergyStone.id).all()
    return {
        "users": [
            {
                "id": u.id,
                "nickname": u.nickname,
                "is_admin": u.is_admin,
                "created_at": u.created_at,
            }
            for u in users
        ],
        "total_users": len(users),
        "stones": [
            {
                "id": s.id,
                "unique_code": s.unique_code,
                "stone_type": s.stone_type,
                "owner_id": s.owner_id,
                "current_energy": s.current_energy,
                "status": s.status,
                "death_count": s.death_count,
            }
            for s in stones
        ],
        "total_stones": len(stones),
    }

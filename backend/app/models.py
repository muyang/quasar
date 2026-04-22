from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    nickname = Column(String, nullable=False)
    created_at = Column(String, nullable=False)


class EnergyStone(Base):
    __tablename__ = "energy_stones"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    unique_code = Column(String, unique=True, nullable=False)  # 石头唯一编号 如 CRY-000001
    stone_type = Column(String, nullable=False)  # 类型: HEALTH/LOVE/WEALTH/CAREER/FAMILY
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # 绑定的主人ID
    current_energy = Column(Integer, nullable=False, default=10)
    death_count = Column(Integer, nullable=False, default=0)
    status = Column(String, nullable=False, default="ALIVE")
    consecutive_days = Column(Integer, nullable=False, default=0)  # 连续打卡天数
    last_charge_time = Column(String, nullable=True)
    last_check_in_date = Column(String, nullable=True)  # 上次打卡日期 YYYY-MM-DD


class CheckInRecord(Base):
    __tablename__ = "check_in_records"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    stone_id = Column(Integer, ForeignKey("energy_stones.id"), nullable=False, index=True)
    check_in_date = Column(String, nullable=False)  # YYYY-MM-DD 格式
    energy_before = Column(Integer, nullable=False)
    energy_after = Column(Integer, nullable=False)
    energy_gained = Column(Integer, nullable=False)  # 实际获得的能量值
    base_gain = Column(Integer, nullable=False)  # 基础能量值（1-5）
    multiplier = Column(Integer, nullable=False)  # 倍数
    consecutive_days = Column(Integer, nullable=False)  # 当时的连续天数
    blessing = Column(String, nullable=False)
    created_at = Column(String, nullable=False)


class TransferRecord(Base):
    __tablename__ = "transfer_records"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    from_stone_id = Column(Integer, ForeignKey("energy_stones.id"), nullable=False, index=True)
    to_stone_id = Column(Integer, ForeignKey("energy_stones.id"), nullable=False, index=True)
    energy_amount = Column(Integer, nullable=False)
    created_at = Column(String, nullable=False)


class PresetCard(Base):
    """预设卡牌池（365张卡牌）"""
    __tablename__ = "preset_cards"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    card_type = Column(String, nullable=False)  # HEALTH/LOVE/WEALTH/CAREER/FAMILY
    mantra = Column(String, nullable=False)  # 咒语（圣经/佛经/名人名言）
    energy_level = Column(Integer, nullable=False)  # 能量等级: 1-5


class Card(Base):
    """用户持有的卡牌"""
    __tablename__ = "cards"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    preset_card_id = Column(Integer, ForeignKey("preset_cards.id"), nullable=False)  # 关联预设卡牌
    card_type = Column(String, nullable=False)  # HEALTH/LOVE/WEALTH/CAREER/FAMILY
    mantra = Column(String, nullable=False)  # 咒语
    energy_level = Column(Integer, nullable=False)  # 能量等级: 1-5
    energy_value = Column(Integer, nullable=False)  # 能量值
    energy_consumed = Column(Integer, nullable=False, default=0)  # 已消耗能量值
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # 所属用户
    gift_status = Column(String, nullable=False, default="NORMAL")  # NORMAL/PENDING/RECEIVED 赠送状态
    gift_from_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # 赠送者ID
    created_at = Column(String, nullable=False)


class UserDrawRecord(Base):
    """用户抽卡记录"""
    __tablename__ = "user_draw_records"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    draw_date = Column(String, nullable=False)  # YYYY-MM-DD
    draw_type = Column(String, nullable=False)  # FREE（打卡免费）/ ENERGY（能量消耗）
    card_id = Column(Integer, ForeignKey("cards.id"), nullable=False)
    created_at = Column(String, nullable=False)
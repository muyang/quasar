from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class EnergyStone(Base):
    __tablename__ = "energy_stones"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, nullable=False, index=True)
    current_energy = Column(Integer, nullable=False, default=10)
    death_count = Column(Integer, nullable=False, default=0)
    status = Column(String, nullable=False, default="ALIVE")
    last_charge_time = Column(String, nullable=True)


class CheckInRecord(Base):
    __tablename__ = "check_in_records"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    stone_id = Column(Integer, ForeignKey("energy_stones.id"), nullable=False, index=True)
    check_in_date = Column(String, nullable=False)  # YYYY-MM-DD 格式
    energy_before = Column(Integer, nullable=False)
    energy_after = Column(Integer, nullable=False)
    blessing = Column(String, nullable=False)
    created_at = Column(String, nullable=False)

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import desc
from sqlalchemy.orm import Session
import models, schemas
from models import WeeklySchedule
from schemas import WeeklyScheduleCreate
from database import get_db

router = APIRouter(prefix="/schedules", tags=["schedules"])

@router.get("/")
def get_schedules(db: Session = Depends(get_db)):
    return db.query(WeeklySchedule).order_by(desc(WeeklySchedule.start_datetime)).all()

@router.post("/")
def create_schedule(data: WeeklyScheduleCreate, db: Session = Depends(get_db)):
    schedule = WeeklySchedule(
        start_datetime=data.start_datetime,
        location=data.location,
        content=data.content,
        participants=data.participants,
        chairperson=data.chairperson,
        status=data.status
    )
    db.add(schedule)
    db.commit()
    db.refresh(schedule)
    return schedule

@router.put("/{schedule_id}")
def update_schedule(schedule_id: int, data: schemas.WeeklyScheduleBase, db: Session = Depends(get_db)):
    cv = db.query(models.WeeklySchedule).filter(models.WeeklySchedule.schedule_id == schedule_id).first()
    if not cv:
        raise HTTPException(status_code=404, detail="Công văn đi không tồn tại")

    # Cập nhật các field có giá trị mới
    update_data = data.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(cv, key, value)

    db.commit()
    db.refresh(cv)
    return cv

@router.delete("/{id}")
def delete_schedule(id: int, db: Session = Depends(get_db)):
    schedule = db.query(WeeklySchedule).filter(WeeklySchedule.schedule_id == id).first()
    if not schedule:
        raise HTTPException(status_code=404, detail="Lịch tuần không tồn tại")
    db.delete(schedule)
    db.commit()
    return {"message": "Xóa lịch tuần thành công"}
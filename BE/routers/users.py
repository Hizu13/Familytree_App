from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from db.mysql_connection import get_db
import models, schemas
from models import User
from passlib.context import CryptContext

router = APIRouter(prefix="/user", tags=["users"])

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# Lấy tất cả users
@router.get("/")
def get_users(db: Session = Depends(get_db)):
    users = db.query(User).all()
    # Ẩn mật khẩu
    return [
        {
            "user_id": u.id,
            "username": u.username,
            "first_name": u.first_name,
            "last_name": u.last_name,
            "email": u.email,
            "role": u.role,
        }
        for u in users
    ]


# Lấy user theo id
@router.get("/{user_id}")
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Người dùng không tồn tại")
    return {
        "user_id": user.id,
        "username": user.username,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "email": user.email,
        "role": user.role
    }


# Tạo user mới (hash mật khẩu trước khi lưu)
@router.post("/")
def create_user(data: schemas.UserCreate, db: Session = Depends(get_db)):
    # Kiểm tra username đã tồn tại chưa
    if db.query(User).filter(User.username == data.username).first():
        raise HTTPException(status_code=400, detail="Username already registered")
    
    # Tạo user mới
    user = models.User(
        username=data.username,
        password_hash=pwd_context.hash(data.password),
        first_name=data.first_name,
        last_name=data.last_name,
        gender=data.gender,
        date_of_birth=data.date_of_birth,
        place_of_birth=data.place_of_birth,
        email=data.email,
        role=data.role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return {
        "id": user.id,
        "username": user.username,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "email": user.email,
        "role": user.role,
    }

# Cập nhật user
@router.put("/{user_id}")
def update_user(user_id: int, data: schemas.UserUpdate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Người dùng không tồn tại")

    # Nếu có password mới thì hash lại
    if data.password:
        user.password_hash = pwd_context.hash(data.password)

    # Cập nhật các field khác (chỉ update nếu gửi lên)
    if data.username:
        user.username = data.username
    if data.first_name:
        user.first_name = data.first_name
    if data.last_name:
        user.last_name = data.last_name
    if data.email:
        user.email = data.email
    if data.role:
        user.role = data.role


    db.commit()
    db.refresh(user)

    return {
        "user_id": user.id,
        "username": user.username,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "email": user.email,
        "role": user.role
    }
# xóa user
 
@router.delete("/{id}")
def delete_user(id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Người dùng không tồn tại")

    db.delete(user)
    db.commit()
    return {"message": "Xóa người dùng thành công"}
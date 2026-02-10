from fastapi import APIRouter, Depends, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from db.mysql_connection import get_db
from models import User
from pydantic import BaseModel
from typing import Optional
from itsdangerous import URLSafeTimedSerializer, BadSignature, SignatureExpired
from passlib.context import CryptContext
from fastapi import FastAPI
from dependencies import get_current_user

# =====================
# ⚙️ Cấu hình
# =====================
SECRET_KEY = "your-secret-key"  # Nên lưu trong file .env
SESSION_EXPIRE_SECONDS = 3600   # 1 giờ
serializer = URLSafeTimedSerializer(SECRET_KEY)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

router = APIRouter(prefix="/auth", tags=["auth"])


# =====================
# 📘 Schema
# =====================
class LoginRequest(BaseModel):
    username: str
    password: str


# =====================
# 🔐 Middleware gia hạn session
# =====================
def setup_session_middleware(app: FastAPI):
    @app.middleware("http")
    async def refresh_session_if_valid(request: Request, call_next):
        response = await call_next(request)
        token = request.cookies.get("user_session")
        if token:
            try:
                data = serializer.loads(token, max_age=SESSION_EXPIRE_SECONDS)
                # Reset thời gian sống cookie (gia hạn khi người dùng thao tác)
                new_token = serializer.dumps(
                    {"user_id": data["user_id"], "role": data["role"]}
                )
                response.set_cookie(
                    key="user_session",
                    value=new_token,
                    httponly=True,
                    max_age=SESSION_EXPIRE_SECONDS,
                    samesite="lax",
                    secure=False,  # Bật True nếu dùng HTTPS
                    path="/"
                )
            except (BadSignature, SignatureExpired):
                pass
        return response


# =====================
# 🧭 Helper kiểm tra quyền
# =====================
def require_roles(allowed_roles: list[str]):
    """Decorator kiểm tra quyền từ cookie session."""
    def wrapper(request: Request, db: Session = Depends(get_db)):
        token = request.cookies.get("user_session")
        if not token:
            raise HTTPException(status_code=401, detail="Chưa đăng nhập")

        try:
            data = serializer.loads(token, max_age=SESSION_EXPIRE_SECONDS)
            user = db.query(User).filter(User.id == data["user_id"]).first()
            if not user or user.role not in allowed_roles:
                raise HTTPException(status_code=403, detail="Không có quyền truy cập")
            return user
        except SignatureExpired:
            raise HTTPException(status_code=401, detail="Phiên đăng nhập đã hết hạn")
        except BadSignature:
            raise HTTPException(status_code=401, detail="Phiên không hợp lệ")
    return wrapper


# =====================
# 🔑 Đăng nhập
# =====================
@router.post("/login")
def login(data: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == data.username).first()
    if not user or not pwd_context.verify(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Sai tên đăng nhập hoặc mật khẩu")

    token = serializer.dumps({"user_id": user.id, "role": user.role})
    response = JSONResponse(content={
        "message": "Đăng nhập thành công",
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "user_id": user.id,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "role": user.role
        }
    })
    # Keep cookie for backward compatibility or web browser convenience if needed, 
    # but user asked for token based. We can keep both for robustness.
    response.set_cookie(
        key="user_session",
        value=token,
        httponly=True,
        max_age=SESSION_EXPIRE_SECONDS,
        samesite="lax",
        secure=False,
        path="/"
    )
    return response


# =====================
# 👤 Lấy thông tin người dùng hiện tại
# =====================
@router.get("/me")
def get_me(current_user: User = Depends(get_current_user)):
    return {
        "user_id": current_user.id,
        "username": current_user.username,
        "first_name": current_user.first_name,
        "last_name": current_user.last_name,
        "gender": current_user.gender,
        "date_of_birth": str(current_user.date_of_birth) if current_user.date_of_birth else None,
        "place_of_birth": current_user.place_of_birth,
        "role": current_user.role,
        "email": current_user.email,
        "cccd": current_user.cccd,
    }


# =====================
# 👤 Cập nhật thông tin user
# =====================

class ProfileUpdateRequest(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    gender: Optional[str] = None
    date_of_birth: Optional[str] = None
    place_of_birth: Optional[str] = None
    email: Optional[str] = None
    cccd: Optional[str] = None # Added

@router.put("/profile")
def update_profile(data: ProfileUpdateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user = current_user
    
    # Update fields
    if data.first_name is not None:
        user.first_name = data.first_name
    if data.last_name is not None:
        user.last_name = data.last_name
    if data.gender is not None:
        user.gender = data.gender
    if data.date_of_birth is not None:
        from datetime import datetime
        try:
            # Handle YYYY-MM-DD
            user.date_of_birth = datetime.strptime(data.date_of_birth, "%Y-%m-%d").date()
        except:
            pass
    if data.place_of_birth is not None:
        user.place_of_birth = data.place_of_birth
    if data.email is not None:
        user.email = data.email
    if data.cccd is not None:
        user.cccd = data.cccd
        
    db.commit()
    db.refresh(user)
    
    return {
        "user_id": user.id,
        "username": user.username,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "gender": user.gender,
        "date_of_birth": str(user.date_of_birth) if user.date_of_birth else None,
        "place_of_birth": user.place_of_birth,
        "role": user.role,
        "email": user.email,
        "cccd": user.cccd,
    }


# =====================
# 🚪 Đăng xuất
# =====================
@router.post("/logout")
def logout(response: Response):
    response = JSONResponse(content={"message": "Đã đăng xuất"})
    # Xóa triệt để bằng cách set max_age=0, expires=0 và value rỗng
    response.set_cookie(
        key="user_session",
        value="",
        httponly=True,
        max_age=0,
        expires=0,
        samesite="lax",
        secure=False,
        path="/"
    )
    return response

from fastapi import Depends, HTTPException, Request
from sqlalchemy.orm import Session
from db.mysql_connection import get_db
from models import User
from itsdangerous import URLSafeTimedSerializer, BadSignature, SignatureExpired

# Should be in config
SECRET_KEY = "your-secret-key"
SESSION_EXPIRE_SECONDS = 3600
serializer = URLSafeTimedSerializer(SECRET_KEY)

def get_current_user(request: Request, db: Session = Depends(get_db)):
    token = None
    
    # 1. Check Authorization Header (Prioritize)
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ")[1]
    
    # 2. Fallback to Cookie
    if not token:
        token = request.cookies.get("user_session")

    if not token:
        raise HTTPException(status_code=401, detail="Chưa đăng nhập")

    try:
        data = serializer.loads(token, max_age=SESSION_EXPIRE_SECONDS)
        user = db.query(User).filter(User.id == data["user_id"]).first()
        if not user:
            raise HTTPException(status_code=401, detail="Người dùng không tồn tại")
        return user
    except SignatureExpired:
        raise HTTPException(status_code=401, detail="Phiên đã hết hạn")
    except BadSignature:
        raise HTTPException(status_code=401, detail="Phiên không hợp lệ")

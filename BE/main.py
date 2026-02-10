from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import auth
from db.mysql_connection import Base, engine
from db.neo4j_connection import Neo4jConnection
from models import Family, Person
from sqlalchemy import text
from fastapi.staticfiles import StaticFiles # <--- Import
from routers import members
from routers import tree
from routers import users
from routers import families
from routers import maintenance
from routers import upload # <--- Import
from routers import chat # <--- Import

app = FastAPI(title="Family Management Backend")

# Mount Static Files
import os
os.makedirs("static", exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

# Trigger reload for DB table recreation

# Kích hoạt middleware gia hạn session
auth.setup_session_middleware(app)

app.include_router(members.router)
app.include_router(tree.router)
app.include_router(users.router)
app.include_router(auth.router)
app.include_router(families.router)
app.include_router(maintenance.router)
app.include_router(upload.router) # <--- Include
app.include_router(chat.router) # <--- Include

# ====== 1️⃣ TẠO BẢNG MYSQL (NẾU CÓ) ======
Base.metadata.create_all(bind=engine)

# ====== 2️⃣ KHỞI TẠO KẾT NỐI NEO4J ======
neo4j_conn = Neo4jConnection()

# ====== 3️⃣ CẤU HÌNH CORS ======
origins = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost",
    "http://127.0.0.1",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ====== 4️⃣ HÀM KIỂM TRA KẾT NỐI MYSQL ======
def check_mysql_connection():
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True, "✅ MySQL connected successfully"
    except Exception as e:
        return False, f"❌ MySQL connection failed: {e}"

# ====== 5️⃣ HÀM KIỂM TRA KẾT NỐI NEO4J ======
def check_neo4j_connection():
    try:
        result = neo4j_conn.query("RETURN 'OK' AS status")
        if result and result[0]["status"] == "OK":
            return True, "✅ Neo4j connected successfully"
        else:
            return False, "⚠️ Neo4j returned unexpected result"
    except Exception as e:
        return False, f"❌ Neo4j connection failed: {e}"

# ====== 6️⃣ API GỐC (TRẢ VỀ TÌNH TRẠNG CẢ HAI DB) ======
@app.get("/")
def root():
    mysql_ok, mysql_msg = check_mysql_connection()
    neo4j_ok, neo4j_msg = check_neo4j_connection()

    all_ok = mysql_ok and neo4j_ok

    return {
        "status": "✅ All systems operational" if all_ok else "⚠️ Some connections failed",
        "mysql": mysql_msg,
        "neo4j": neo4j_msg,
    }


from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
from db.mysql_connection import get_db
from models import Family, Person, User
from schemas import PersonRead, FamilyRead, FamilyCreate, FamilyUpdate, JoinFamilyRequest, UpdateMemberRoleRequest
from fastapi import Request
from itsdangerous import URLSafeTimedSerializer, BadSignature, SignatureExpired
from dependencies import get_current_user
import uuid
# Import Helper Sync Neo4j
from db.neo4j_connection import add_person_to_graph

# Should be in config
SECRET_KEY = "your-secret-key"
serializer = URLSafeTimedSerializer(SECRET_KEY)

router = APIRouter(prefix="/families", tags=["families"])

# API 1: Lấy danh sách gia phả
@router.get("/", response_model=List[FamilyRead])
def get_families(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    print(f"[DEBUG] GET /families/ - current_user.id: {current_user.id}, username: {current_user.username}")
    
    # 1. Lấy gia phả do user sở hữu (Creator)
    owned_families = db.query(Family).filter(Family.owner_id == current_user.id).all()
    
    # 2. Lấy gia phả mà user là thành viên (Member)
    member_families = db.query(Family).join(Person, Person.family_id == Family.id).filter(
        Person.user_id == current_user.id
    ).all()
    
    # 3. Gộp lại và loại bỏ trùng lặp (nếu user vừa là owner vừa là member - dù logic tạo set owner nhưng join set member)
    all_families = list({f.id: f for f in (owned_families + member_families)}.values())
    
    print(f"[DEBUG] Found {len(all_families)} families (Owned: {len(owned_families)}, Joined: {len(member_families)})")
    return all_families

# API 2: Tạo gia phả mới
@router.post("/", response_model=FamilyRead)
def create_family(family: FamilyCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # 1. Tạo Gia phả
    # Generate unique join code (6 chars)
    join_code = str(uuid.uuid4())[:6].upper()
    
    new_family = Family(
        name=family.name, 
        description=family.description,
        origin_location=family.origin_location,
        join_code=join_code,
        owner_id=current_user.id
    )
    db.add(new_family)
    db.commit()
    db.refresh(new_family)
    
    
    # 2. Tạo Person đại diện cho User: ROLE = ADMIN
    new_person = Person(
        family_id=new_family.id,
        user_id=current_user.id, # Link User ID
        first_name=current_user.first_name or "",
        last_name=current_user.last_name or "",
        gender=current_user.gender or 'male', # Lấy từ user hoặc mặc định
        role='admin' # NGƯỜI TẠO LÀ ADMIN
    )
    try:
        db.add(new_person)
        db.commit()
        
        # --- SYNC NEO4J ---
        full_name = f"{new_person.last_name} {new_person.first_name}".strip()
        add_person_to_graph(
            id=new_person.id, 
            full_name=full_name,
            gender=new_person.gender,
            family_id=new_family.id
        )
    except Exception as e:
        print(f"Không thể tạo Person cho User: {e}")
        pass

    return new_family

# API 2.5: Tham gia gia phả (Join Family)
@router.post("/join", response_model=FamilyRead)
def join_family(request: JoinFamilyRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    try:
        # 1. Tìm gia phả theo join_code
        print(f"[DEBUG] Joining family with code: {request.join_code}")
        family = db.query(Family).filter(Family.join_code == request.join_code).first()
        if not family:
            raise HTTPException(status_code=404, detail="Mã tham gia không hợp lệ")

        # Check đã là thành viên chưa (theo user_id)
        existing_member = db.query(Person).filter(
            Person.user_id == current_user.id,
            Person.family_id == family.id
        ).first()
        
        if existing_member:
            raise HTTPException(status_code=400, detail="Bạn đã là thành viên của gia phả này")
            
        # --- SYNC LOGIC: Check if Person with same CCCD exists ---
        matched_person = None
        if current_user.cccd:
             matched_person = db.query(Person).filter(
                 Person.family_id == family.id,
                 Person.cccd == current_user.cccd
             ).first()
             
        if matched_person:
            # If person exists but has no user attached -> LINK THEM
            if matched_person.user_id is None:
                print(f"[SYNC] Found matching Person (ID: {matched_person.id}) for User {current_user.username} via CCCD {current_user.cccd}")
                matched_person.user_id = current_user.id
                # Optional: Update details if missing
                if not matched_person.first_name and current_user.first_name:
                    matched_person.first_name = current_user.first_name
                if not matched_person.last_name and current_user.last_name:
                    matched_person.last_name = current_user.last_name
                if not matched_person.avatar_url: 
                    # Use placeholder or no-op
                    pass 
                
                db.commit()
                db.refresh(matched_person)
                return family
            else:
                # Matched person already has account? 
                # Case 1: user_id == current_user.id (Already handled by existing_member check above)
                # Case 2: user_id != current_user.id (Duplicate CCCD usage?)
                if matched_person.user_id != current_user.id:
                     print(f"[WARNING] CCCD {current_user.cccd} is claimed by another user for Person {matched_person.id}")
                     # Decide: Fail or Create duplicate? Create duplicate for safety but warn.
                     pass 

        # Thêm thành viên mới: ROLE = MEMBER
        new_person = Person(
            family_id=family.id,
            user_id=current_user.id, # Link User ID
            cccd=current_user.cccd, # Save CCCD to Person too if available
            first_name=current_user.first_name or "",
            last_name=current_user.last_name or "",
            gender=current_user.gender or 'male', # Lấy từ user hoặc mặc định
            role='member' 
        )
        db.add(new_person)
        db.commit()
        db.refresh(new_person) # Refresh to get the ID
        
        # --- SYNC NEO4J ---
        try:
            full_name = f"{new_person.last_name} {new_person.first_name}".strip()
            add_person_to_graph(
                id=new_person.id, 
                full_name=full_name,
                gender=new_person.gender,
                family_id=family.id
            )
        except Exception as neo_e:
             print(f"Neo4j Sync Error: {neo_e}")

        return family
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"❌ Error joining family: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Internal Error: {str(e)}")

# API 3: Cập nhật gia phả
@router.put("/{family_id}", response_model=FamilyRead)
def update_family(family_id: int, family_update: FamilyUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Gia phả không tồn tại")
    
    # Kiểm tra quyền: Thành viên + Admin
    member = db.query(Person).filter(
        Person.user_id == current_user.id, 
        Person.family_id == family_id
    ).first()
    

    
    if not member:
        raise HTTPException(status_code=403, detail="Không có quyền truy cập")

    if member.role != 'admin':
        raise HTTPException(status_code=403, detail="Bạn cần quyền quản trị viên của gia phả để chỉnh sửa")
    
    if family_update.name is not None:
        family.name = family_update.name
    if family_update.description is not None:
        family.description = family_update.description
    if family_update.origin_location is not None:
        family.origin_location = family_update.origin_location
        
    db.commit()
    db.refresh(family)
    return family

# API 4: Xóa gia phả
@router.delete("/{family_id}")
def delete_family(family_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    family = db.query(Family).filter(Family.id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Gia phả không tồn tại")
    
    member = db.query(Person).filter(
        Person.user_id == current_user.id, 
        Person.family_id == family_id
    ).first()


    
    if not member or member.role != 'admin':
        raise HTTPException(status_code=403, detail="Cần quyền admin (Trưởng tộc) để xóa gia phả")
    
    db.delete(family)
    db.commit()
    return {"message": "Xóa gia phả thành công"}

# API 5: Lấy thông tin thành viên của User hiện tại
@router.get("/{family_id}/me", response_model=PersonRead)
def get_current_member_in_family(family_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    person = db.query(Person).filter(
        Person.user_id == current_user.id,
        Person.family_id == family_id
    ).first()


    
    if not person:
        raise HTTPException(status_code=404, detail="Bạn không có trong gia phả này")
        
    family = db.query(Family).filter(Family.id == family_id).first()
    if family and family.owner_id == current_user.id:
        if person.role != 'admin':
            person.role = 'admin'
            db.commit()
            db.refresh(person)
            
    return person

# API 6: Quản lý role thành viên (Chỉ Admin)
@router.put("/{family_id}/members/{member_id}/role")
def update_member_role(
    family_id: int, 
    member_id: int, 
    request: UpdateMemberRoleRequest, 
    db: Session = Depends(get_db), 
    current_user: User = Depends(get_current_user)
):
    # 1. Check quyền người gọi (Admin)
    admin_member = db.query(Person).filter(
        Person.user_id == current_user.id, 
        Person.family_id == family_id
    ).first()
    

    
    if not admin_member or admin_member.role != 'admin':
        raise HTTPException(status_code=403, detail="Chỉ Admin mới có quyền phân quyền")

    # 2. Check member target
    target_member = db.query(Person).filter(Person.id == member_id, Person.family_id == family_id).first()
    if not target_member:
        raise HTTPException(status_code=404, detail="Thành viên không tồn tại")

    # 3. Update role
    # Không cho phép set thành admin (vì chỉ có 1 admin) -> Muốn chuyển admin phải dùng API khác (future)
    if request.role not in ['editor', 'member']:
         raise HTTPException(status_code=400, detail="Quyền không hợp lệ (chỉ editor hoặc member)")
         
    target_member.role = request.role
    db.commit()
    
    return {"message": "Cập nhật quyền thành công", "new_role": request.role}
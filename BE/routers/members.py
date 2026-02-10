# routers/members.py
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Request
from sqlalchemy.orm import Session
from db.mysql_connection import SessionLocal
from models import Person, Relationship
from schemas import PersonCreate, PersonRead
from typing import List, Optional
import pandas as pd
import io
from datetime import datetime

router = APIRouter(prefix="/members", tags=["Members"])


# ----- Dependency -----
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


from dependencies import get_current_user
from models import User

# ... import User model to type hint ...

# Helper check quyền
def verify_family_access(db: Session, user: User, family_id: int):
    # 1. Admin hệ thống có quyền xem mọi thứ
    if user.role == "admin":
        return True
    
    # 2. Kiểm tra xem user có phải là một Person trong gia phả này không (qua user_id)
    is_member = db.query(Person).filter(
        Person.user_id == user.id, 
        Person.family_id == family_id
    ).first()
    
    # 3. Fallback: Kiểm tra qua CCCD (nếu user có CCCD và chưa được link qua user_id)
    if not is_member and hasattr(user, 'cccd') and user.cccd:
        is_member = db.query(Person).filter(
            Person.cccd == user.cccd, 
            Person.family_id == family_id
        ).first()
    
    if not is_member:
        # HACK: Nếu gia phả chưa có thành viên nào (vừa tạo), cho phép truy cập để Import
        member_count = db.query(Person).filter(Person.family_id == family_id).count()
        if member_count == 0:
            return True
            
        raise HTTPException(status_code=403, detail="Bạn không có quyền truy cập vào gia phả này")
    return is_member

def verify_editor_access(db: Session, user: User, family_id: int):
    # Check if user is Admin/Editor in the family
    member = db.query(Person).filter(
        Person.user_id == user.id, 
        Person.family_id == family_id
    ).first()
    
    if not member:
         raise HTTPException(status_code=403, detail="Bạn không phải thành viên gia phả")
         
    if member.role not in ['admin', 'editor']:
         raise HTTPException(status_code=403, detail="Chỉ Admin hoặc Editor mới có quyền thực hiện")
    return member

from db.neo4j_connection import add_person_to_graph, create_relationship_in_graph, delete_person_from_graph

# ----- Thêm thành viên -----
@router.post("/", response_model=PersonRead)
def create_member(person: PersonCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Verify access to family_id
    # Verify access to family_id
    verify_editor_access(db, current_user, person.family_id)
    
    # Store child links for post-processing
    is_father_of = person.is_father_of_id
    is_mother_of = person.is_mother_of_id
    
    # Create the person
    person_data = person.dict(exclude={'is_father_of_id', 'is_mother_of_id', 'spouse_id'})
    db_person = Person(**person_data)
    db.add(db_person)
    db.commit()
    db.refresh(db_person)
    
    # Link to child if specified
    if is_father_of:
        child = db.query(Person).filter(Person.id == is_father_of).first()
        if child:
            child.father_id = db_person.id
            db.commit()
            
            # Sync to Relationship table with Vietnamese types
            try:
                # 1. (Father, Child) -> Bố
                exists = db.query(Relationship).filter(Relationship.person1_id == db_person.id, Relationship.person2_id == child.id).first()
                if not exists:
                    db.add(Relationship(person1_id=db_person.id, person2_id=child.id, type="bố"))
                
                # 2. (Child, Father) -> Con
                exists_rev = db.query(Relationship).filter(Relationship.person1_id == child.id, Relationship.person2_id == db_person.id).first()
                if not exists_rev:
                    child_role = "con trai" if child.gender == 'male' else "con gái"
                    db.add(Relationship(person1_id=child.id, person2_id=db_person.id, type=child_role))
                
                db.commit()
            except Exception as e:
                print(f"Error syncing relationship (Father): {e}")

            # Also sync to Neo4j
            try:
                create_relationship_in_graph(db_person.id, child.id, "FATHER_OF")
            except: pass

    if is_mother_of:
        child = db.query(Person).filter(Person.id == is_mother_of).first()
        if child:
            child.mother_id = db_person.id
            db.commit()

            # Sync to Relationship table with Vietnamese types
            try:
                # 1. (Mother, Child) -> Mẹ
                exists = db.query(Relationship).filter(Relationship.person1_id == db_person.id, Relationship.person2_id == child.id).first()
                if not exists:
                    db.add(Relationship(person1_id=db_person.id, person2_id=child.id, type="mẹ"))
                
                # 2. (Child, Mother) -> Con
                exists_rev = db.query(Relationship).filter(Relationship.person1_id == child.id, Relationship.person2_id == db_person.id).first()
                if not exists_rev:
                    child_role = "con trai" if child.gender == 'male' else "con gái"
                    db.add(Relationship(person1_id=child.id, person2_id=db_person.id, type=child_role))
                
                db.commit()
            except Exception as e:
                print(f"Error syncing relationship (Mother): {e}")

            # Also sync to Neo4j
            try:
                create_relationship_in_graph(db_person.id, child.id, "MOTHER_OF")
            except: pass

    # Link to Spouse if specified
    if person.spouse_id:
        spouse = db.query(Person).filter(Person.id == person.spouse_id).first()
        if spouse:
            try:
                # Determine roles based on gender
                # db_person (New) -> Spouse (Existing)
                role_1_to_2 = "chồng" if db_person.gender == 'male' else "vợ"
                
                # Spouse (Existing) -> db_person (New)
                role_2_to_1 = "chồng" if spouse.gender == 'male' else "vợ"

                # 1. DB Relationship
                exists = db.query(Relationship).filter(
                    Relationship.person1_id == db_person.id, 
                    Relationship.person2_id == spouse.id
                ).first()
                
                if not exists:
                    db.add(Relationship(person1_id=db_person.id, person2_id=spouse.id, type=role_1_to_2))
                    db.add(Relationship(person1_id=spouse.id, person2_id=db_person.id, type=role_2_to_1))
                    db.commit()

                # 2. Neo4j Sync
                create_relationship_in_graph(db_person.id, spouse.id, "SPOUSE")
                create_relationship_in_graph(spouse.id, db_person.id, "SPOUSE") 
            except Exception as e:
                print(f"Error linking spouse: {e}")
    
    # --- Sync Siblings (Anh/Chị/Em) ---
    # Find siblings based on Father/Mother ID
    siblings = set()
    if db_person.father_id:
        p_sibs = db.query(Person).filter(Person.father_id == db_person.father_id, Person.id != db_person.id).all()
        siblings.update(p_sibs)
    if db_person.mother_id:
        m_sibs = db.query(Person).filter(Person.mother_id == db_person.mother_id, Person.id != db_person.id).all()
        siblings.update(m_sibs)
    
    for sib in siblings:
        try:
            # Determine relationship type
            # Check full status
            is_full = (sib.father_id == db_person.father_id) and (sib.mother_id == db_person.mother_id)
            suffix = " ruột" if is_full else ""
            
            # Compare Age (DOB)
            # Default: db_person is younger (since just created?) -> sibling is older
            # Better: check DOB
            am_i_older = False
            if db_person.date_of_birth and sib.date_of_birth:
                am_i_older = db_person.date_of_birth < sib.date_of_birth
            else:
                # Fallback: ID check (lower ID usually older)
                am_i_older = db_person.id < sib.id
            
            # Relation 1: Me (P1) -> Sib (P2) ("Tôi là gì của Sib?")
            if am_i_older:
                my_role = "anh" if db_person.gender == 'male' else "chị"
                if suffix: my_role += suffix
            else:
                my_role = "em"
                if suffix: my_role += suffix
                if db_person.gender == 'male': my_role += " trai"
                else: my_role += " gái"

            # Relation 2: Sib (P1) -> Me (P2) ("Sib là gì của Tôi?")
            if not am_i_older: # Sib is older
                sib_role = "anh" if sib.gender == 'male' else "chị"
                if suffix: sib_role += suffix
            else: # Sib is younger
                sib_role = "em"
                if suffix: sib_role += suffix
                if sib.gender == 'male': sib_role += " trai"
                else: sib_role += " gái"
            
            # Add to DB
            exists1 = db.query(Relationship).filter(Relationship.person1_id == db_person.id, Relationship.person2_id == sib.id).first()
            if not exists1:
                db.add(Relationship(person1_id=db_person.id, person2_id=sib.id, type=my_role))
                
            exists2 = db.query(Relationship).filter(Relationship.person1_id == sib.id, Relationship.person2_id == db_person.id).first()
            if not exists2:
                db.add(Relationship(person1_id=sib.id, person2_id=db_person.id, type=sib_role))
            
            db.commit()

            # Neo4j Sibling
            try:
                create_relationship_in_graph(db_person.id, sib.id, "SIBLING")
                create_relationship_in_graph(sib.id, db_person.id, "SIBLING")
            except: pass
            
        except Exception as ex:
            print(f"Error syncing sibling {sib.id}: {ex}")
    
    # --- End Sibling Sync ---

    # --- Sync self to Neo4j ---
    try:
        full_name = f"{db_person.last_name} {db_person.first_name}".strip()
        add_person_to_graph(
            id=db_person.id,
            full_name=full_name,
            gender=db_person.gender,
            family_id=db_person.family_id,
            father_id=db_person.father_id,
            mother_id=db_person.mother_id
        )
    except Exception as e:
        print(f"Neo4j Sync Error (create_member): {e}")
        
    return db_person


# ----- Lấy danh sách Vợ/Chồng của thành viên -----
@router.get("/member/{member_id}/spouses", response_model=List[PersonRead])
def get_member_spouses(member_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Lấy danh sách vợ/chồng của một thành viên"""
    member = db.query(Person).filter(Person.id == member_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    
    verify_family_access(db, current_user, member.family_id)
    
    # Tìm tất cả quan hệ vợ/chồng từ bảng Relationship
    spouse_relationships = db.query(Relationship).filter(
        Relationship.person1_id == member_id,
        Relationship.type.in_(['vợ', 'chồng'])
    ).all()
    
    # Lấy thông tin chi tiết của các vợ/chồng
    spouses = []
    for rel in spouse_relationships:
        spouse = db.query(Person).filter(Person.id == rel.person2_id).first()
        if spouse:
            spouses.append(spouse)
    
    return spouses


# ----- Lấy danh sách thành viên theo Family -----
@router.get("/{family_id}", response_model=List[PersonRead])
def get_members_by_family(family_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    verify_family_access(db, current_user, family_id)
    members = db.query(Person).filter(Person.family_id == family_id).all()
    return members


from schemas import TreeResponse, TreeNode, TreeEdge

# ----- Lấy dữ liệu Sơ đồ cây (GraphView) -----
@router.get("/{family_id}/tree", response_model=TreeResponse)
def get_family_tree(family_id: int, request: Request, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """API trả về Nodes và Edges để vẽ cây gia phả (Query từ Neo4j)."""
    # 1. Fetch Graph from Neo4j
    from db.neo4j_connection import get_family_graph
    
    graph_data = get_family_graph(family_id)
    
    nodes = []
    edges = []
    
    # Query SQL for reliable Spouse data and Avatars
    spouse_map = {}
    avatar_map = {}
    try:
        node_ids = [n['id'] for n in graph_data['nodes']]
        if node_ids:
            # 1. Spouses
            sp_rels = db.query(Relationship).filter(
                Relationship.type.in_(['vợ', 'chồng']),
                Relationship.person1_id.in_(node_ids)
            ).all()
            
            for r in sp_rels:
                p1, p2 = r.person1_id, r.person2_id
                if p1 not in spouse_map: spouse_map[p1] = []
                if p2 not in spouse_map[p1]: spouse_map[p1].append(p2)
            
            # 2. Avatars & DOB & Birth Year (Fetch Persons via IN clause)
            persons = db.query(Person).filter(Person.id.in_(node_ids)).all()
            base_url = str(request.base_url).rstrip('/')
            dob_map = {}
            birth_year_map = {}
            for p in persons:
                if p.avatar_url:
                    # Fix URL if relative
                    url = p.avatar_url
                    if url.startswith("/"):
                        url = f"{base_url}{url}"
                    avatar_map[p.id] = url
                
                # Capture DOB
                if p.date_of_birth:
                    dob_map[p.id] = p.date_of_birth.strftime("%d/%m/%Y")
                    # Extract birth year from date_of_birth
                    birth_year_map[p.id] = str(p.date_of_birth.year)
                
    except Exception as e:
        print(f"Error fetching extra data from SQL: {e}")

    for n in graph_data['nodes']:
        nodes.append(TreeNode(
            id=n['id'],
            name=n['name'],
            gender=n['gender'] or 'male',
            birth_year=birth_year_map.get(n['id'], n.get('birth_year', '?')),
            dob=dob_map.get(n['id']),
            avatar_url=avatar_map.get(n['id']),
            father_id=n.get('father_id'),
            mother_id=n.get('mother_id'),
            spouses=spouse_map.get(n['id'], [])
        ))
        
    for e in graph_data['edges']:
        # Map Neo4j edge type to our Edge type
        # Neo4j: (Father)-[:PARENT_OF]->(Child)
        # TreeEdge expects from -> to.
        # But our TreeView (GraphView) expects directional edges.
        # Logic in members.py before: Father->Child. PARENT_OF is Father->Child. So it matches.
        
        # We need to distinguish Father/Mother.
        # But Neo4j edge is just PARENT_OF. We check Gender of From Node?
        # GraphData edges: {from, to, type}.
        # We can look up gender from nodes list.
        
        # Build map
        node_gender_map = {n['id']: n['gender'] for n in graph_data['nodes']}
        parent_gender = node_gender_map.get(e['from_id'], 'male')
        
        edge_type = 'FATHER_OF' if parent_gender == 'male' else 'MOTHER_OF'
        
        edges.append(TreeEdge(from_id=e['from_id'], to_id=e['to_id'], type=edge_type))
            
    return TreeResponse(nodes=nodes, edges=edges)


# ----- Cập nhật thành viên -----
@router.put("/{member_id}", response_model=PersonRead)
def update_member(member_id: int, person_update: PersonCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_person = db.query(Person).filter(Person.id == member_id).first()
    if not db_person:
        raise HTTPException(status_code=404, detail="Member not found")
    
    verify_family_access(db, current_user, db_person.family_id)
    
    update_data = person_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(db_person, key, value)
    

    db.commit()
    db.refresh(db_person)
    
    # --- SYNC NEO4J (Update Info) ---
    try:
        full_name = f"{db_person.last_name} {db_person.first_name}".strip()
        add_person_to_graph(
            id=db_person.id,
            full_name=full_name,
            gender=db_person.gender,
            family_id=db_person.family_id
            # Note: Not syncing parents here to avoid duplicating edges if changed. 
            # Parent changes should be handled via specific relationship logic if needed.
        )
    except Exception as e:
        print(f"Neo4j Update Error: {e}")

    return db_person


# ----- Xóa thành viên -----
@router.delete("/{member_id}")
def delete_member(member_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_person = db.query(Person).filter(Person.id == member_id).first()
    if not db_person:
        raise HTTPException(status_code=404, detail="Member not found")
    
    verify_family_access(db, current_user, db_person.family_id)
    
    # 1. Delete from MySQL
    try:
        # 1a. Delete all relationships involving this person (to avoid foreign key constraint)
        db.query(Relationship).filter(
            (Relationship.person1_id == member_id) | (Relationship.person2_id == member_id)
        ).delete(synchronize_session=False)
        
        # 1b. Delete the person
        db.delete(db_person)
        db.commit()
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi xóa dữ liệu MySQL: {e}")

    # 2. Sync Delete from Neo4j
    try:
        print(f"[DELETE] Attempting to delete person {member_id} from Neo4j...")
        delete_person_from_graph(member_id)
        print(f"[DELETE] ✅ Successfully deleted person {member_id} from Neo4j")
    except Exception as e:
        print(f"[DELETE] ❌ Neo4j Delete Error for person {member_id}: {e}")
        import traceback
        traceback.print_exc()
        # Không raise lỗi vì MySQL đã xóa thành công, chỉ log lại warning
    
    return {"message": "Member deleted successfully"}


# ----- IMPORT THÀNH VIÊN TỪ EXCEL -----
@router.post("/import")
async def import_members(
    family_id: int = Form(...),
    anchor_id: Optional[int] = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_family_access(db, current_user, family_id)
    
    try:
        contents = await file.read()
# ... (rest of import function)
        df = pd.read_excel(io.BytesIO(contents))
        
        # Chuẩn hóa cột header (lowercase, strip)
        df.columns = [str(c).lower().strip() for c in df.columns]
        print(f"DEBUG: Detected columns: {df.columns.tolist()}")
        
        # Helper tìm cột gần đúng
        def find_col(aliases):
            for alias in aliases:
                if alias in df.columns:
                    return alias
            return None

        # Maps to store Excel ID -> DB ID
        # Key: ID from Excel (or row index if no ID)
        # Value: Database ID of created Person
        id_map = {} 
        
        # Detect ID columns
        col_id = find_col(['id', 'stt', 'no', 'member_id'])
        col_father = find_col(['father_id', 'fatherid', 'id_bo', 'id_cha', 'ma_bo', 'ma_cha'])
        col_mother = find_col(['mother_id', 'motherid', 'id_me', 'id_ma', 'ma_me', 'ma_ma'])
        
        # --- PASS 1: CREATE MEMBERS ---
        persons_to_update = [] # List of (db_person, excel_row) for Pass 2
        created_count = 0

        for idx, row in df.iterrows():
            # ... (Name extraction logic remains) ...
            
            def get_val(aliases):
                col = find_col(aliases)
                if col and not pd.isna(row[col]):
                    return str(row[col]).strip()
                return None
            
            # --- Tên ---
            first_name = get_val(['tên', 'first name', 'firstname', 'ten', 'first_name', 'tên gọi'])
            last_name = get_val(['họ', 'last name', 'lastname', 'ho', 'last_name', 'họ đệm'])
            full_name = get_val(['họ và tên', 'full name', 'fullname', 'hovaten', 'họ tên', 'tên đầy đủ', 'name'])

            if not first_name:
                if full_name:
                    parts = full_name.split(' ')
                    if len(parts) > 1:
                        first_name = parts[-1]
                        last_name = " ".join(parts[:-1])
                    else:
                        first_name = full_name
                        last_name = ""
                else:
                    print(f"DEBUG: Row {idx} skipped. Missing Name.")
                    continue 

            # --- Giới tính ---
            gender_raw = get_val(['giới tính', 'gender', 'gioitinh'])
            gender = 'male' # Default
            if gender_raw:
                s = gender_raw.lower()
                if s in ['nữ', 'female', 'gái', 'f']:
                    gender = 'female'
                elif s in ['khác', 'other', 'o']:
                    gender = 'other'

            # --- Ngày sinh ---
            dob_col = find_col(['ngày sinh', 'date of birth', 'dob', 'ngaysinh', 'date_of_birth'])
            dob_str = None
            if dob_col:
                dob_raw = row[dob_col]
                if pd.notna(dob_raw):
                    try:
                        # Dùng pandas to_datetime để xử lý các định dạng ngày tháng thông minh
                        # dayfirst=True ưu tiên DD/MM/YYYY (phổ biến ở VN)
                        dt = pd.to_datetime(dob_raw, dayfirst=True, errors='coerce')
                        if not pd.isna(dt):
                            dob_str = dt.strftime('%Y-%m-%d')
                    except Exception as e:
                        print(f"DEBUG: Date parse error row {idx}: {e}")

            new_person = Person(
                family_id=family_id,
                first_name=first_name,
                last_name=last_name or "",
                gender=gender,
                date_of_birth=dob_str,
                cccd=get_val(['cccd', 'id card', 'id_card']),
                place_of_birth=get_val(['quê quán', 'hometown', 'quequan', 'place_of_birth'])
            )
            
            try:
                db.add(new_person)
                db.flush() 
            except Exception as e:
                db.rollback()
                print(f"DEBUG: Error adding row {idx}: {e}")
                # Nếu lỗi trùng CCCD, có thể bỏ qua hoặc báo lỗi
                if "Duplicate entry" in str(e):
                    print(f"Skipping duplicate CCCD at row {idx}")
                    continue
                else:
                    # Lỗi khác thì throw ra
                    raise e
            
            # Save to map
            # Propagate Excel ID if exists, extracting integer value if possible
            excel_id = idx + 1 # Default to 1-based index
            if col_id and pd.notna(row[col_id]):
                try: 
                    excel_id = int(row[col_id])
                except: 
                    excel_id = str(row[col_id])
            
            id_map[excel_id] = new_person.id
            persons_to_update.append((new_person, row))
            created_count += 1
        
        # --- PASS 2: UPDATE RELATIONSHIPS ---
        
        for person, row in persons_to_update:
            # 1. Check direct father_id/mother_id columns
            f_val = row[col_father] if col_father and pd.notna(row[col_father]) else None
            m_val = row[col_mother] if col_mother and pd.notna(row[col_mother]) else None
            
            if f_val is not None:
                # Try to map from Excel ID -> DB ID
                try: 
                    # Handle both string/int keys
                    # If Excel has mixed types, try flexible matching
                    key_int = int(f_val)
                    if key_int in id_map: 
                        person.father_id = id_map[key_int]
                    elif str(f_val) in id_map:
                         person.father_id = id_map[str(f_val)]
                except: pass
            
            if m_val is not None:
                try: 
                    key_int = int(m_val)
                    if key_int in id_map: 
                        person.mother_id = id_map[key_int]
                    elif str(m_val) in id_map:
                         person.mother_id = id_map[str(m_val)]
                except: pass

            # 2. Existing "Relation to Anchor" logic (Fallback)
            # ... (Keep existing anchor logic optionally)
            
            # Helper for anchor relation
            if anchor_id:
                 # ... (existing logic)
                 # Fetch relation string
                relation_col = find_col(['quan hệ', 'relationship', 'quanhe', 'role'])
                if relation_col and pd.notna(row[relation_col]):
                    rel = str(row[relation_col]).lower()
                    
                    anchor_person = db.query(Person).filter(Person.id == anchor_id).first()
                    if anchor_person:
                         if any(x in rel for x in ['con', 'son', 'daughter', 'child']):
                            if anchor_person.gender == 'male':
                                person.father_id = anchor_person.id
                            else:
                                person.mother_id = anchor_person.id
                                
                         elif rel in ['cha', 'bố', 'father', 'dad']:
                             anchor_person.father_id = person.id
                         elif rel in ['mẹ', 'má', 'mother', 'mom']:
                             anchor_person.mother_id = person.id

        # --- SYNC TO RELATIONSHIP TABLE ---
        sync_errors = []
        try:
            for person, row in persons_to_update:
                try:
                    with db.begin_nested():
                        # Sync Father
                        if person.father_id:
                            exists = db.query(Relationship).filter(
                                Relationship.person1_id == person.id,
                                Relationship.person2_id == person.father_id,
                                Relationship.type == 'bố'
                            ).first()
                            if not exists:
                                db.add(Relationship(
                                    person1_id=person.id, 
                                    person2_id=person.father_id, 
                                    type='bố' 
                                ))
                        
                        # Sync Mother
                        if person.mother_id:
                            exists = db.query(Relationship).filter(
                                Relationship.person1_id == person.id,
                                Relationship.person2_id == person.mother_id,
                                Relationship.type == 'mẹ'
                            ).first()
                            if not exists:
                                db.add(Relationship(
                                    person1_id=person.id, 
                                    person2_id=person.mother_id, 
                                    type='mẹ'
                                ))
                except Exception as inner_e:
                    # Nested rollback happens automatically on exit of context manager if error
                    # print(f"DEBUG: Error syncing row {person.id}: {inner_e}") # Suppress excessive logs
                    sync_errors.append(str(inner_e))
            
            # Commit the main transaction (Persons)
            db.commit()
            
            # --- PASS 3: SYNC TO NEO4J (2-Step approach to avoid race condition) ---
            print("DEBUG: Starting Neo4j Sync (2-Step)...")
            neo4j_errors = []
            
            # Step 1: Create all Person Nodes first
            for person, row in persons_to_update:
                try:
                    full_name = f"{person.last_name} {person.first_name}".strip()
                    # Call with father/mother=None to only create the node
                    add_person_to_graph(
                        id=person.id,
                        full_name=full_name,
                        gender=person.gender,
                        family_id=family_id,
                        father_id=None,
                        mother_id=None
                    )
                except Exception as ex:
                    print(f"Neo4j Node Sync Error (Row {person.id}): {ex}")
                    neo4j_errors.append(f"Node: {ex}")

            # Step 2: Establish all Relationships
            for person, row in persons_to_update:
                try:
                    if person.father_id:
                        create_relationship_in_graph(person.father_id, person.id, "FATHER_OF")
                    if person.mother_id:
                        create_relationship_in_graph(person.mother_id, person.id, "MOTHER_OF")
                except Exception as ex:
                    print(f"Neo4j Rel Sync Error (Row {person.id}): {ex}")
                    neo4j_errors.append(f"Rel: {ex}")
            
        except Exception as e:
            db.rollback() 
            # Check for table missing error again specifically if commit fails
            if "1146" in str(e) or "doesn't exist" in str(e):
                 raise HTTPException(status_code=400, detail="Lỗi: Bảng 'relationships' chưa được tạo. Vui lòng tạo bảng trong Database.")
            
            print(f"DEBUG: Fatal error in commit: {e}")
            raise HTTPException(status_code=400, detail=f"Lỗi lưu dữ liệu: {str(e)}")
        
        if created_count == 0:
            return {"message": f"Success but 0 members created. Detected columns: {df.columns.tolist()}"}

        msg = f"Successfully imported {created_count} members."
        if sync_errors:
            msg += f" Warning: {len(sync_errors)} relationships failed to sync to MySQL."
        if 'neo4j_errors' in locals() and neo4j_errors:
            msg += f" Warning: {len(neo4j_errors)} members failed to sync to Neo4j."
            
        return {"message": msg}


    except Exception as e:
        print(f"Error importing: {e}")
        raise HTTPException(status_code=400, detail=f"Import failed: {str(e)}")


# ----- TÌM KIẾM MỐI QUAN HỆ (NEO4J) -----
from db.neo4j_connection import find_shortest_path

@router.post("/path")
def find_relationship_path(
    data: dict, # {from_id: int, to_id: int}
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    from_id = data.get("from_id")
    to_id = data.get("to_id")
    
    if not from_id or not to_id:
         raise HTTPException(status_code=400, detail="Missing from_id or to_id")
    
    # Verify access to both persons? Or just if they belong to accessible families?
    # Ideally check if user can see both. For simplicity, we trust Neo4j graph context or check family_id
    
    path = find_shortest_path(from_id, to_id)
    if not path:
         return {"relationship": "Không tìm thấy mối quan hệ"}
         
    # Path structure: {'nodes': [{id, name, gender}, ...], 'rels': [{start, end, type}, ...]}
    nodes = path['nodes']
    rels = path['rels']
    
    # --- HÀM TỔNG HỢP QUAN HỆ (MỤC 3 EXPLANATION) ---
    def get_summary_term(nodes, rels):
        n_steps = len(rels)
        
        # Check for SPOUSE relationship (1 step, direct)
        if n_steps == 1 and rels[0]['type'] == 'SPOUSE':
            gender = nodes[0].get('gender')
            is_male = gender in ['male', 'nam']
            return "Chồng" if is_male else "Vợ"
        
        # directions: 1 nếu n[i] là cha/mẹ n[i+1], -1 nếu n[i] là con n[i+1]
        dirs = []
        for i in range(n_steps):
            rel_type = rels[i]['type']
            # Handle SPOUSE separately (neutral direction)
            if rel_type == 'SPOUSE':
                dirs.append(0)  # Neutral for spouse
            elif rels[i]['start'] == nodes[i]['id']:
                dirs.append(1)
            else:
                dirs.append(-1)
        
        
        start_gender = nodes[0].get('gender')
        is_male = start_gender == 'male' or start_gender == 'nam'
        
        # 1. Quan hệ trực hệ đi xuống (Tổ tiên -> Hậu duệ): dirs = [1, 1, ...]
        # Ví dụ: Cha/Mẹ -> Con, Ông/Bà -> Cháu
        # Đây là khi nodes[0] -> nodes[1] theo chiều FATHER_OF hoặc MOTHER_OF
        if all(d == 1 for d in dirs):
            if n_steps == 1:
                # Kiểm tra relationship type để xác định chính xác
                rel_type = rels[0]['type']
                if rel_type == 'FATHER_OF':
                    return "Cha"
                elif rel_type == 'MOTHER_OF':
                    return "Mẹ"
                else:
                    # Fallback to gender check
                    return "Cha" if is_male else "Mẹ"
                    
            if n_steps == 2:
                # Ông/Bà -> Cha/Mẹ -> Cháu
                # Xác định nội/ngoại dựa vào người ở giữa
                mid_gender = nodes[1].get('gender')
                is_paternal_side = (mid_gender == 'male' or mid_gender == 'nam')
                side = "nội" if is_paternal_side else "ngoại"
                
                return f"Ông {side}" if is_male else f"Bà {side}"
                    
            if n_steps == 3: 
                return "Cụ" if is_male else "Cụ (nữ)"
            return f"Tổ tiên ({n_steps} đời)"

        # 2. Quan hệ trực hệ đi lên (Hậu duệ -> Tổ tiên): dirs = [-1, -1, ...]
        # Ví dụ: Con -> Cha/Mẹ, Cháu -> Ông/Bà
        # Đây là khi nodes[0] <- nodes[1] (ngược chiều relationship)
        if all(d == -1 for d in dirs):
            if n_steps == 1: 
                return "Con trai" if is_male else "Con gái"
            if n_steps == 2: 
                return "Cháu trai" if is_male else "Cháu gái"
            if n_steps == 3: 
                return "Chắt"
            return f"Hậu duệ ({n_steps} đời)"

        # 3. Quan hệ ngang (Anh chị em)
        if dirs == [-1, 1]:
            # Need to check birth dates to determine elder vs younger sibling
            # Fetch person data from DB to get birth dates
            try:
                p1 = db.query(Person).filter(Person.id == nodes[0]['id']).first()
                p2 = db.query(Person).filter(Person.id == nodes[-1]['id']).first()
                
                if p1 and p2:
                    # Determine who is older
                    is_older = False
                    if p1.date_of_birth and p2.date_of_birth:
                        is_older = p1.date_of_birth < p2.date_of_birth
                    else:
                        is_older = p1.id < p2.id  # Fallback: lower ID = older
                    
                    gender = nodes[0].get('gender')
                    is_male = gender in ['male', 'nam']
                    
                    if is_older:
                        return "Anh ruột" if is_male else "Chị ruột"
                    else:
                        return "Em trai ruột" if is_male else "Em gái ruột"
            except:
                pass
            return "Anh/Chị/Em"
        
        # 4. Quan hệ Bác/Chú/Cô/Dì (Parent's sibling)
        # nodes[0] is uncle/aunt, nodes[-1] is nephew/niece
        # Pattern: Uncle/Aunt -> GP -> Parent -> Child
        # dirs = [-1, 1, 1]: going up to GP, then down to parent, then down to child
        if n_steps == 3 and dirs == [-1, 1, 1]:
            # This is uncle/aunt relationship (from uncle's perspective)
            # nodes[0] = Uncle/Aunt, nodes[-1] = Nephew/Niece
            # Need to determine the type based on uncle's gender, age relative to parent, and parent's gender
            try:
                uncle_node = nodes[0]
                parent_node = nodes[2]  # Fix: Compare with Sibling (Parent), not GP (nodes[1])  
                
                # Fetch DOB to compare
                uncle = db.query(Person).filter(Person.id == uncle_node['id']).first()
                parent = db.query(Person).filter(Person.id == parent_node['id']).first()
                
                if uncle and parent:
                    # Determine if uncle is older than parent (their sibling)
                    is_uncle_older_than_parent = False
                    if uncle.date_of_birth and parent.date_of_birth:
                        is_uncle_older_than_parent = uncle.date_of_birth < parent.date_of_birth
                    else:
                        is_uncle_older_than_parent = uncle.id < parent.id
                    
                    uncle_gender = uncle_node.get('gender')
                    is_male = uncle_gender in ['male', 'nam']
                    parent_gender = parent_node.get('gender')
                    parent_is_male = parent_gender in ['male', 'nam']
                    
                    # Determine relationship based on parent's side and uncle's age/gender
                    if parent_is_male:
                        # Father's side (bên nội)
                        if is_uncle_older_than_parent:
                            # Older sibling of father = Bác (both male and female)
                            return "Bác"
                        else:
                            # Younger sibling of father
                            if is_male:
                                return "Chú"
                            else:
                                return "Cô"
                    else:
                        # Mother's side (bên ngoại)
                        if is_uncle_older_than_parent:
                             # older sibling of mother
                            return "Bác"
                        else:
                            # Younger sibling of mother
                            if is_male:
                                return "Cậu"
                            else:
                                return "Dì"
            except:
                pass
                
            return "Bác/Chú/Cô/Dì/Cậu"
        
        # 5. Nephew/Niece relationship (reverse of uncle/aunt)
        # nodes[0] is nephew/niece, nodes[-1] is uncle/aunt
        # Pattern: Nephew/Niece -> Parent -> GP -> Uncle/Aunt
        # dirs = [-1, -1, 1] means: going up to parent, up to GP, then across to uncle
        if n_steps == 3 and dirs == [-1, -1, 1]:
            # This is nephew/niece from their perspective looking at uncle
            try:
                nephew_node = nodes[0]  # The person making the query
                nephew = db.query(Person).filter(Person.id == nephew_node['id']).first()
                
                if nephew:
                    nephew_gender = nephew_node.get('gender')
                    is_male = nephew_gender in ['male', 'nam']
                    
                    return "Cháu trai" if is_male else "Cháu gái"
            except:
                pass
            
            return "Cháu"

        # Also handle the reverse direction pattern for uncle/aunt
        # Pattern: Child -> Parent -> GP -> Uncle
        # dirs = [1, 1, -1]
        if n_steps == 3 and dirs == [1, 1, -1]:
            # This is also uncle/aunt but path goes other direction
            try:
                uncle_node = nodes[-1]
                parent_node = nodes[-2]
                
                uncle = db.query(Person).filter(Person.id == uncle_node['id']).first()
                parent = db.query(Person).filter(Person.id == parent_node['id']).first()
                
                print(f"DEBUG Uncle/Aunt: nephew={nodes[0].get('name')}, parent={parent_node.get('name')}, uncle={uncle_node.get('name')}")
                
                if uncle and parent:
                    # Check if uncle and parent are siblings (same father or mother)
                    are_siblings = (
                        (uncle.father_id and parent.father_id and uncle.father_id == parent.father_id) or
                        (uncle.mother_id and parent.mother_id and uncle.mother_id == parent.mother_id)
                    )
                    
                    print(f"DEBUG: are_siblings={are_siblings}, uncle.father_id={uncle.father_id}, parent.father_id={parent.father_id}")
                    
                    if are_siblings:
                        # Direct siblings - use birth date comparison
                        is_uncle_older_than_parent = False
                        if uncle.date_of_birth and parent.date_of_birth:
                            is_uncle_older_than_parent = uncle.date_of_birth < parent.date_of_birth
                        else:
                            is_uncle_older_than_parent = uncle.id < parent.id
                    else:
                        # NOT siblings - they might be cousins
                        # Find relationship between uncle and parent to determine hierarchy
                        print(f"DEBUG: NOT siblings, finding path between uncle {uncle.id} and parent {parent.id}")
                        uncle_parent_path = find_shortest_path(uncle.id, parent.id)
                        
                        if uncle_parent_path:
                            up_nodes = uncle_parent_path['nodes']
                            up_rels = uncle_parent_path['rels']
                            uncle_to_parent_term = get_summary_term(up_nodes, up_rels)
                            
                            print(f"DEBUG: uncle_to_parent_term='{uncle_to_parent_term}'")
                            
                            # If uncle is "Anh họ" of parent -> uncle is older rank
                            # If uncle is "Em họ" of parent -> uncle is younger rank
                            if uncle_to_parent_term and "Anh" in uncle_to_parent_term:
                                is_uncle_older_than_parent = True
                            elif uncle_to_parent_term and "Em" in uncle_to_parent_term:
                                is_uncle_older_than_parent = False
                            else:
                                # Fallback to ID comparison
                                is_uncle_older_than_parent = uncle.id < parent.id
                        else:
                            # No path found, fallback to ID
                            is_uncle_older_than_parent = uncle.id < parent.id
                    
                    uncle_gender = uncle_node.get('gender')
                    is_male = uncle_gender in ['male', 'nam']
                    parent_gender = parent_node.get('gender')
                    parent_is_male = parent_gender in ['male', 'nam']
                    
                    if parent_is_male:
                        # Father's side (bên nội)
                        if is_uncle_older_than_parent:
                            return "Bác"
                        else:
                            if is_male:
                                return "Chú"
                            else:
                                return "Cô"
                    else:
                        # Mother's side (bên ngoại)
                        if is_uncle_older_than_parent:
                            return "Bác"
                        else:
                            if is_male:
                                return "Cậu"
                            else:
                                return "Dì"
            except:
                pass
                
            return "Bác/Chú/Cô/Dì/Cậu"
        
        # 5.4. Extended Uncle/Aunt relationship (5 steps through great-grandparent)
        # Pattern: Child -> Parent -> GP -> GGP -> Uncle's Parent -> Uncle
        # dirs = [-1, -1, -1, 1, 1] (Up, Up, Up, Down, Down)
        if n_steps == 5 and dirs == [-1, -1, -1, 1, 1]:
            try:
                my_gp_node = nodes[2]      # My Grandparent
                uncles_parent_node = nodes[4] # Uncle's Parent (Sibling of My GP)
                uncle_node = nodes[5]      # The Uncle
                parent_node = nodes[1]     # My Parent
                
                my_gp = db.query(Person).filter(Person.id == my_gp_node['id']).first()
                uncles_parent = db.query(Person).filter(Person.id == uncles_parent_node['id']).first()
                uncle = db.query(Person).filter(Person.id == uncle_node['id']).first()
                
                if my_gp and uncles_parent and uncle:
                    # Determine hierarchy between MY GP and UNCLE'S PARENT
                    is_my_gp_older = False
                    if my_gp.date_of_birth and uncles_parent.date_of_birth:
                        is_my_gp_older = my_gp.date_of_birth < uncles_parent.date_of_birth
                    else:
                        # Fallback to ID
                        is_my_gp_older = my_gp.id < uncles_parent.id
                        
                    uncle_gender = uncle_node.get('gender')
                    is_male = uncle_gender in ['male', 'nam']
                    
                    parent_gender = parent_node.get('gender')
                    parent_is_male = parent_gender in ['male', 'nam']
                    
                    if parent_is_male:
                        # Father's side
                        if is_my_gp_older:
                            # My line is older -> Uncle is younger rank -> But I am the Nephew
                            # "Nephew is [REL] of Uncle" -> "Cháu họ"
                            return "Cháu họ"
                        else:
                            return "Cháu họ"
                    else:
                        # Mother's side
                        return "Cháu họ"
            except:
                pass
            return "Cháu họ"
        
        # 5.5. Extended Uncle/Aunt (Reverse) - Uncle looking at Nephew
        # Pattern: Uncle -> Uncle's Parent -> GGP -> GP -> Parent -> Nephew
        # dirs = [-1, -1, 1, 1, 1] (Up, Up, Down, Down, Down)
        if n_steps == 5 and dirs == [-1, -1, 1, 1, 1]:
            try:
                uncle_node = nodes[0]
                uncles_parent_node = nodes[1]
                my_gp_node = nodes[3]
                uncle = db.query(Person).filter(Person.id == uncle_node['id']).first()
                uncles_parent = db.query(Person).filter(Person.id == uncles_parent_node['id']).first()
                my_gp = db.query(Person).filter(Person.id == my_gp_node['id']).first()
                
                if my_gp and uncles_parent and uncle:
                    is_nephew_line_older = False
                    if my_gp.date_of_birth and uncles_parent.date_of_birth:
                        is_nephew_line_older = my_gp.date_of_birth < uncles_parent.date_of_birth
                    else:
                        is_nephew_line_older = my_gp.id < uncles_parent.id

                    uncle_gender = uncle_node.get('gender')
                    is_male = uncle_gender in ['male', 'nam']
                    
                    # Uncle looking at Nephew -> Always "Cháu"
                    # We can specify "Cháu họ" or "Cháu (gọi bằng Chú/Bác)"
                    
                    if is_nephew_line_older:
                        # Liệt (older) -> Uncle is Junior (Chú) -> Uncle is [Chú] of Nephew
                        return "Chú" if is_male else "Cô"
                    else:
                        # Huệ (older) -> Uncle is Senior (Bác) -> Uncle is [Bác] of Nephew
                        
                        # Check Parent Gender (Hồng)
                        parent_node = nodes[4]
                        parent_gender = parent_node.get('gender')
                        parent_is_male = parent_gender in ['male', 'nam']
                        
                        if parent_is_male:
                            return "Bác"
                        else:
                            return "Cậu" if is_male else "Dì"
            except:
                pass
            return "Bác/Chú/Cô/Dì/Cậu"

        # 5.6. Extended Great-Uncle/Great-Nephew (6 steps)
        # Relationship: Grand-Nephew <-> Great-Uncle (Ông họ - Cháu họ)
        
        # Forward: Grand-Nephew -> Great-Uncle (Long -> Hải)
        # Pattern: Child -> Parent -> GP -> GGP -> GGGP -> Uncle's Parent -> Uncle
        # Long -> Hoàng -> Hồng -> Liệt -> Việt -> Huệ -> Hải
        # Up, Up, Up, Up, Down, Down -> [-1, -1, -1, -1, 1, 1]
        if n_steps == 6 and dirs == [-1, -1, -1, -1, 1, 1]:
            # User is Long (Grand-Nephew) looking at Hải (Great-Uncle)
            return "Cháu họ"

        # Reverse: Great-Uncle -> Grand-Nephew (Hải -> Long)
        # Pattern: Uncle -> Uncle's Parent -> GGGP -> GGP -> GP -> Parent -> Child
        # Hải -> Huệ -> Việt -> Liệt -> Hồng -> Hoàng -> Long
        # Up, Up, Down, Down, Down, Down -> [-1, -1, 1, 1, 1, 1]
        if n_steps == 6 and dirs == [-1, -1, 1, 1, 1, 1]:
            # User is Hải (Great-Uncle) looking at Long (Grand-Nephew)
            try:
                # User is nodes[0] (Hải)
                user_node = nodes[0]
                gender = user_node.get('gender')
                is_male = gender in ['male', 'nam']
                return "Ông họ" if is_male else "Bà họ"
            except:
                return "Ông/Bà họ"
        
        # 5.7. 7-step Extended Relationship (First cousin once removed - generation difference)
        # Relationship: Great-Aunt/Uncle <-> Grand-Nephew/Niece (Cô/Bác/Chú họ - Cháu họ)
        
        # Reverse: Great-Aunt/Uncle -> Grand-Nephew (Yến -> Long)
        # Pattern: Yến -> Hải -> Huệ -> Việt -> Liệt -> Hồng -> Hoàng -> Long
        # Up, Up, Up, Down, Down, Down, Down -> [-1, -1, -1, 1, 1, 1, 1]
        if n_steps == 7 and dirs == [-1, -1, -1, 1, 1, 1, 1]:
            # User is Yến (Great-Aunt) looking at Long (Grand-Nephew)
            try:
                # Determine Seniority between Huệ (My GP, Node 2) and Liệt (Target's GGP, Node 4)
                # Yến(0) -> Hải(1) -> Huệ(2) -> Việt(3) -> Liệt(4) -> Hồng(5) -> Hoàng(6) -> Long(7)
                
                my_ancestor_node = nodes[2]   # Huệ
                target_ancestor_node = nodes[4] # Liệt
                user_node = nodes[0] # Yến
                
                my_ancestor = db.query(Person).filter(Person.id == my_ancestor_node['id']).first()
                target_ancestor = db.query(Person).filter(Person.id == target_ancestor_node['id']).first()
                
                if my_ancestor and target_ancestor:
                     is_target_line_older = False
                     if target_ancestor.date_of_birth and my_ancestor.date_of_birth:
                         is_target_line_older = target_ancestor.date_of_birth < my_ancestor.date_of_birth
                     else:
                         is_target_line_older = target_ancestor.id < my_ancestor.id
                     
                     user_gender = user_node.get('gender')
                     is_male = user_gender in ['male', 'nam']
                     
                     if is_target_line_older:
                         # Target line (Liệt) is Older -> I am Junior branch -> Cô/Chú
                         return "Chú họ" if is_male else "Cô họ"
                     else:
                         # I am Senior branch -> Bác
                         return "Bác họ"
            except:
                pass
            return "Họ hàng"

        # Forward: Grand-Nephew -> Great-Aunt/Uncle (Long -> Yến)
        # Pattern: Long -> Hoàng -> Hồng -> Liệt -> Việt -> Huệ -> Hải -> Yến
        # Up, Up, Up, Up, Down, Down, Down -> [-1, -1, -1, -1, 1, 1, 1]
        if n_steps == 7 and dirs == [-1, -1, -1, -1, 1, 1, 1]:
            # User is Long (Grand-Nephew) looking at Yến (Great-Aunt)
            return "Cháu họ"
        # Pattern: Great-Uncle -> GGP -> GP -> Parent -> Great-Nephew
        # dirs = [-1, 1, 1, 1] (from great-uncle down to great-nephew)
        if n_steps == 4 and dirs == [-1, 1, 1, 1]:
            try:
                great_uncle_node = nodes[0]
                ggp_node = nodes[1]  # Great-grandparent
                gp_node = nodes[2]   # Grandparent (sibling of great-uncle)
                parent_node = nodes[3]  # Parent
                
                great_uncle = db.query(Person).filter(Person.id == great_uncle_node['id']).first()
                grandparent = db.query(Person).filter(Person.id == gp_node['id']).first()
                parent = db.query(Person).filter(Person.id == parent_node['id']).first()
                
                if great_uncle and grandparent and parent:
                    # Determine if great-uncle is older than grandparent
                    is_great_uncle_older = False
                    if great_uncle.date_of_birth and grandparent.date_of_birth:
                        is_great_uncle_older = great_uncle.date_of_birth < grandparent.date_of_birth
                    else:
                        is_great_uncle_older = great_uncle.id < grandparent.id
                    
                    great_uncle_gender = great_uncle_node.get('gender')
                    is_male = great_uncle_gender in ['male', 'nam']
                    
                    parent_gender = parent_node.get('gender')
                    parent_is_male = parent_gender in ['male', 'nam']
                    
                    # Determine relationship based on side and age
                    if parent_is_male:
                        # Paternal side (bên nội)
                        return "Ông cố" if is_male else "Bà cố"
                    
                    else:
                        # Maternal side (bên ngoại)
                        return "Ông cố" if is_male else "Bà cố"
                        
            except:
                pass
            
            return "Cụ/Ông cố"
        
        # 5.6. Great-Nephew/Niece relationship (reverse)
        # Pattern: Great-Nephew -> Parent -> GP -> GGP -> Great-Uncle
        # dirs = [-1, -1, -1, 1]
        if n_steps == 4 and dirs == [-1, -1, -1, 1]:
            try:
                great_nephew_node = nodes[0]
                gender = great_nephew_node.get('gender')
                is_male = gender in ['male', 'nam']
                return "Cháu cố"
            except:
                pass
            
            return "Cháu cố"
        
        # 5.7. Great-Great-Uncle/Aunt (5 steps - sibling of great-grandparent)
        # Pattern: GGU -> GGGP -> GGP -> GP -> Parent -> Great-Great-Nephew
        # dirs = [-1, 1, 1, 1, 1]
        if n_steps == 5 and dirs == [-1, 1, 1, 1, 1]:
            try:
                ggu_node = nodes[0]  # Great-great-uncle
                gggp_node = nodes[1]  # Great-great-great-grandparent
                ggp_node = nodes[2]   # Great-great-grandparent (sibling of GGU)
                
                ggu = db.query(Person).filter(Person.id == ggu_node['id']).first()
                ggp = db.query(Person).filter(Person.id == ggp_node['id']).first()
                
                if ggu and ggp:
                    # Determine if GGU is older than GGP (their sibling)
                    is_ggu_older = False
                    if ggu.date_of_birth and ggp.date_of_birth:
                        is_ggu_older = ggu.date_of_birth < ggp.date_of_birth
                    else:
                        is_ggu_older = ggu.id < ggp.id
                    
                    ggu_gender = ggu_node.get('gender')
                    is_male = ggu_gender in ['male', 'nam']
                    
                    # At this level, typically just called "Cụ" regardless of age
                    # But we can distinguish if needed
                    return "Cụ" if is_male else "Bà cụ"
            except:
                pass
            
            return "Cụ"
        
        # 5.8. Great-Great-Nephew/Niece (reverse - 5 steps)
        # Pattern: GGN -> Parent -> GP -> GGP -> GGGP -> GGU
        # dirs = [-1, -1, -1, -1, 1]
        if n_steps == 5 and dirs == [-1, -1, -1, -1, 1]:
            try:
                ggn_node = nodes[0]
                gender = ggn_node.get('gender')
                return "Cháu cố"
            except:
                pass
            
            return "Cháu cố"
        

        # 6. Cousin relationships (Anh em họ - children of uncle/aunt)
        # Pattern: Me -> Parent -> GP -> Uncle/Aunt -> Cousin
        # dirs = [1, 1, -1, -1] (going up 2 levels, then down 2 levels)
        # Or reverse: Cousin -> Uncle -> GP -> Parent -> Me
        # dirs = [-1, -1, 1, 1]
        if n_steps == 4:
            if dirs == [1, 1, -1, -1] or dirs == [-1, -1, 1, 1]:
                # This is cousin relationship
                try:
                    if dirs == [1, 1, -1, -1]:
                        # Me -> Parent -> GP -> Uncle -> Cousin
                        cousin_node = nodes[-1]
                        my_node = nodes[0]
                        my_parent_node = nodes[1]
                        gp_node = nodes[2]
                        uncle_node = nodes[3]
                    else:
                        # Cousin -> Uncle -> GP -> Parent -> Me
                        cousin_node = nodes[0]
                        my_node = nodes[-1]
                        gp_node = nodes[2]
                        my_parent_node = nodes[3]
                        uncle_node = nodes[1]
                    
                    # NEW LOGIC: Instead of comparing birth dates,
                    # calculate the actual sibling relationship between my_parent and uncle
                    # This requires finding the path between them
                    
                    # Build a simple path to check sibling relationship
                    # my_parent -> gp, gp -> uncle (2 steps)
                    # We need to determine if my_parent is "Anh" or "Em" of uncle
                    
                    # Fetch both parents
                    uncle = db.query(Person).filter(Person.id == uncle_node['id']).first()
                    my_parent = db.query(Person).filter(Person.id == my_parent_node['id']).first()
                    
                    # Determine hierarchy based on sibling relationship
                    # Check if they share the same parents (siblings)
                    my_parent_is_older_sibling = False
                    
                    if uncle and my_parent:
                        # Same father OR same mother indicates they are siblings
                        are_siblings = (
                            (my_parent.father_id and uncle.father_id and my_parent.father_id == uncle.father_id) or
                            (my_parent.mother_id and uncle.mother_id and my_parent.mother_id == uncle.mother_id)
                        )
                        
                        if are_siblings:
                            # For siblings, use birth date to determine anh/em
                            # This is acceptable as per user requirement
                            if uncle.date_of_birth and my_parent.date_of_birth:
                                my_parent_is_older_sibling = my_parent.date_of_birth < uncle.date_of_birth
                            else:
                                # Fallback to ID if no birth date
                                my_parent_is_older_sibling = my_parent.id < uncle.id
                        
                    cousin_gender = cousin_node.get('gender')
                    is_male = cousin_gender in ['male', 'nam']
                        
                    # Determine cousin relationship based on PARENT'S sibling hierarchy
                    if my_parent_is_older_sibling:
                        # My Parent is OLDER sibling (Anh/Chị) of Uncle
                        # => Uncle is younger sibling of My Parent
                        # => Uncle is Chú/Cô/Dì/Cậu (depending on gender and side)
                        # => Cousin is "Con chú/cô/dì/cậu"
                        # => Cousin is younger rank than me
                        if is_male:
                            return "Em trai họ (con chú/cô/dì/cậu)"
                        else:
                            return "Em gái họ (con chú/cô/dì/cậu)"
                    else:
                        # My Parent is YOUNGER sibling (Em) of Uncle
                        # => Uncle is older sibling (Anh/Chị) of My Parent  
                        # => Uncle is Bác
                        # => Cousin is "Con bác"
                        # => Cousin is older rank than me
                        if is_male:
                            return "Anh họ (con bác)"
                        else:
                            return "Chị họ (con bác)"
                except:
                    pass
                
                return "Anh chị em họ"

        # 6b. Second Cousin relationships (Con của anh em họ - children of first cousins)
        # Pattern: Me -> Parent -> GP -> GGP -> Great-Uncle -> Parent's Cousin -> My Second Cousin
        # This is 6 steps for second cousins
        # dirs = [1, 1, 1, -1, -1, -1] or reverse [-1, -1, -1, 1, 1, 1]
        if n_steps == 6:
            if dirs == [1, 1, 1, -1, -1, -1] or dirs == [-1, -1, -1, 1, 1, 1]:
                # This is second cousin relationship
                try:
                    if dirs == [1, 1, 1, -1, -1, -1]:
                        # Me -> Parent -> GP -> GGP -> Great-Uncle -> Parent's Cousin -> Second Cousin
                        second_cousin_node = nodes[-1]
                        my_node = nodes[0]
                        my_parent_node = nodes[1]  # My parent
                        parents_cousin_node = nodes[5]  # My parent's cousin
                    else:
                        # Reverse: Second Cousin -> Parent's Cousin -> Great-Uncle -> GGP -> GP -> Parent -> Me
                        second_cousin_node = nodes[0]
                        my_node = nodes[-1]
                        my_parent_node = nodes[-2]  # nodes[5]
                        parents_cousin_node = nodes[1]  # My parent's cousin
                    
                    # Strategy: Determine relationship between my_parent and parents_cousin
                    # They are first cousins, so we need to know which one is "higher rank"
                    # We can recursively calculate the relationship between them
                    
                    # Build path between my_parent and parents_cousin
                    # This should be a 4-step cousin relationship
                    parent_relationship_path = find_shortest_path(my_parent_node['id'], parents_cousin_node['id'])
                    
                    if parent_relationship_path:
                        parent_nodes = parent_relationship_path['nodes']
                        parent_rels = parent_relationship_path['rels']
                        
                        # Get the cousin relationship term for parents
                        parent_term = get_summary_term(parent_nodes, parent_rels)
                        
                        # Now determine second cousin relationship based on parent relationship
                        second_cousin_gender = second_cousin_node.get('gender')
                        is_male = second_cousin_gender in ['male', 'nam']
                        
                        # If my parent is "Anh/Chị họ" of parents_cousin
                        # => I am higher rank than second cousin
                        # => second cousin is "Em họ đời 2"
                        if parent_term and "Anh" in parent_term or "Chị" in parent_term:
                            # My parent is older rank cousin
                            if is_male:
                                return "Em trai họ đời 2"
                            else:
                                return "Em gái họ đời 2"
                        # If my parent is "Em họ" of parents_cousin
                        # => I am lower rank than second cousin
                        # => second cousin is "Anh/Chị họ đời 2"
                        elif parent_term and "Em" in parent_term:
                            # My parent is younger rank cousin
                            if is_male:
                                return "Anh họ đời 2"
                            else:
                                return "Chị họ đời 2"
                
                except:
                    pass
                
                return "Anh chị em họ đời 2"


        # 7. Generic Spouse-of-Relative relationships (e.g., Wife of Uncle, Husband of Cousin)
        # Check if the last relationship is SPOUSE
        if n_steps > 1:
            last_rel = rels[-1]
            last_rel_type = last_rel.get('type', '')
            if last_rel_type == 'SPOUSE':
                # Determine relationship to the Partner (the person before Spouse)
                # Recurse: find relationship between Me (nodes[0]) and Partner (nodes[-2])
                sub_nodes = nodes[:-1] # Remove Spouse
                sub_rels = rels[:-1]   # Remove Spouse Rel
                
                partner_term = get_summary_term(sub_nodes, sub_rels)
                
                if not partner_term:
                    return None
                
                spouse_node = nodes[-1]
                spouse_gender = spouse_node.get('gender')
                is_spouse_male = spouse_gender in ['male', 'nam']
                
                # GENERAL RULE:
                # 1. Same generation (Anh/Chị/Em): Add "chồng" or "vợ"
                # 2. Other generations (Ông, Bà, Bác, Chú, Cô, Cháu, etc.): Keep the same term
                
                # Check if it's same-generation relationship
                if any(keyword in partner_term for keyword in ["Anh", "Chị", "Em"]):
                    # Same generation - use "chồng/vợ" suffix
                    # IMPORTANT: Flip the gender term
                    # Partner is "Chị" (female) -> Spouse (male) is "Anh chồng"
                    # Partner is "Anh" (male) -> Spouse (female) is "Chị vợ"
                    
                    if "Chị" in partner_term:
                        # Partner is female (Chị) -> Spouse is male -> Use "Anh"
                        return "Anh chồng" if is_spouse_male else "Em vợ"
                    elif "Anh" in partner_term:
                        # Partner is male (Anh) -> Spouse is female -> Use "Chị"
                        return "Chị vợ" if is_spouse_male == False else "Em chồng"
                    elif "Em" in partner_term:
                        # Partner is Em -> Need to determine if Em trai or Em gái
                        # If spouse is male and partner has "Em" -> partner is likely female (Em gái) -> spouse is Em chồng
                        # If spouse is female and partner has "Em" -> partner is likely male (Em trai) -> spouse is Em vợ
                        return "Em chồng" if is_spouse_male else "Em vợ"

                
                # Special mappings for uncle/aunt terms
                # Partner is male uncle/aunt term -> Spouse needs female equivalent
                if partner_term == "Chú":
                    return "Thím"  # Wife of Chú
                elif partner_term == "Cậu":
                    return "Mợ"  # Wife of Cậu
                elif partner_term in ["Cô", "Dì"]:
                    return "Dượng"  # Husband of Cô/Dì
                elif partner_term == "Bác":
                    # Bác can be male or female, spouse should match
                    return "Bác gái" if is_spouse_male == False else "Bác"
                
                # For all other cases (Ông, Bà, Cụ, Ông cố, Cháu, etc.)
                # Keep the same term
                return partner_term


        # 8. Start-of-path Spouse relationships (User is Spouse -> Partner -> Target)
        # e.g. Me (Wife) -> Husband -> Cousin
        if n_steps > 1:
            first_rel = rels[0]
            first_rel_type = first_rel.get('type', '')
            if first_rel_type == 'SPOUSE':
                # My Spouse is nodes[1]
                # Calculate relationship from My Spouse (nodes[1]) to Target (nodes[-1])
                sub_nodes = nodes[1:]
                sub_rels = rels[1:]
                
                partner_term = get_summary_term(sub_nodes, sub_rels)
                
                if not partner_term:
                    return None
                
                my_node = nodes[0]
                my_gender = my_node.get('gender')
                is_me_male = my_gender in ['male', 'nam']
                
                # DEBUG
                print(f"DEBUG S8: partner_term='{partner_term}', is_me_male={is_me_male}, my_name={my_node.get('name')}, target_name={nodes[-1].get('name')}")
                
                # Apply the SAME general rule as Section 7
                # 1. Same generation: Add "chồng/vợ"
                # 2. Other generations: Keep the same term
                
                # Check if same-generation relationship
                if any(keyword in partner_term for keyword in ["Anh", "Chị", "Em"]):
                    # Same generation - apply different rules based on relationship type
                    
                    # Rule 1: Cousin relationships (họ) - flip gender based on spouse
                    if "họ" in partner_term:
                        if is_me_male:
                            # Male spouse
                            if "Chị" in partner_term or "Em gái" in partner_term:
                                # Partner (female) calls female cousin -> I (male) call male equivalent
                                if "con bác" in partner_term:
                                    return "Anh họ (con bác)"
                                elif "đời 2" in partner_term:
                                    return "Anh họ đời 2"
                                else:
                                    return "Anh họ"
                            else:
                                # Partner calls male cousin -> keep it
                                return partner_term
                        else:
                            # Female spouse
                            if "Anh" in partner_term or "Em trai" in partner_term:
                                # Partner (male) calls male cousin -> I (female) call female equivalent
                                if "con bác" in partner_term:
                                    return "Chị họ (con bác)"
                                elif "đời 2" in partner_term:
                                    return "Chị họ đời 2"
                                else:
                                    return "Chị họ"
                            else:
                                # Partner calls female cousin -> keep it
                                return partner_term
                    
                    # Rule 2: Direct siblings (trai/gái) - remove gender suffix, keep rank
                    elif "trai" in partner_term or "gái" in partner_term:
                        # Strip "trai" or "gái" and keep base term
                        if "Anh" in partner_term:
                            return "Anh"
                        elif "Chị" in partner_term:
                            return "Chị"
                        elif "Em" in partner_term:
                            return "Em"
                    
                    # Rule 3: Generic Anh/Chị/Em (no họ, no trai/gái) - keep as is
                    else:
                        return partner_term

                
                # Special mappings for uncle/aunt terms
                if partner_term == "Chú":
                    return "Thím"
                elif partner_term == "Cậu":
                    return "Mợ"
                elif partner_term in ["Cô", "Dì"]:
                    return "Dượng"
                elif partner_term == "Bác":
                    return "Bác gái" if is_me_male == False else "Bác"
                
                # For all other cases: keep the same term
                return partner_term


        return None

    # Tạo mô tả chi tiết từng bước (giữ lại để bổ trợ)
    description_parts = []
    for i in range(len(nodes) - 1):
        n1, n2, rel = nodes[i], nodes[i+1], rels[i]
        rel_type = rel.get('type', '')
        
        # Handle SPOUSE relationship
        if rel_type == 'SPOUSE':
            gender = n1.get('gender')
            is_male = gender in ['male', 'nam']
            role = "Chồng" if is_male else "Vợ"
            description_parts.append(f"{n1['name']} là {role} của {n2['name']}")
        # Handle PARENT relationships
        elif rel['start'] == n1['id']:
            # n1 is parent of n2
            if rel_type == 'FATHER_OF':
                role = "Cha"
            elif rel_type == 'MOTHER_OF':
                role = "Mẹ"
            else:
                # Fallback to gender
                role = "Cha" if (n1.get('gender') == 'male' or n1.get('gender') == 'nam') else "Mẹ"
            description_parts.append(f"{n1['name']} là {role} của {n2['name']}")
        else:
            # n1 is child of n2
            gender = n1.get('gender')
            is_male = gender in ['male', 'nam']
            role = "Con trai" if is_male else "Con gái"
            description_parts.append(f"{n1['name']} là {role} của {n2['name']}")
    
    summary = get_summary_term(nodes, rels)
    detailed = ". ".join(description_parts) + "."
    
    result = {
        "relationship": detailed,
        "path": [n['id'] for n in nodes]
    }
    
    if summary:
        result["relationship"] = f"{nodes[0]['name']} là {summary} của {nodes[-1]['name']}. ({detailed})"
    
    return result


from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from db.mysql_connection import get_db
from models import Person, Relationship, User
from db.neo4j_connection import add_person_to_graph, create_relationship_in_graph
from dependencies import get_current_user

router = APIRouter(prefix="/maintenance", tags=["Maintenance"])

@router.post("/sync-neo4j")
def sync_neo4j(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """
    Quét toàn bộ DB MySQL và đẩy dữ liệu sang Neo4j để sửa lỗi lệch dữ liệu.
    """
    print(f"DEBUG: Maintenance Sync started by user {current_user.username}")
    
    try:
        # 1. Lấy tất cả Persons
        persons = db.query(Person).all()
        print(f"DEBUG: Found {len(persons)} persons in MySQL.")
        
        # 2. Đẩy Nodes
        nodes_created = 0
        for p in persons:
            try:
                full_name = f"{p.last_name} {p.first_name}".strip()
                add_person_to_graph(
                    id=p.id,
                    full_name=full_name,
                    gender=p.gender,
                    family_id=p.family_id,
                    father_id=None,
                    mother_id=None
                )
                nodes_created += 1
            except Exception as node_e:
                print(f"DEBUG: Error adding node {p.id}: {node_e}")
        
        print(f"DEBUG: Finished adding {nodes_created} nodes to Neo4j.")

        # 3. Đẩy Relationships từ Person (Cột father_id, mother_id)
        rel_count = 0
        for p in persons:
            try:
                if p.father_id:
                    create_relationship_in_graph(p.father_id, p.id, "FATHER_OF")
                    rel_count += 1
                if p.mother_id:
                    create_relationship_in_graph(p.mother_id, p.id, "MOTHER_OF")
                    rel_count += 1
            except Exception as rel_e:
                print(f"DEBUG: Error adding rel from person {p.id}: {rel_e}")

        # 4. Đẩy Relationships từ bảng Relationship (Đề phòng data chỉ có ở đây)
        rels = db.query(Relationship).all()
        print(f"DEBUG: Found {len(rels)} entries in Relationship table.")
        for r in rels:
            try:
                # Map relationship_type or extra_info
                # person1_id is Child, person2_id is Parent (based on import logic)
                parent_id = r.person2_id
                child_id = r.person1_id
                if r.relationship_type.lower() in ['father', 'mother', 'parent'] or r.extra_info in ['Cha', 'Mẹ']:
                   create_relationship_in_graph(parent_id, child_id, "PARENT_OF")
                   rel_count += 1
            except Exception as rel_e:
                 print(f"DEBUG: Error adding rel {r.id}: {rel_e}")

        print(f"DEBUG: Sync completed. Nodes: {nodes_created}, Rels: {rel_count}")
                
        return {
            "status": "success", 
            "message": f"Synced {nodes_created} persons and {rel_count} relationships to Neo4j."
        }
    except Exception as e:
        print(f"DEBUG: Global Sync Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

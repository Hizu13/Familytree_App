from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from db.mysql_connection import get_db
from models import Person

router = APIRouter(
    prefix="/tree",
    tags=["Family Tree"]
)

@router.get("/{family_id}")
def get_family_tree(family_id: int, db: Session = Depends(get_db)):
    persons = db.query(Person).filter(Person.family_id == family_id).all()
    if not persons:
        raise HTTPException(status_code=404, detail="Family not found")

    # Bước 1: Map ID -> node
    person_map = {
        p.id: {
            "id": p.id,
            "name": getattr(p, "name", f"{getattr(p, 'first_name', '')} {getattr(p, 'last_name', '')}".strip()),
            "children": []
        }
        for p in persons
    }

    # Bước 2: Gắn con vào cha
    for p in persons:
        if p.father_id and p.father_id in person_map:
            person_map[p.father_id]["children"].append(person_map[p.id])

    # Bước 3: Lấy gốc (người không có cha)
    roots = [person_map[p.id] for p in persons if not p.father_id]

    # Bước 4: Trả JSON
    return roots

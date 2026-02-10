from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from db.mysql_connection import SessionLocal
from models import Person, Relationship
from typing import List, Optional, Dict
from datetime import date

router = APIRouter(prefix="/relationships", tags=["Relationships"])

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Helper: Load family graph
def build_family_graph(family_id: int, db: Session):
    members = db.query(Person).filter(Person.family_id == family_id).all()
    # Map id -> Person object
    person_map = {m.id: m for m in members}
    # Map child_id -> [father_id, mother_id]
    parents_map = {}
    for m in members:
        p_ids = []
        if m.father_id: p_ids.append(m.father_id)
        if m.mother_id: p_ids.append(m.mother_id)
        parents_map[m.id] = p_ids
    return person_map, parents_map

# Helper: Find ancestors
def get_ancestors(person_id: int, parents_map: Dict[int, List[int]], depth=0):
    """Return dict {ancestor_id: distance}"""
    ancestors = {person_id: depth} # Include self as distance 0
    queue = [(person_id, depth)]
    
    visited = set([person_id])
    
    while queue:
        curr, dist = queue.pop(0)
        p_ids = parents_map.get(curr, [])
        for p in p_ids:
            if p not in visited:
                visited.add(p)
                ancestors[p] = dist + 1
                queue.append((p, dist + 1))
    return ancestors
def _calculate_blood_relationship(person1_id: int, person2_id: int, person_map, parents_map, p1_obj, p2_obj):
    """
    Tính mối quan hệ huyết thống giữa 2 người.
    Return: Mối quan hệ của person2 ĐỐI VỚI person1 (person2 là gì của person1?)
    """
    # 1. Get ancestors
    ancestors_p1 = get_ancestors(person1_id, parents_map)
    ancestors_p2 = get_ancestors(person2_id, parents_map)

    # Check if P2 is ancestor of P1 (P2 là tổ tiên của P1)
    if person2_id in ancestors_p1:
        gen_diff = ancestors_p1[person2_id]
        if gen_diff == 1:
            # P2 is parent of P1
            if p2_obj.gender in ['male', 'nam']:
                return "Bố"
            else:
                return "Mẹ"
        if gen_diff == 2:
            # P2 is grandparent of P1
            if p2_obj.gender in ['male', 'nam']:
                return "Ông"
            else:
                return "Bà"
        if gen_diff == 3:
            if p2_obj.gender in ['male', 'nam']:
                return "Cụ ông"
            else:
                return "Cụ bà"
        if gen_diff >= 4:
            return f"Tổ tiên đời thứ {gen_diff}"

    # Check if P1 is ancestor of P2 (P1 là tổ tiên của P2, tức P2 là hậu duệ của P1)
    if person1_id in ancestors_p2:
        gen_diff = ancestors_p2[person1_id]
        if gen_diff == 1:
            # P2 is child of P1
            if p2_obj.gender in ['male', 'nam']:
                return "Con trai"
            else:
                return "Con gái"
        if gen_diff == 2:
            # P2 is grandchild of P1
            if p2_obj.gender in ['male', 'nam']:
                return "Cháu trai"
            else:
                return "Cháu gái"
        if gen_diff == 3:
            return "Chắt"
        if gen_diff == 4:
            return "Chút"
        if gen_diff == 5:
            return "Chít"
        return f"Hậu duệ đời thứ {gen_diff}"

    # 2. Find common ancestor (LCA)
    common_ancestors = set(ancestors_p1.keys()).intersection(set(ancestors_p2.keys()))
    if not common_ancestors:
        return None
    
    lca_id = min(common_ancestors, key=lambda x: ancestors_p1[x] + ancestors_p2[x])
    d1 = ancestors_p1[lca_id]  # Distance from P1 to LCA
    d2 = ancestors_p2[lca_id]  # Distance from P2 to LCA

    # Same generation (siblings, cousins)
    if d1 == d2:
        is_older = False
        if p2_obj.date_of_birth and p1_obj.date_of_birth:
             is_older = p2_obj.date_of_birth < p1_obj.date_of_birth
        else:
             is_older = p2_obj.id < p1_obj.id  # Fallback: lower ID = older
        
        if d1 == 1:  # Siblings (same parents)
             if is_older:
                 if p2_obj.gender in ['male', 'nam']:
                     return "Anh ruột"
                 else:
                     return "Chị ruột"
             else:
                 if p2_obj.gender in ['male', 'nam']:
                     return "Em trai ruột"
                 else:
                     return "Em gái ruột"
        
        # Cousins (same grandparents or further)
        if is_older:
            if p2_obj.gender in ['male', 'nam']:
                return "Anh họ"
            else:
                return "Chị họ"
        else:
            if p2_obj.gender in ['male', 'nam']:
                return "Em trai họ"
            else:
                return "Em gái họ"

    # P2 is higher generation (uncle/aunt, grand-uncle, etc.)
    if d1 > d2:
        diff = d1 - d2
        if diff == 1:
            # P2 is uncle/aunt of P1
            # Need to check if P2 is from father's side or mother's side
            # For simplicity, use generic terms
            if p2_obj.gender in ['male', 'nam']:
                # Check if P2 is older or younger than P1's parent
                # Simplified: use "Bác" for older, "Chú" for younger on father's side
                # For now, generic
                return "Bác/Chú"
            else:
                return "Cô/Dì"
        if diff == 2:
            if p2_obj.gender in ['male', 'nam']:
                return "Ông cố"
            else:
                return "Bà cố"
        return f"Họ hàng trên {diff} đời"

    # P2 is lower generation (nephew/niece, grand-nephew, etc.)
    if d1 < d2:
        diff = d2 - d1
        if diff == 1:
            # P2 is nephew/niece of P1
            if p2_obj.gender in ['male', 'nam']:
                return "Cháu trai"
            else:
                return "Cháu gái"
        if diff == 2:
            return "Cháu chắt"
        return f"Họ hàng dưới {diff} đời"

    return "Quan hệ phức tạp"

@router.get("/calculate")
def calculate_relationship(person1_id: int, person2_id: int, family_id: int, db: Session = Depends(get_db)):
    if person1_id == person2_id:
        return {"relationship": "Bản thân"}

    person_map, parents_map = build_family_graph(family_id, db)
    
    if person1_id not in person_map or person2_id not in person_map:
        raise HTTPException(status_code=404, detail="Thành viên không thuộc gia phả này")

    p1 = person_map[person1_id]
    p2 = person_map[person2_id]

    # 0. Check Direct
    direct_rel = db.query(Relationship).filter(
        Relationship.person1_id == person2_id,
        Relationship.person2_id == person1_id
    ).first()
    if direct_rel:
        return {"relationship": direct_rel.type}

    # 1. Blood
    blood_rel = _calculate_blood_relationship(person1_id, person2_id, person_map, parents_map, p1, p2)
    if blood_rel:
        return {"relationship": blood_rel}

    # 2. In-Law (Thông qua Vợ/Chồng)
    # Tìm vợ/chồng của P1
    spouse_rel_p1 = db.query(Relationship).filter(
        ((Relationship.person1_id == person1_id) & (Relationship.type.in_(['Vợ', 'Chồng']))) |
        ((Relationship.person2_id == person1_id) & (Relationship.type.in_(['Vợ', 'Chồng'])))
    ).first()

    if spouse_rel_p1:
        # P1 có spouse là S1
        s1_id = spouse_rel_p1.person2_id if spouse_rel_p1.person1_id == person1_id else spouse_rel_p1.person1_id
        if s1_id in person_map:
            # Check quan hệ của P2 đối với S1 (P2 là gì của S1?)
            rel_p2_s1 = _calculate_blood_relationship(s1_id, person2_id, person_map, parents_map, person_map[s1_id], p2)
            if rel_p2_s1:
                # Map logic
                if "Bố" in rel_p2_s1: return {"relationship": "Bố vợ/chồng"}
                if "Mẹ" in rel_p2_s1: return {"relationship": "Mẹ vợ/chồng"}
                if "Anh" in rel_p2_s1: return {"relationship": "Anh vợ/chồng"}
                if "Chị" in rel_p2_s1: return {"relationship": "Chị vợ/chồng"}
                if "Em" in rel_p2_s1: return {"relationship": "Em vợ/chồng"}

    # Tim Vo/Chong cua P2 (P2 la Spouse cua S2)
    # Check if P1 is related to S2? 
    # Logic: P2 is Spouse of S2. S2 is related to P1 (e.g. S2 is Son/Daughter of P1).
    # Then P2 is Son/Daughter-in-law.
    
    spouse_rel_p2 = db.query(Relationship).filter(
        ((Relationship.person1_id == person2_id) & (Relationship.type.in_(['Vợ', 'Chồng']))) |
        ((Relationship.person2_id == person2_id) & (Relationship.type.in_(['Vợ', 'Chồng'])))
    ).first()

    if spouse_rel_p2:
         s2_id = spouse_rel_p2.person2_id if spouse_rel_p2.person1_id == person2_id else spouse_rel_p2.person1_id
         if s2_id in person_map:
             # Check quan hệ của S2 đối với P1 (S2 là gì của P1?)
             rel_s2_p1 = _calculate_blood_relationship(person1_id, s2_id, person_map, parents_map, p1, person_map[s2_id])
             if rel_s2_p1:
                 if "Con" in rel_s2_p1: 
                     if p2.gender == 'male' or p2.gender == 'nam': return {"relationship": "Con rể"}
                     return {"relationship": "Con dâu"}

    return {"relationship": "Quan hệ người dưng hoặc chưa xác định"}

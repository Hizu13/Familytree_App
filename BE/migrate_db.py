from db.mysql_connection import SessionLocal
from models import Person, Relationship
from sqlalchemy.orm import Session
from datetime import datetime

def regenerate_relationships():
    db = SessionLocal()
    try:
        print("Starting Relationship Regeneration...")
        persons = db.query(Person).all()
        processed_count = 0
        
        # Pre-fetch for faster lookup
        person_map = {p.id: p for p in persons}
        
        for p in persons:
            # 1. Father / Mother / Child
            if p.father_id and p.father_id in person_map:
                father = person_map[p.father_id]
                # (Me, Dad) -> Bố
                ensure_rel(db, p.id, father.id, "bố")
                # (Dad, Me) -> Con
                child_role = "con trai" if p.gender == 'male' else "con gái"
                ensure_rel(db, father.id, p.id, child_role)
                
            if p.mother_id and p.mother_id in person_map:
                mother = person_map[p.mother_id]
                # (Me, Mom) -> Mẹ
                ensure_rel(db, p.id, mother.id, "mẹ")
                # (Mom, Me) -> Con
                child_role = "con trai" if p.gender == 'male' else "con gái"
                ensure_rel(db, mother.id, p.id, child_role)

            # 2. Siblings (Recalculate for everyone)
            # Find siblings via DB query is safer than map iteration for each
            # Or use map? Map is faster.
            # Siblings = same father OR same mother
            siblings = []
            if p.father_id:
                siblings += [sib for sib in persons if sib.father_id == p.father_id and sib.id != p.id]
            if p.mother_id:
                siblings += [sib for sib in persons if sib.mother_id == p.mother_id and sib.id != p.id and sib not in siblings]
            
            for sib in siblings:
                # Calculate Role
                 # Check full status
                is_full = (sib.father_id == p.father_id) and (sib.mother_id == p.mother_id)
                suffix = " ruột" if is_full else ""
                
                # Check age
                am_i_older = False
                if p.date_of_birth and sib.date_of_birth:
                    am_i_older = p.date_of_birth < sib.date_of_birth
                else:
                    am_i_older = p.id < sib.id
                
                # Relation: Me -> Sib ("Tôi là gì của Sib?")
                if am_i_older:
                    my_role = "anh" if p.gender == 'male' else "chị"
                    if suffix: my_role += suffix
                else:
                    my_role = "em"
                    if suffix: my_role += suffix
                    if p.gender == 'male': my_role += " trai"
                    else: my_role += " gái"
                
                ensure_rel(db, p.id, sib.id, my_role)

            processed_count += 1
            if processed_count % 10 == 0:
                print(f"Processed {processed_count}/{len(persons)} persons...")
        
        db.commit()
        print("Relationship Regeneration Completed Successfully!")
        
    except Exception as e:
        print(f"Error: {e}")
        db.rollback()
    finally:
        db.close()

def ensure_rel(db: Session, p1: int, p2: int, type_: str):
    exists = db.query(Relationship).filter(
        Relationship.person1_id == p1, 
        Relationship.person2_id == p2
    ).first()
    
    if not exists:
        db.add(Relationship(person1_id=p1, person2_id=p2, type=type_))
    # If exists but Type is diff? Update?
    # Old logic might have empty type? No we dropped table.
    # So if exists, it's correct.

if __name__ == "__main__":
    regenerate_relationships()

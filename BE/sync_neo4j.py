"""
Script để đồng bộ lại tất cả relationships vào Neo4j
"""
import sys
sys.path.append('.')

from db.mysql_connection import SessionLocal
from db.neo4j_connection import Neo4jConnection, add_person_to_graph, create_relationship_in_graph
from models import Person
from dotenv import load_dotenv

load_dotenv()

def sync_all_to_neo4j():
    db = SessionLocal()
    neo4j = Neo4jConnection()
    
    try:
        # 1. Xóa toàn bộ graph hiện tại
        print("🗑️  Clearing Neo4j database...")
        neo4j.execute("MATCH (n) DETACH DELETE n")
        print("✅ Cleared!")
        
        # 2. Thêm tất cả persons
        print("\n👤 Adding all persons to Neo4j...")
        all_persons = db.query(Person).all()
        for person in all_persons:
            full_name = f"{person.last_name or ''} {person.first_name}".strip()
            add_person_to_graph(person.id, full_name, person.gender, person.family_id)
            print(f"  ✓ Added: {full_name} (ID: {person.id})")
        
        # 3. Thêm tất cả relationships
        print("\n🔗 Adding relationships...")
        for person in all_persons:
            # Father relationship
            if person.father_id:
                try:
                    create_relationship_in_graph(person.father_id, person.id, "FATHER_OF")
                    print(f"  ✓ FATHER_OF: {person.father_id} -> {person.id}")
                except Exception as e:
                    print(f"  ❌ Error creating FATHER_OF: {e}")
            
            # Mother relationship
            if person.mother_id:
                try:
                    create_relationship_in_graph(person.mother_id, person.id, "MOTHER_OF")
                    print(f"  ✓ MOTHER_OF: {person.mother_id} -> {person.id}")
                except Exception as e:
                    print(f"  ❌ Error creating MOTHER_OF: {e}")
        
        # 4. Thêm SPOUSE relationships
        print("\n💑 Adding spouse relationships...")
        from models import Relationship
        spouse_rels = db.query(Relationship).filter(Relationship.type.in_(['vợ', 'chồng'])).all()
        processed_pairs = set()
        
        for rel in spouse_rels:
            pair = tuple(sorted([rel.person1_id, rel.person2_id]))
            if pair not in processed_pairs:
                try:
                    create_relationship_in_graph(rel.person1_id, rel.person2_id, "SPOUSE")
                    create_relationship_in_graph(rel.person2_id, rel.person1_id, "SPOUSE")
                    print(f"  ✓ SPOUSE: {rel.person1_id} <-> {rel.person2_id}")
                    processed_pairs.add(pair)
                except Exception as e:
                    print(f"  ❌ Error creating SPOUSE: {e}")
        
        print("\n✅ Sync completed!")
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()
        neo4j.close()

if __name__ == "__main__":
    sync_all_to_neo4j()

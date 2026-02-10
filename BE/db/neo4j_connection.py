from neo4j import GraphDatabase
from dotenv import load_dotenv
import os

load_dotenv()

class Neo4jConnection:
    def __init__(self):
        self.uri = os.getenv("NEO4J_URI", "bolt://localhost:7687")
        self.user = os.getenv("NEO4J_USER", "neo4j")
        self.password = os.getenv("NEO4J_PASSWORD", "password")
        # Add timeouts to prevent hanging
        self.driver = GraphDatabase.driver(
            self.uri, 
            auth=(self.user, self.password),
            connection_timeout=5.0, # 5 seconds
            max_connection_lifetime=200 # Restart connection occasionally
        )

    def close(self):
        if self.driver:
            self.driver.close()

    def query(self, query, parameters=None):
        """Thực thi query đọc dữ liệu (SELECT)."""
        with self.driver.session() as session:
            result = session.run(query, parameters or {})
            return [record.data() for record in result]

    def execute(self, query, parameters=None):
        """Thực thi query ghi dữ liệu (CREATE / MERGE / DELETE)."""
        with self.driver.session() as session:
            session.run(query, parameters or {})

# --- Các hàm tiện ích đặc thù cho gia phả ---
neo4j_conn = Neo4jConnection()

def add_person_to_graph(id, full_name, gender, family_id, father_id=None, mother_id=None):
    """Thêm hoặc cập nhật một node Person vào Neo4j."""
    neo4j_conn.execute("""
        MERGE (p:Person {id: $id})
        SET p.name = $full_name, p.gender = $gender, p.family_id = $family_id
    """, {"id": id, "full_name": full_name, "gender": gender, "family_id": family_id})

    # Nếu có cha/mẹ ngay lúc này, tạo luôn. 
    # Nhưng trong import sẽ dùng hàm riêng để tránh lỗi node chưa tồn tại.
    if father_id:
        create_relationship_in_graph(father_id, id, "FATHER_OF")

    if mother_id:
        create_relationship_in_graph(mother_id, id, "MOTHER_OF")

def create_relationship_in_graph(parent_id, child_id, type="PARENT_OF"):
    """
    Tạo quan hệ giữa Cha/Mẹ và Con. 
    Sử dụng MERGE cho cả nodes để đảm bảo chúng tồn tại trước khi nối.
    """
    # Use the passed type parameter (FATHER_OF, MOTHER_OF, SIBLING, etc.)
    neo4j_conn.execute(f"""
        MERGE (parent:Person {{id: $parent_id}})
        MERGE (child:Person {{id: $child_id}})
        MERGE (parent)-[:{type}]->(child)
    """, {"parent_id": parent_id, "child_id": child_id})

def delete_person_from_graph(id):
    """Xóa node Person và các quan hệ liên quan khỏi Neo4j."""
    neo4j_conn.execute("""
        MATCH (p:Person {id: $id})
        DETACH DELETE p
    """, {"id": id})

def find_shortest_path(from_id, to_id):
    """Tìm đường đi ngắn nhất giữa 2 người, ưu tiên quan hệ cha/mẹ hơn vợ/chồng."""
    # Try to find path using FATHER_OF/MOTHER_OF only first
    query_direct = """
        MATCH (start:Person {id: $from_id}), (end:Person {id: $to_id})
        MATCH p = shortestPath((start)-[:FATHER_OF|MOTHER_OF|SPOUSE*]-(end))
        RETURN [n in nodes(p) | {id: n.id, name: n.name, gender: n.gender}] as nodes,
               [r in relationships(p) | {start: startNode(r).id, end: endNode(r).id, type: type(r)}] as rels
    """
    result = neo4j_conn.query(query_direct, {"from_id": from_id, "to_id": to_id})
    
    # If found direct path, return it
    if result:
        return result[0]
    
    # Otherwise, try including SPOUSE relationships
    query_with_spouse = """
        MATCH (start:Person {id: $from_id}), (end:Person {id: $to_id})
        MATCH p = shortestPath((start)-[:FATHER_OF|MOTHER_OF|SPOUSE*]-(end))
        RETURN [n in nodes(p) | {id: n.id, name: n.name, gender: n.gender}] as nodes,
               [r in relationships(p) | {start: startNode(r).id, end: endNode(r).id, type: type(r)}] as rels
    """
    result = neo4j_conn.query(query_with_spouse, {"from_id": from_id, "to_id": to_id})
    
    if not result:
        return None
        
    return result[0] # {'nodes': [...], 'rels': []}


def get_family_graph(family_id):
    """Lấy toàn bộ cây gia phả của family_id từ Neo4j."""
    query = """
        MATCH (p:Person {family_id: $family_id})
        OPTIONAL MATCH (p)-[r:PARENT_OF]->(child)
        RETURN p as node, r as rel
    """
    # Note: Query này trả về từng row (node + rel). Cần group lại ở Python.
    # Tuy nhiên, để dễ format TreeResponse (nodes list, edges list), ta có thể collect luôn trong Cypher.
    
    query_collect = """
        MATCH (n:Person {family_id: $family_id})
        OPTIONAL MATCH (father:Person)-[:FATHER_OF]->(n)
        OPTIONAL MATCH (mother:Person)-[:MOTHER_OF]->(n)
        OPTIONAL MATCH (n)-[r]->(child)
        WHERE type(r) IN ['FATHER_OF', 'MOTHER_OF']
        RETURN collect(DISTINCT {
                 id: n.id, 
                 name: n.name, 
                 gender: n.gender, 
                 birth_year: "?",
                 father_id: father.id,
                 mother_id: mother.id
               }) as nodes, 
               collect(DISTINCT {from_id: startNode(r).id, to_id: endNode(r).id, type: type(r)}) as edges
    """
    result = neo4j_conn.query(query_collect, {"family_id": family_id})
    if not result:
        return {"nodes": [], "edges": []}
        
    data = result[0]
    # Filter out null edges (from OPTIONAL MATCH where no relationship exists)
    edges = [e for e in data['edges'] if e['from_id'] is not None]
    
    return {"nodes": data['nodes'], "edges": edges}

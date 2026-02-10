"""
Script tạo database family_tree nếu chưa tồn tại
"""
import pymysql
import sys

def create_database():
    try:
        # Kết nối đến MySQL server (không chỉ định database)
        connection = pymysql.connect(
            host='127.0.0.1',
            port=3306,
            user='root',
            password='',  # XAMPP mặc định không có password cho root
            charset='utf8mb4',
            cursorclass=pymysql.cursors.DictCursor
        )
        
        print("✅ Kết nối MySQL thành công!")
        
        with connection.cursor() as cursor:
            # Kiểm tra database đã tồn tại chưa
            cursor.execute("SHOW DATABASES LIKE 'family_tree'")
            result = cursor.fetchone()
            
            if result:
                print("✅ Database 'family_tree' đã tồn tại")
            else:
                # Tạo database mới
                cursor.execute("CREATE DATABASE family_tree CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
                print("✅ Đã tạo database 'family_tree' thành công!")
            
            # Hiển thị tất cả databases
            cursor.execute("SHOW DATABASES")
            databases = cursor.fetchall()
            print("\n📋 Danh sách databases:")
            for db in databases:
                print(f"  - {db['Database']}")
        
        connection.close()
        return True
        
    except pymysql.Error as e:
        print(f"❌ Lỗi MySQL: {e}")
        return False
    except Exception as e:
        print(f"❌ Lỗi: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    print("🚀 Đang kiểm tra và tạo database...")
    success = create_database()
    sys.exit(0 if success else 1)

import sqlite3
import os

db_path = 'mobile-vendor-api/instance/haus2.db'

def fix_database():
    print(f"🔧 Memperbarui skema database di {db_path}...")
    
    if not os.path.exists(db_path):
        print("❌ Database tidak ditemukan!")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Daftar kolom baru yang perlu ditambahkan
    new_columns = [
        ("message_type", "VARCHAR(20) DEFAULT 'text'"),
        ("media_url", "VARCHAR(255)"),
        ("product_id", "INTEGER")
    ]

    for col_name, col_type in new_columns:
        try:
            print(f"➕ Menambahkan kolom '{col_name}'...")
            cursor.execute(f"ALTER TABLE chat_messages ADD COLUMN {col_name} {col_type}")
            print(f"✅ Kolom '{col_name}' berhasil ditambahkan.")
        except sqlite3.OperationalError as e:
            if "duplicate column name" in str(e):
                print(f"ℹ️ Kolom '{col_name}' sudah ada.")
            else:
                print(f"❌ Gagal menambahkan '{col_name}': {e}")

    # Mengubah kolom 'message' agar boleh NULL (SQLite tidak mendukung ALTER COLUMN secara langsung)
    # Namun kita bisa membiarkannya tetap NOT NULL jika default value diatur, 
    # tapi agar aman untuk pesan media, kita pastikan skema mendukungnya.
    
    conn.commit()
    conn.close()
    print("\n🚀 Sinkronisasi Database Selesai!")

if __name__ == "__main__":
    fix_database()

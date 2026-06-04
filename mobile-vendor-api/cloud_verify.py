import os
import sys
import cloudinary
import cloudinary.uploader
import base64
from sqlalchemy import create_engine, text

def verify_neon(db_url):
    print("\n[1/2] Memverifikasi Koneksi Neon (PostgreSQL)...")
    try:
        if db_url.startswith("postgres://"):
            db_url = db_url.replace("postgres://", "postgresql://", 1)
            
        engine = create_engine(db_url)
        with engine.connect() as conn:
            result = conn.execute(text("SELECT version();")).fetchone()
            print(f"✅ Koneksi Berhasil! Versi DB: {result[0]}")
            
            print("Mencoba membuat tabel sementara...")
            conn.execute(text("CREATE TABLE IF NOT EXISTS _test_larisin (id serial PRIMARY KEY, val text);"))
            conn.execute(text("INSERT INTO _test_larisin (val) VALUES ('test_connection');"))
            conn.execute(text("DROP TABLE _test_larisin;"))
            conn.commit()
            print("✅ Hak akses baca/tulis OK.")
        return True
    except Exception as e:
        print(f"❌ Gagal koneksi Neon: {e}")
        return False

def verify_cloudinary(cloud_url):
    print("\n[2/2] Memverifikasi Koneksi Cloudinary...")
    try:
        os.environ['CLOUDINARY_URL'] = cloud_url
        cloudinary.config(secure=True)
        
        # Create a valid 1x1 transparent PNG image in memory/disk
        # This is a valid base64 encoded 1x1 pixel PNG
        png_data = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
        
        test_file_path = "test_upload.png"
        with open(test_file_path, "wb") as f:
            f.write(png_data)
            
        print("Mencoba mengunggah file gambar asli (1x1 PNG)...")
        result = cloudinary.uploader.upload(test_file_path, folder="larisin/test")
        print(f"✅ Berhasil! File tersedia di: {result.get('secure_url')}")
        
        os.remove(test_file_path)
        return True
    except Exception as e:
        print(f"❌ Gagal koneksi Cloudinary: {e}")
        return False

if __name__ == "__main__":
    print("=== LARISIN CLOUD VERIFICATION TOOL ===")
    
    db_url = os.environ.get('DATABASE_URL')
    cloud_url = os.environ.get('CLOUDINARY_URL')
    
    if not db_url or not cloud_url:
        print("\nERROR: Variabel lingkungan tidak ditemukan.")
        print("Silakan masukkan link Anda saat menjalankan perintah.")
        sys.exit(1)
        
    neon_ok = verify_neon(db_url)
    cloud_ok = verify_cloudinary(cloud_url)
    
    if neon_ok and cloud_ok:
        print("\n🏆 SEMUA KONEKSI OK! Infrastruktur Anda siap 100%.")
        print("Langkah selanjutnya: Push kode ke GitHub dan hubungkan ke Render.")
    else:
        print("\n⚠️ Harap periksa kembali link Cloudinary Anda.")

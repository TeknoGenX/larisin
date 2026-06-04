# 🚀 Panduan Deployment Larisin: Cloud-Ready Edition

Ikuti langkah-langkah ini untuk memindahkan **Larisin** dari komputer lokal ke internet menggunakan layanan gratis yang telah dipilih.

---

## 🏗️ Fase 1: Persiapan Infrastruktur (Layanan Gratis)

### 1. Database (Neon.tech)
1. Daftar di [Neon.tech](https://neon.tech).
2. Buat project baru bernama `larisin-db`.
3. Di Dashboard Neon, salin **Connection String** (Pilih mode PostgreSQL 16+).
   * Contoh: `postgresql://alex:abc123@ep-cool-water-123456.us-east-2.aws.neon.tech/neondb?sslmode=require`
4. Simpan link ini untuk langkah selanjutnya.

### 2. Storage (Cloudinary.com)
1. Daftar di [Cloudinary.com](https://cloudinary.com).
2. Di Dashboard utama, cari bagian **API Environment variable**.
3. Salin link yang diawali dengan `cloudinary://`.
   * Contoh: `cloudinary://123456789:abcdefg@mycloudname`
4. Link ini akan otomatis digunakan sistem Larisin untuk menyimpan foto dan voice notes.

---

## 🧠 Fase 2: Deploy Backend API (Render.com / Koyeb)

1. **Push ke GitHub:** Pastikan seluruh folder proyek Anda sudah di-push ke repository GitHub (Private atau Public).
2. **Setup di Render:**
   * Pilih **New +** > **Web Service**.
   * Hubungkan repository GitHub Anda.
   * **Root Directory:** `mobile-vendor-api`
   * **Runtime:** `Python 3`
   * **Build Command:** `pip install -r requirements.txt`
   * **Start Command:** `python run.py` (atau `gunicorn --config gunicorn_config.py app:create_app\(\)` untuk produksi tinggi).
3. **Environment Variables:** Di menu "Environment" Render, tambahkan variabel berikut:
   * `DATABASE_URL`: (Isi dengan link dari Neon)
   * `CLOUDINARY_URL`: (Isi dengan link dari Cloudinary)
   * `SECRET_KEY`: (Gunakan string acak panjang, misal: `openssl rand -hex 32`)
   * `JWT_SECRET_KEY`: (Gunakan string acak panjang yang berbeda)
   * `FLASK_ENV`: `production`

---

## 📱 Fase 3: Deploy Frontend Web (GitHub Pages)

1. **Update Base URL:** 
   Di folder `mobile_vendor_app/lib/shared/`, buka semua file yang memiliki `_baseUrl` dan ganti `http://127.0.0.1:5003` menjadi URL backend Render Anda (misal: `https://larisin-api.onrender.com`).
2. **Build Web:**
   Jalankan perintah ini di terminal:
   ```bash
   flutter build web --release --base-href "/larisin-web/"
   ```
3. **Deploy:**
   * Gunakan package `ghpages` atau upload folder `build/web` ke branch `gh-pages` di repository Anda.
   * Aktifkan GitHub Pages di menu Settings repo Anda.

---

## ✅ Fase 4: Verifikasi & Migrasi

1. **Database Migration:** 
   Setelah backend online, jalankan skrip inisialisasi tabel (Anda bisa melakukannya via Render Shell atau sementara mengubah `run.py` untuk menjalankan `db.create_all()`).
2. **Test Audit:**
   Jalankan `exhaustive_audit.py` di komputer lokal Anda, tapi ganti `BASE_URL` ke URL Render Anda untuk memastikan server cloud merespons dengan benar.

---

**Selamat! Larisin kini aktif 24/7 di awan (cloud) dan siap melayani 30+ partner Anda!**

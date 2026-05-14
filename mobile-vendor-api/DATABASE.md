# 🗄️ Database Architecture: Haus2 Ecosystem

Sistem menggunakan SQLite dengan SQLAlchemy untuk menjamin integritas data transaksi.

## 📐 Schema Overview

### 👤 `users` Table
- `username`: Unique identity.
- `role`: [admin, vendor, customer].
- `latitude`, `longitude`: Lokasi real-time terakhir.
- `is_verified`: Status KYC Vendor.

### 💬 `chat_messages` Table
- `message_type`: [text, voice, image, product].
- `media_url`: Path file audio/gambar di server.
- `product_id`: Relasi ke produk (untuk kartu produk).
- `is_read`: Status baca pesan (Read Receipts).

### 🍱 `products` & `daily_stocks`
- `daily_stocks`: Stok spesifik per vendor per hari. Stok di kartu chat diambil secara dinamis dari tabel ini.

### 🧾 `orders` & `order_items`
- Menjamin integrasi harga saat transaksi terjadi via snapshot `price_at_order`.

## ⚙️ Konfigurasi & Maintenance
- **Jalur Absolut:** Database dikonfigurasi menggunakan `os.path.abspath` di `app/__init__.py` untuk menghindari masalah *working directory*.
- **Inisialisasi Ulang:** Gunakan `python reinit_db.py` untuk menghapus dan membuat ulang seluruh tabel sesuai model terbaru.
- **Seeding:** Gunakan `seed_products.py` dan `seed_users.py` untuk mengisi data awal pengujian.

## 🔐 Concurrency Control
- **Pessimistic Locking (`with_for_update`)**: Digunakan saat checkout untuk memastikan stok tidak dipotong dua kali oleh transaksi yang bersamaan.

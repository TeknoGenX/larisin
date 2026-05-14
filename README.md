# 🏠 Haus2 Ecosystem: Marketplace Mobile Vendor

Sistem marketplace real-time yang mendukung vendor keliling (mobile vendor), pelanggan, dan administrasi pusat. Dilengkapi dengan pelacakan lokasi real-time, sistem chat multimedia, dan manajemen stok terpusat.

## 📁 Struktur Proyek
- `mobile-vendor-api/`: Backend API berbasis Flask, SQLAlchemy, dan Socket.IO.
- `mobile_vendor_app/`: Frontend Mobile berbasis Flutter (Multi-flavor untuk Vendor & Customer).
- `test_ecosystem.py`: Skrip pengujian end-to-end untuk seluruh alur bisnis.

## 🚀 Persiapan Backend
1. Masuk ke direktori backend: `cd mobile-vendor-api`
2. Pastikan virtual environment aktif: `source /home/andi-liani/virtual/venv/bin/activate`
3. Inisialisasi Database (jika diperlukan): `python reinit_db.py`
4. Jalankan Server: `python run.py` (Server akan berjalan di port 5003).

## 🧪 Pengujian
Tersedia beberapa skrip pengujian untuk memvalidasi integritas sistem:
- `python test_ecosystem.py`: Menjalankan simulasi penuh dari registrasi hingga ulasan (End-to-End).
- `pytest mobile-vendor-api/test_api.py`: Unit test untuk endpoint API.
- `python test_stock_api.py`: Mengetes sinkronisasi stok real-time.

## 🛠️ Fitur Utama
- **Real-time Tracking:** Lokasi vendor diperbarui secara instan di peta pelanggan menggunakan WebSocket.
- **Advanced Chat:** Mendukung pesan teks, Voice Notes, Photo Messaging, dan Kartu Produk interaktif.
- **Transaction Safety:** Menggunakan *Pessimistic Locking* pada database untuk mencegah *overselling* saat checkout simultan.
- **Admin Dashboard:** Monitoring statistik penjualan dan verifikasi KYC vendor secara visual.

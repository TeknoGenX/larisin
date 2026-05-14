# 🛡️ Security Implementation Report: Haus2 Ecosystem

Sistem menerapkan beberapa lapisan keamanan untuk melindungi pengguna.

## 🔑 1. Akses Kontrol & Real-time
- **JWT (Stateless):** Semua endpoint API mobile dilindungi oleh token JWT 24 jam.
- **Socket Rooms:** Pengguna hanya bergabung ke room `user_{id}` mereka sendiri untuk menjamin pesan chat tidak bocor ke pihak lain.

## 🛡️ 2. Perlindungan Media & File
- **Mime-type Validation:** Endpoint `/upload` memvalidasi ekstensi file (hanya gambar/audio tertentu) untuk mencegah eksekusi skrip berbahaya.
- **UUID Filenaming:** File yang diunggah diganti namanya menggunakan UUID untuk menghindari konflik nama file dan penyisipan path.

## 💰 3. Integritas Transaksi
- **Database Transactions:** Pengurangan stok dan pembuatan pesanan dibungkus dalam satu transaksi database. Jika satu gagal, seluruh proses dibatalkan (*Atomicity*).
- **Vendor Verification:** Fitur stok dan jualan hanya aktif bagi vendor yang sudah disetujui Admin.

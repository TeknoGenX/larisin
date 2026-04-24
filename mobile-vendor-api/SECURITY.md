# 🛡️ Security Implementation Report: Haus2 Ecosystem

Sistem ini dirancang dengan prinsip **Security by Design** untuk melindungi data pengguna dan integritas transaksi.

## 🔑 1. Akses Kontrol (JWT)
- Menggunakan JSON Web Token dengan payload `role`.
- Token berlaku selama 24 jam.
- Filter Role otomatis untuk membedakan akses Admin, Vendor, dan Customer via Decorator `@role_required`.

## 🛡️ 2. Perlindungan Serangan
- **Brute Force Protection:** Salah password 5x mengakibatkan blokir akun 15 menit otomatis.
- **Review Anti-Spam:** Batasan ulasan hanya untuk pesanan yang sudah `delivered`.
- **Public Admin Lock:** Registrasi publik dilarang menggunakan `role: admin`.

## 🗺️ 3. Integritas Data GPS
- Validasi koordinat geografis bumi saat pengiriman dari perangkat vendor.
- Pemisahan data lokasi yang bersifat sementara (In-memory ready jika pindah ke Redis).

## 💰 4. Integritas Transaksi
- **Pessimistic Locking:** Penggunaan database transaction saat pemotongan stok otomatis.
- **Double Validation:** Stok dicek saat checkout untuk mencegah pesanan melebihi ketersediaan.

# 📑 Dokumentasi API Marketplace Mobile Vendor

Seluruh request wajib menyertakan header `Content-Type: application/json`. Endpoint yang dilindungi membutuhkan header `Authorization: Bearer <JWT_TOKEN>`.

## 🛡️ Autentikasi (`/auth`)
- `POST /auth/register`: Pendaftaran Customer/Vendor. (Kirim `ktp_image_url` untuk vendor).
- `POST /auth/login`: Login akun. Mengembalikan `access_token` dan detail user. (Proteksi Brute-force aktif).

## 🏢 Admin API (`/admin`)
- `GET /admin/pending-vendors`: Daftar vendor yang menunggu verifikasi KYC.
- `PATCH /admin/verify-vendor/<id>`: Menyetujui atau menolak vendor baru.
- `POST /admin/products`: Menambahkan menu minuman baru ke katalog global.

## 🚲 Vendor Operations (`/vendor`)
- `GET /vendor/products`: Katalog produk resmi dari pusat.
- `POST /vendor/stock`: Update jumlah stok jualan (Wajib akun Verified).
- `POST /vendor/location`: Update posisi GPS terbaru (Otomatis setiap 30 detik).
- `GET /vendor/orders`: Daftar pesanan masuk untuk diproses.
- `PATCH /vendor/orders/<id>/status`: Update status pesanan (`processing` -> `on_delivery`).

## 🛒 Customer Operations (`/customer` & `/order`)
- `GET /customer/nearby-vendors`: Mencari vendor aktif di sekitar (Radius search).
- `GET /customer/vendor-stock/<vendor_id>`: Melihat sisa stok pedagang tertentu.
- `POST /order/`: Checkout keranjang belanja (Pessimistic Locking aktif).
- `GET /order/history`: Riwayat belanja pribadi.
- `PATCH /order/<id>/complete`: Konfirmasi pesanan diterima (Ubah ke `delivered`).
- `POST /customer/review`: Memberikan rating (1-5) & ulasan.
- `GET /customer/vendor-reviews/<vendor_id>`: Melihat testimoni pelanggan lain.

## 🖥️ Web Admin Dashboard (`/web-admin`)
- `GET /web-admin/login`: Halaman login dashboard.
- `GET /web-admin/dashboard`: Visualisasi statistik, Peta live, dan Verifikasi KYC.
- `GET /web-admin/orders/export`: Download seluruh transaksi dalam format **CSV**.

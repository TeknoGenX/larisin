# 📑 Dokumentasi API Marketplace Mobile Vendor

Seluruh request wajib menyertakan header `Content-Type: application/json`. Endpoint yang dilindungi membutuhkan header `Authorization: Bearer <JWT_TOKEN>`.

## 🛡️ Autentikasi (`/auth`)
- `POST /auth/register`: Pendaftaran Customer/Vendor.
- `POST /auth/login`: Login akun. Mengembalikan `access_token` dan detail user.

## 💬 Real-time Chat (`/chat`)
- `POST /chat/send`: Mengirim pesan teks.
- `GET /chat/history/<other_id>`: Mengambil riwayat pesan antara dua user.
- `GET /chat/conversations`: Mendapatkan daftar percakapan aktif dengan info unread.
- `PATCH /chat/read/<other_id>`: Menandai pesan sebagai dibaca (Centang Biru).
- `POST /chat/upload/voice`: Upload rekaman suara (.m4a).
- `POST /chat/upload/image`: Upload gambar (.jpg, .png).
- `POST /chat/send-product`: Mengirim kartu produk interaktif.

## 🚲 Vendor Operations (`/vendor`)
- `GET /vendor/products`: Katalog produk resmi.
- `POST /vendor/stock`: Update stok harian.
- `POST /vendor/location`: Update posisi GPS (Real-time via Socket.IO).
- `GET /vendor/orders`: Daftar pesanan masuk.

## 🛒 Customer Operations (`/customer` & `/order`)
- `GET /customer/nearby-vendors`: Mencari vendor aktif di sekitar.
- `POST /order/`: Checkout keranjang belanja (Pessimistic Locking).
- `GET /order/history`: Riwayat belanja pribadi.
- `POST /customer/review`: Memberikan rating & ulasan.

## 🖥️ Web Admin Dashboard (`/web-admin`)
- `GET /web-admin/login`: Halaman login dashboard.
- `GET /web-admin/dashboard`: Visualisasi statistik & Peta live.

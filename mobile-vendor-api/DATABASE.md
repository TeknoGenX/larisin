# 🗄️ Database Architecture: Haus2 Ecosystem

Sistem menggunakan SQLite (Dev) dengan SQLAlchemy untuk menjamin integritas data transaksi.

## 📐 Schema Overview

### 👤 `users` Table
- `username`: Unique.
- `role`: [admin, vendor, customer].
- `is_verified`: Default `false` (Wajib disetujui admin sebelum berjualan).
- `failed_login_attempts`: Brute Force protection counter.
- `locked_until`: Timestamp blokir akun otomatis.
- `latitude`, `longitude`: Koordinat GPS terakhir.

### 🍱 `products` & `daily_stocks`
- `products`: Katalog global (nama, deskripsi, harga).
- `daily_stocks`: Jumlah stok spesifik per Vendor per Hari. Otomatis terpotong saat pesanan masuk.

### 🧾 `orders` & `order_items`
- `orders`: Status (`pending` -> `paid` -> `processing` -> `on_delivery` -> `delivered`).
- `order_items`: Menyimpan snapshot `price_at_order` saat transaksi terjadi.

### ⭐️ `reviews`
- Berelasi unik dengan satu `Order ID` untuk mencegah spam ulasan.

## 🔐 Concurrency Control
Sistem mengamankan pengurangan stok menggunakan **Pessimistic Locking**:
- **SQLAlchemy `with_for_update()`**: Digunakan saat proses checkout untuk mengunci baris stok vendor sehingga tidak terjadi *double-spending* atau *race condition* stok saat banyak pembeli memesan produk yang sama secara bersamaan.

## 📍 Vendor Locations
- Koordinat diperbarui setiap 30 detik dari aplikasi Flutter Vendor.
- Customer hanya menarik data vendor yang memiliki `is_active = True`.

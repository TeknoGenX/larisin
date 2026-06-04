# LAMPIRAN 1: TEMPLATE USULAN IDE HACKATHON WEB APPLICATION

**Nama Tim:** [Isi Nama Tim Anda]
**Nama Anggota Tim:**
1. [Nama Ketua] (KETUA)
2. [Nama Anggota 1]
3. [Nama Anggota 2]
**Asal Institusi:** [Nama Perguruan Tinggi Anda]
**Judul Usulan Ide:** **Larisin: Akselerasi Swasembada Ekonomi Mikro melalui Ekosistem Marketplace Mobile Vendor Berbasis Real-Time Tracking dan Secured Transactions**

**Dukungan SDG’s:**
*   **SDG 1: Tanpa Kemiskinan** – Memberdayakan pedagang mikro (sektor informal) untuk mendapatkan kepastian pendapatan melalui digitalisasi pasar.
*   **SDG 9: Industri, Inovasi, dan Infrastruktur** – Membangun infrastruktur digital "Pasar Bergerak" yang menghubungkan produsen lokal langsung ke konsumen.
*   **SDG 7: Energi Bersih dan Terjangkau** – Efisiensi konsumsi BBM pedagang keliling hingga 30-40% melalui optimasi rute berdasarkan permintaan (On-Demand).
*   **SDG 17: Kemitraan untuk Mencapai Tujuan** – Memperkuat sinergi antara pedagang, masyarakat, dan pengelola kawasan dalam satu ekosistem ekonomi mandiri.

---

### 1. LATAR BELAKANG
Sektor pedagang keliling (mobile vendors) di Indonesia merupakan pilar ekonomi kerakyatan yang mendukung swasembada pangan tingkat lokal. Namun, kelompok ini menghadapi dua tantangan sistemik: **Inefisiensi Energi** (berkeliling tanpa rute pasti yang memboroskan BBM) dan **Ketiadaan Visibilitas Digital** (pelanggan sulit menemukan lokasi vendor secara tepat waktu). Di tengah ambisi global menuju swasembada ekonomi, Larisin hadir sebagai jembatan teknologi. Dengan mentransformasi pedagang konvensional menjadi entitas digital yang terpetakan secara real-time, kita tidak hanya menyelamatkan ekonomi mikro, tetapi juga menciptakan ekosistem distribusi lokal yang cerdas dan rendah emisi.

### 2. TUJUAN
1.  **Mewujudkan Swasembada Ekonomi Lokal:** Membangun kemandirian ekonomi kawasan dengan memastikan seluruh kebutuhan pokok masyarakat dapat dipenuhi oleh vendor lokal yang terintegrasi secara digital.
2.  **Menjamin Keamanan Transaksi (Secured Transactions):** Mengimplementasikan sistem transaksi yang *robust* untuk melindungi data dan keuangan pelaku UMKM dari kegagalan sistemik.
3.  **Optimalisasi Rute & Energi:** Mengurangi jejak karbon pedagang dengan memberikan visibilitas titik permintaan pelanggan secara presisi.

### 3. GAMBARAN TEKNOLOGI USULAN
Larisin adalah ekosistem marketplace terintegrasi yang terdiri dari:
*   **Real-Time Tracking Service:** Menggunakan protokol WebSocket (Socket.io) untuk sinkronisasi posisi GPS pedagang ke peta pelanggan secara *live* dengan latensi rendah.
*   **Web Admin & Vendor Dashboard:** Platform berbasis web untuk manajemen stok, analisis statistik penjualan, dan pemantauan kesehatan ekosistem secara terpusat.
*   **Secured Transaction Engine:** Backend yang dirancang khusus untuk menangani pesanan tinggi secara bersamaan dengan integritas data yang ketat.
*   **Multi-Flavor Mobile App:** Aplikasi Android/iOS untuk sisi Vendor dan Customer yang terhubung ke satu *single source of truth*.

### 4. ANALISA TARGET PASAR
*   **Vendor Mikro:** Pedagang sayur keliling, pedagang makanan matang (bakso, roti, jamu), dan penyedia jasa (sol sepatu, perbaikan elektronik).
*   **Konsumen Domestik:** Masyarakat di kawasan perumahan padat, apartemen, dan wilayah rural yang membutuhkan akses cepat ke barang pokok tanpa biaya transportasi tambahan.
*   **Instansi/Kawasan:** Pengelola perumahan atau pemerintah daerah yang ingin mendigitalisasi sektor informal di wilayahnya.

### 5. ANALISA PERBANDINGAN SISTEM EKSISTING DENGAN SISTEM USULAN
| Fitur | Sistem Tradisional / Marketplace Umum | Larisin (Sistem Usulan) |
| :--- | :--- | :--- |
| **Model Distribusi** | Statis (toko fisik) atau Kurir Ekspedisi | **Dinamis (Mobile Vendor)** - Barang menjemput pembeli secara langsung. |
| **Update Lokasi** | Tidak ada / Hanya status pengiriman | **Real-Time Live Tracking** via Peta Interaktif. |
| **Integritas Stok** | Sering terjadi *miss-match* saat pesanan membludak | **Aman** dengan implementasi *Pessimistic Locking* di level database. |
| **Dampak Lingkungan** | Tinggi (rute logistik panjang) | **Rendah** (Optimasi jarak tempuh vendor lokal). |

### 6. TEKNOLOGI YANG DIGUNAKAN (TECH STACK)
*   **Backend:** Python Flask dengan SQLAlchemy ORM.
*   **Database:** PostgreSQL/SQLite dengan implementasi **Pessimistic Locking (`with_for_update()`)** untuk menjamin keamanan transaksi pada kondisi *high-concurrency*.
*   **Real-Time Communication:** **Socket.io** untuk sinkronisasi GPS, Chat, dan Status Pesanan.
*   **Mobile Framework:** Flutter (Provider Pattern) untuk performa UI yang mulus.
*   **Frontend Web:** Jinja2, Tailwind CSS, dan Leaflet.js untuk pemetaan web admin.
*   **Security:** JSON Web Token (JWT) untuk otentikasi aman dan RBAC (Role-Based Access Control).

### 7. LANGKAH-LANGKAH PENGEMBANGAN
1.  **Analisis & Skema ACID:** Merancang database yang mendukung transaksi ACID untuk mencegah *race condition* pada stok barang.
2.  **Socket Integration:** Membangun server WebSocket untuk menangani ribuan koneksi GPS secara simultan.
3.  **Cross-Platform Dev:** Sinkronisasi logika bisnis antara API Backend, Dashboard Web, dan Aplikasi Mobile.
4.  **Security Audit:** Melakukan uji coba transaksi "Double-Booking" untuk memvalidasi efektivitas sistem *locking*.
5.  **Pilot Project:** Implementasi terbatas pada komunitas pedagang keliling untuk mengumpulkan data akurasi rute.

### 8. POTENSI SKALABILITAS KE INDUSTRI F&B MODERN
Larisin dirancang dengan arsitektur yang sangat fleksibel, memungkinkannya untuk diadaptasi tidak hanya bagi mobile vendor, tetapi juga bagi industri F&B yang lebih luas:
*   **Kafe & Restoran (Internal Delivery):** Menghilangkan ketergantungan pada aggregator pihak ketiga dengan mengelola kurir internal yang terpetakan secara real-time.
*   **Chain Stores & Franchise:** Dashboard pusat dapat memantau ribuan cabang sekaligus dengan sinkronisasi stok dan analisis performa per wilayah.
*   **Sistem Pre-Order & Pick-up:** Memungkinkan toko fisik untuk melayani pelanggan secara lebih efisien tanpa penumpukan antrean.
*   **Supply Chain B2B:** Menghubungkan produsen makanan/minuman langsung ke distributor dan retail melalui satu sistem pemesanan yang aman dan terintegrasi.

### 9. RENCANA KEBERLANJUTAN
Larisin dirancang untuk skalabilitas jangka panjang melalui:
*   **AI Route Recommendation:** Pengembangan algoritma pembelajaran mesin untuk menyarankan rute terlaris bagi pedagang berdasarkan data historis.
*   **Financial Inclusion:** Data transaksi digital di Larisin dapat digunakan sebagai skor kredit bagi pedagang mikro untuk mendapatkan bantuan modal usaha.
*   **White-Label Solution:** Memungkinkan pemerintah daerah mengadopsi sistem ini guna mempercepat transformasi swasembada ekonomi digital di tingkat kabupaten/kota.

### 9. DAFTAR PUSTAKA
1.  SQLAlchemy Documentation. (2024). *Pessimistic Locking for Transaction Integrity*.
2.  Socket.io API Reference. (2024). *Real-time bidirectional event-based communication*.
3.  Bappenas Indonesia. (2023). *Strategi Nasional Pengembangan Ekonomi Digital & Swasembada UMKM*.
4.  Flutter.dev. (2024). *State Management and Performance in Multi-Flavor Apps*.

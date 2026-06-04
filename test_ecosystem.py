import requests
import time

BASE_URL = "http://127.0.0.1:5003"

def test_flow():
    print("--- MULAI PENGUJIAN END-TO-END ---")
    ts = int(time.time())
    vendor_username = f"vendor_{ts}"
    customer_username = f"customer_{ts}"

    # 1. Registrasi Vendor
    print(f"\n[1] Registrasi Vendor: {vendor_username}...")
    v_reg = requests.post(f"{BASE_URL}/auth/register", json={
        "username": vendor_username,
        "password": "password123",
        "role": "vendor",
        "ktp_image_url": "https://example.com/ktp.jpg"
    })
    v_reg_data = v_reg.json()
    print(f"Status: {v_reg.status_code}, Msg: {v_reg_data.get('msg')}")
    vendor_id = v_reg_data['user']['id']

    # 2. Login Admin & Verifikasi Vendor
    print("\n[2] Login Admin & Verifikasi Vendor...")
    admin_login = requests.post(f"{BASE_URL}/auth/login", json={
        "username": "admin",
        "password": "password123"
    })
    admin_token = admin_login.json()['access_token']
    
    v_verify = requests.patch(f"{BASE_URL}/admin/verify-vendor/{vendor_id}", 
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"is_verified": True}
    )
    print(f"Verifikasi Status: {v_verify.status_code}, Msg: {v_verify.json().get('msg')}")

    # 3. Vendor Update Stok & Lokasi
    print("\n[3] Vendor Update Stok & Lokasi...")
    v_login_resp = requests.post(f"{BASE_URL}/auth/login", json={
        "username": vendor_username,
        "password": "password123"
    })
    v_login_data = v_login_resp.json()
    v_token = v_login_data['access_token']
    
    # Sync FCM Token (NEW)
    v_fcm = requests.post(f"{BASE_URL}/auth/fcm-token", 
        headers={"Authorization": f"Bearer {v_token}"},
        json={"fcm_token": f"TEST_V_TOKEN_{ts}"}
    )
    print(f"Vendor FCM Sync: {v_fcm.status_code}")
    
    # Ambil daftar produk untuk mendapatkan ID valid
    products_res = requests.get(f"{BASE_URL}/vendor/products",
        headers={"Authorization": f"Bearer {v_token}"}
    )
    products = products_res.json()
    if not products:
        print("Gagal mendapatkan produk untuk update stok!")
        return
    product_id = products[0]['id']
    print(f"Menggunakan produk: {products[0]['name']} (ID: {product_id})")
    
    # Update Stok
    v_stock = requests.post(f"{BASE_URL}/vendor/stock",
        headers={"Authorization": f"Bearer {v_token}"},
        json=[{"product_id": product_id, "quantity": 50}]
    )
    # Update Lokasi
    v_loc = requests.post(f"{BASE_URL}/vendor/location",
        headers={"Authorization": f"Bearer {v_token}"},
        json={"latitude": -6.20, "longitude": 106.81, "is_active": True}
    )
    print(f"Update Stok: {v_stock.status_code}, Update Lokasi: {v_loc.status_code}")

    # 4. Registrasi & Login Customer
    print(f"\n[4] Registrasi & Login Customer: {customer_username}...")
    requests.post(f"{BASE_URL}/auth/register", json={
        "username": customer_username,
        "password": "pembeli123",
        "role": "customer"
    })
    c_login = requests.post(f"{BASE_URL}/auth/login", json={
        "username": customer_username,
        "password": "pembeli123"
    })
    c_login_data = c_login.json()
    c_token = c_login_data['access_token']

    # Sync FCM Token (NEW)
    c_fcm = requests.post(f"{BASE_URL}/auth/fcm-token", 
        headers={"Authorization": f"Bearer {c_token}"},
        json={"fcm_token": f"TEST_C_TOKEN_{ts}"}
    )
    print(f"Customer FCM Sync: {c_fcm.status_code}")

    # 5. Customer Cari Vendor & Checkout
    print("\n[5] Customer Cari Vendor & Checkout...")
    nearby = requests.get(f"{BASE_URL}/customer/nearby-vendors",
        headers={"Authorization": f"Bearer {c_token}"}
    )
    print(f"Vendor Terdekat: {len(nearby.json())} ditemukan.")
    
    order = requests.post(f"{BASE_URL}/order/",
        headers={"Authorization": f"Bearer {c_token}"},
        json={"vendor_id": vendor_id, "items": [{"product_id": product_id, "quantity": 2}]}
    )
    order_id = order.json().get('order_id')
    print(f"Checkout Status: {order.status_code}, Order ID: {order_id}")

    # 5.5 Chat Test (NEW)
    print("\n[5.5] Customer Kirim Chat ke Vendor...")
    chat = requests.post(f"{BASE_URL}/chat/send",
        headers={"Authorization": f"Bearer {c_token}"},
        json={"receiver_id": vendor_id, "message": "Mas, pesanan saya segera diproses ya!"}
    )
    print(f"Chat Status: {chat.status_code}")

    # 6. Vendor Proses & Kirim Pesanan
    print("\n[6] Vendor Proses & Kirim Pesanan...")
    requests.patch(f"{BASE_URL}/vendor/orders/{order_id}/status",
        headers={"Authorization": f"Bearer {v_token}"},
        json={"status": "processing"}
    )
    v_send = requests.patch(f"{BASE_URL}/vendor/orders/{order_id}/status",
        headers={"Authorization": f"Bearer {v_token}"},
        json={"status": "on_delivery"}
    )
    print(f"Status Terakhir Vendor: {v_send.json().get('msg')}")

    # 7. Customer Selesaikan Pesanan & Beri Ulasan
    print("\n[7] Customer Selesaikan Pesanan & Beri Ulasan...")
    c_done = requests.patch(f"{BASE_URL}/order/{order_id}/complete",
        headers={"Authorization": f"Bearer {c_token}"}
    )
    c_review = requests.post(f"{BASE_URL}/customer/review",
        headers={"Authorization": f"Bearer {c_token}"},
        json={"order_id": order_id, "rating": 5, "comment": "Thai Tea-nya enak banget!"}
    )
    print(f"Selesai Status: {c_done.status_code}, Review Status: {c_review.status_code}")

    print("\n--- PENGUJIAN SELESAI & BERHASIL! ---")

if __name__ == "__main__":
    try:
        test_flow()
    except Exception as e:
        print(f"TERJADI ERROR SAAT PENGUJIAN: {e}")

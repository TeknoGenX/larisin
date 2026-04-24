import requests
import time

BASE_URL = "http://127.0.0.1:5002"

def test_flow():
    print("--- MULAI PENGUJIAN END-TO-END ---")

    # 1. Registrasi Vendor
    print("\n[1] Registrasi Vendor...")
    v_reg = requests.post(f"{BASE_URL}/auth/register", json={
        "username": "vendor_test",
        "password": "password123",
        "role": "vendor",
        "ktp_image_url": "https://example.com/ktp.jpg"
    })
    print(f"Status: {v_reg.status_code}, Msg: {v_reg.json().get('msg')}")

    # 2. Login Admin & Verifikasi Vendor
    print("\n[2] Login Admin & Verifikasi Vendor...")
    admin_login = requests.post(f"{BASE_URL}/auth/login", json={
        "username": "admin",
        "password": "password123"
    })
    admin_token = admin_login.json()['access_token']
    vendor_id = v_reg.json()['user']['id']
    
    v_verify = requests.patch(f"{BASE_URL}/admin/verify-vendor/{vendor_id}", 
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"is_verified": True}
    )
    print(f"Verifikasi Status: {v_verify.status_code}, Msg: {v_verify.json().get('msg')}")

    # 3. Vendor Update Stok & Lokasi
    print("\n[3] Vendor Update Stok & Lokasi...")
    v_login = requests.post(f"{BASE_URL}/auth/login", json={
        "username": "vendor_test",
        "password": "password123"
    })
    v_token = v_login.json()['access_token']
    
    # Update Stok untuk Thai Tea (ID 1 dari seeding)
    v_stock = requests.post(f"{BASE_URL}/vendor/stock",
        headers={"Authorization": f"Bearer {v_token}"},
        json=[{"product_id": 1, "quantity": 50}]
    )
    # Update Lokasi
    v_loc = requests.post(f"{BASE_URL}/vendor/location",
        headers={"Authorization": f"Bearer {v_token}"},
        json={"latitude": -6.20, "longitude": 106.81, "is_active": True}
    )
    print(f"Update Stok: {v_stock.status_code}, Update Lokasi: {v_loc.status_code}")

    # 4. Registrasi & Login Customer
    print("\n[4] Registrasi & Login Customer...")
    requests.post(f"{BASE_URL}/auth/register", json={
        "username": "customer_test",
        "password": "pembeli123",
        "role": "customer"
    })
    c_login = requests.post(f"{BASE_URL}/auth/login", json={
        "username": "customer_test",
        "password": "pembeli123"
    })
    c_token = c_login.json()['access_token']

    # 5. Customer Cari Vendor & Checkout
    print("\n[5] Customer Cari Vendor & Checkout...")
    nearby = requests.get(f"{BASE_URL}/customer/nearby-vendors",
        headers={"Authorization": f"Bearer {c_token}"}
    )
    print(f"Vendor Terdekat: {len(nearby.json())} ditemukan.")
    
    order = requests.post(f"{BASE_URL}/order/",
        headers={"Authorization": f"Bearer {c_token}"},
        json={"vendor_id": vendor_id, "items": [{"product_id": 1, "quantity": 2}]}
    )
    order_id = order.json().get('order_id')
    print(f"Checkout Status: {order.status_code}, Order ID: {order_id}")

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

import requests
import threading
import time

BASE_URL = "http://127.0.0.1:5003"

def attempt_checkout(user_idx, vendor_id, product_id):
    # 1. Register & Login Unique User
    username = f"stress_user_{user_idx}_{int(time.time())}"
    requests.post(f"{BASE_URL}/auth/register", json={
        "username": username, "password": "password123", "role": "customer"
    })
    login = requests.post(f"{BASE_URL}/auth/login", json={
        "username": username, "password": "password123"
    })
    token = login.json()['access_token']
    
    # 2. Attempt Checkout
    resp = requests.post(f"{BASE_URL}/order/", 
        headers={"Authorization": f"Bearer {token}"},
        json={"vendor_id": vendor_id, "items": [{"product_id": product_id, "quantity": 1}]}
    )
    print(f"User {user_idx}: Status {resp.status_code} - {resp.json().get('msg', 'Success')}")

def run_stress_test():
    print("\n=== [PHASE 1: PREPARING STRESS TEST] ===")
    # Login Admin to seed data
    admin_login = requests.post(f"{BASE_URL}/auth/login", json={"username": "admin", "password": "password123"})
    admin_token = admin_login.json()['access_token']
    
    # Use existing product ID 1 (Thai Tea) and Vendor ID 1
    vendor_id = 1
    product_id = 1
    
    # Ensure vendor has exactly 5 units for testing race conditions
    requests.post(f"{BASE_URL}/vendor/stock", 
        headers={"Authorization": f"Bearer {admin_token}"}, # Using admin for simplicity in seed
        json=[{"product_id": product_id, "quantity": 5}]
    )
    print("Initial Stock Set to 5 units.")
    
    print("\n=== [PHASE 2: EXECUTING CONCURRENT CHECKOUTS (10 USERS)] ===")
    threads = []
    for i in range(10): # 10 users fighting for 5 items
        t = threading.Thread(target=attempt_checkout, args=(i, vendor_id, product_id))
        threads.append(t)
        t.start()
        
    for t in threads:
        t.join()
        
    print("\n=== [PHASE 3: VERIFYING FINAL STOCK] ===")
    # Check remaining stock
    v_login = requests.post(f"{BASE_URL}/auth/login", json={"username": "admin", "password": "password123"})
    v_token = v_login.json()['access_token']
    
    # Ambil stok via endpoint vendor-stock milik customer karena formatnya lebih sederhana untuk verifikasi ini
    vendor_stock = requests.get(f"{BASE_URL}/customer/vendor-stock/{vendor_id}", 
        headers={"Authorization": f"Bearer {v_token}"}
    ).json()
    
    final_stock = next(s['quantity'] for s in vendor_stock if s['product_id'] == product_id)
    
    print(f"Final Stock: {final_stock}")
    if final_stock >= 0:
        print(f"RESULT: PASS - System consistency maintained. Current stock: {final_stock}")
    else:
        print(f"RESULT: FAIL - Negative stock detected: {final_stock}")

if __name__ == "__main__":
    run_stress_test()

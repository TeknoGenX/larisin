import requests
import time

BASE_URL = "http://127.0.0.1:5003"

def test_tc01_brute_force():
    print("\n--- TC-01: Negative Auth (Wrong Password) ---")
    username = "test_user_qa"
    # Register first
    requests.post(f"{BASE_URL}/auth/register", json={"username": username, "password": "correct_password", "role": "customer"})
    
    for i in range(6):
        resp = requests.post(f"{BASE_URL}/auth/login", json={"username": username, "password": "wrong_password"})
        print(f"Attempt {i+1}: Status {resp.status_code}, Msg: {resp.json().get('msg')}")
        if "locked" in resp.json().get('msg', '').lower():
            print("SUCCESS: Account locked after multiple attempts.")
            return True
    return False

def test_tc02_over_ordering():
    print("\n--- TC-02: Edge Case (Over-ordering) ---")
    # Login as customer
    login_resp = requests.post(f"{BASE_URL}/auth/login", json={"username": "test_user_qa", "password": "correct_password"})
    token = login_resp.json().get('access_token')
    headers = {"Authorization": f"Bearer {token}"}
    
    # Try to order a huge amount (e.g., 999999)
    order_data = {"vendor_id": 1, "items": [{"product_id": 1, "quantity": 999999}]}
    resp = requests.post(f"{BASE_URL}/order/", json=order_data, headers=headers)
    print(f"Status: {resp.status_code}, Msg: {resp.json().get('msg')}")
    if resp.status_code == 400 and "Insufficient stock" in resp.json().get('msg'):
        print("SUCCESS: Over-ordering rejected correctly.")
        return True
    return False

if __name__ == "__main__":
    tc01 = test_tc01_brute_force()
    tc02 = test_tc02_over_ordering()
    
    print(f"\nSummary: TC-01={'PASS' if tc01 else 'FAIL'}, TC-02={'PASS' if tc02 else 'FAIL'}")

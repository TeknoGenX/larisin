import requests

BASE_URL = "http://127.0.0.1:5003"

def test_vendor_stock():
    # Login as customer
    login_res = requests.post(f"{BASE_URL}/auth/login", json={
        "username": "andi_pembeli",
        "password": "pembeli123"
    })
    token = login_res.json()['access_token']
    
    # Get vendor 35
    vendor_id = 35
    
    # Fetch stock
    stock_res = requests.get(f"{BASE_URL}/customer/vendor-stock/{vendor_id}", 
        headers={"Authorization": f"Bearer {token}"}
    )
    print(f"Status Code: {stock_res.status_code}")
    print(f"Stock Data: {stock_res.json()}")

if __name__ == "__main__":
    test_vendor_stock()

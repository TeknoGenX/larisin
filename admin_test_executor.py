import requests

BASE_URL = "http://127.0.0.1:5003"
ADMIN_SESSION = requests.Session()

def test_admin_flow():
    print("\n--- Pengujian Manual: Fitur Admin Dashboard ---")
    
    # 1. Login Admin
    print("[1] Mencoba Login Admin...")
    login_resp = ADMIN_SESSION.post(f"{BASE_URL}/web-admin/login", data={"username": "admin", "password": "password123"})
    if login_resp.status_code == 200 and "Dashboard" in login_resp.text:
        print("    STATUS: PASS (Admin logged in successfully)")
    else:
        print(f"    STATUS: FAIL (Login failed with status {login_resp.status_code})")

    # 2. Check Health Page
    print("[2] Mengecek Halaman System Health...")
    health_resp = ADMIN_SESSION.get(f"{BASE_URL}/web-admin/health")
    if "System Health" in health_resp.text and "CPU Usage" in health_resp.text:
        print("    STATUS: PASS (Health metrics displayed)")
    else:
        print("    STATUS: FAIL (Health metrics missing)")

    # 3. Export CSV
    print("[3] Mengecek Fitur Ekspor CSV Pesanan...")
    export_resp = ADMIN_SESSION.get(f"{BASE_URL}/web-admin/orders/export")
    if export_resp.status_code == 200 and "Order ID" in export_resp.text:
        print("    STATUS: PASS (CSV Export successful and contains data)")
    else:
        print("    STATUS: FAIL (CSV Export failed)")

    # 4. Vendor Verification Logic
    print("[4] Mengecek Navigasi Manajemen Vendor...")
    vendor_resp = ADMIN_SESSION.get(f"{BASE_URL}/web-admin/vendors")
    if "Vendors" in vendor_resp.text:
        print("    STATUS: PASS (Vendor list accessible)")
    else:
        print("    STATUS: FAIL (Vendor list inaccessible)")

if __name__ == "__main__":
    # Ensure admin user exists for testing (admin_password is the default in test environment)
    # This script assumes the server is running.
    test_admin_flow()

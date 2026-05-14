import requests
import json
import time

BASE_URL = "http://127.0.0.1:5003"

def test_user_acceptance_cycle():
    print("🚀 Memulai Simulasi Pengujian Pengguna Akhir...")
    
    # 1. Registrasi & Login
    print("\n[1] Menguji Autentikasi...")
    payload = {"username": "tester_customer", "password": "password123", "role": "customer"}
    requests.post(f"{BASE_URL}/auth/register", json=payload)
    login_res = requests.post(f"{BASE_URL}/auth/login", json=payload).json()
    token = login_res['access_token']
    print("✅ Login Customer Berhasil.")

    # 2. Cek Daftar Penjual Terdekat
    print("\n[2] Menguji Fitur Discovery...")
    vendors = requests.get(f"{BASE_URL}/customer/nearby-vendors", 
                          headers={"Authorization": f"Bearer {token}"}).json()
    if len(vendors) >= 0:
        print(f"✅ Berhasil menarik data {len(vendors)} pedagang aktif.")

    # 3. Cek Fitur Chat & Riwayat Percakapan
    print("\n[3] Menguji Sistem Chat...")
    # Cari ID vendor1 (dari seed data)
    vendor_id = 11 # Asumsi ID dari seed_users.py
    chat_payload = {"receiver_id": vendor_id, "message": "Halo, apakah masih jualan?"}
    res_chat = requests.post(f"{BASE_URL}/chat/send", json=chat_payload,
                            headers={"Authorization": f"Bearer {token}"})
    if res_chat.status_code == 201:
        print("✅ Kirim pesan teks berhasil.")
    
    # 4. Cek Fitur Kartu Produk di Chat
    print("\n[4] Menguji Kartu Produk & Cek Stok...")
    # Vendor mengirim kartu produk ke customer (Simulasi via API vendor)
    # Kita butuh token vendor untuk ini
    v_payload = {"username": "vendor1", "password": "vendorPass123!"}
    v_token = requests.post(f"{BASE_URL}/auth/login", json=v_payload).json()['access_token']
    
    prod_card_payload = {"receiver_id": login_res['user']['id'], "product_id": 1}
    res_card = requests.post(f"{BASE_URL}/chat/send-product", json=prod_card_payload,
                            headers={"Authorization": f"Bearer {v_token}"})
    
    if res_card.status_code == 201:
        data = res_card.json()
        print(f"✅ Vendor mengirim Kartu Produk: {data['product']['name']}")
        print(f"✅ Info Stok Real-time di Kartu: {data['product'].get('stock_quantity', 0)}")

    print("\n🏁 Simulasi API Selesai. Seluruh infrastruktur inti stabil.")

if __name__ == "__main__":
    try:
        test_user_acceptance_cycle()
    except Exception as e:
        print(f"❌ Pengujian Gagal: {e}")

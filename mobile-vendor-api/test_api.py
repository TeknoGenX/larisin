import json
import pytest
import os
from app import create_app, db
from app.models import User, Product, DailyStock

# Test credentials from environment variables with defaults
TEST_VENDOR_PASSWORD = os.getenv('TEST_VENDOR_PASSWORD', 'password123')
TEST_CUSTOMER_PASSWORD = os.getenv('TEST_CUSTOMER_PASSWORD', 'pembeli123')
TEST_ADMIN_PASSWORD = os.getenv('TEST_ADMIN_PASSWORD', 'password123')

@pytest.fixture
def client():
    app = create_app()
    db_path = f"test_{os.getpid()}.db"
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'
    app.config['JWT_SECRET_KEY'] = 'test-secret'
    
    with app.test_client() as client:
        with app.app_context():
            db.create_all()
            p = Product(name="Thai Tea", price=10000)
            db.session.add(p)
            admin = User(username="admin_final", role="admin", is_verified=True)
            admin.set_password(TEST_ADMIN_PASSWORD)
            db.session.add(admin)
            db.session.commit()
            global_product_id = p.id
        yield client, global_product_id
        with app.app_context():
            db.session.remove()
            db.drop_all()
    if os.path.exists(db_path):
        os.remove(db_path)

def test_full_business_flow(client):
    client, product_id = client
    # 1. Register Vendor
    res = client.post('/auth/register', json={"username": "v_final", "password": TEST_VENDOR_PASSWORD, "role": "vendor"})
    assert res.status_code == 201
    vendor_id = res.get_json()['user']['id']

    # 2. Login Admin
    login_res = client.post('/auth/login', json={"username": "admin_final", "password": TEST_ADMIN_PASSWORD})
    assert login_res.status_code == 200
    admin_token = login_res.get_json()['access_token']

    # 3. Verify Vendor
    res = client.patch(f'/admin/verify-vendor/{vendor_id}', 
                      headers={"Authorization": f"Bearer {admin_token}"},
                      json={"is_verified": True})
    assert res.status_code == 200

    # 4. Vendor Login & Update Stock
    login_res = client.post('/auth/login', json={"username": "v_final", "password": TEST_VENDOR_PASSWORD})
    v_token = login_res.get_json()['access_token']
    res = client.post('/vendor/stock', headers={"Authorization": f"Bearer {v_token}"}, 
                     json=[{"product_id": product_id, "quantity": 10}])
    assert res.status_code == 200
    # 5. Customer Flow (Register -> Login -> Order)
    client.post('/auth/register', json={"username": "c_final", "password": TEST_CUSTOMER_PASSWORD, "role": "customer"})
    login_res = client.post('/auth/login', json={"username": "c_final", "password": TEST_CUSTOMER_PASSWORD})
    c_token = login_res.get_json()['access_token']
    
    res = client.post('/order/', headers={"Authorization": f"Bearer {c_token}"},
                     json={"vendor_id": vendor_id, "items": [{"product_id": 1, "quantity": 2}]})
    assert res.status_code == 201
    order_id = res.get_json()['order_id']

    # 6. Status Update to Delivered
    # Vendor: Processing -> On Delivery
    client.patch(f'/vendor/orders/{order_id}/status', headers={"Authorization": f"Bearer {v_token}"}, json={"status": "processing"})
    client.patch(f'/vendor/orders/{order_id}/status', headers={"Authorization": f"Bearer {v_token}"}, json={"status": "on_delivery"})
    
    # Customer: Complete
    res = client.patch(f'/order/{order_id}/complete', headers={"Authorization": f"Bearer {c_token}"})
    assert res.status_code == 200
    
    # 7. Final Check Stock
    with client.application.app_context():
        stock = DailyStock.query.filter_by(vendor_id=vendor_id, product_id=1).first()
        assert stock.quantity == 8
    
    print("\n\n✅ [TEST PASSED] Seluruh Alur Bisnis Backend Berfungsi Sempurna!")

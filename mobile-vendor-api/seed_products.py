from app import create_app
from app.models import db, Product

app = create_app()

products_data = [
    {"name": "Thai Tea", "price": 10000, "description": "Minuman teh khas Thailand"},
    {"name": "Green Tea", "price": 10000, "description": "Teh hijau segar"},
    {"name": "Kopling (Kopi Keliling)", "price": 10000, "description": "Kopi susu nikmat"},
    {"name": "Jasmine Tea", "price": 6000, "description": "Teh melati harum"},
    {"name": "Lemon Tea", "price": 8000, "description": "Teh lemon menyegarkan"},
    {"name": "Matcha Latte", "price": 14000, "description": "Green tea premium dengan susu"},
    {"name": "Beng-Beng Drink", "price": 12000, "description": "Coklat Beng-Beng cair"},
    {"name": "Taro Latte", "price": 12000, "description": "Rasa taro yang creamy"},
    {"name": "Kopi Coklat", "price": 13000, "description": "Perpaduan kopi dan coklat"}
]

with app.app_context():
    for p in products_data:
        existing = Product.query.filter_by(name=p['name']).first()
        if not existing:
            new_product = Product(name=p['name'], price=p['price'], description=p['description'])
            db.session.add(new_product)
    
    db.session.commit()
    print("Katalog produk berhasil di-seed!")

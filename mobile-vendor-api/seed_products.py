from app import create_app
from app.models import db, Product

app = create_app()

products_data = [
    # Beverages (Haus!)
    {"name": "Thai Tea", "price": 10000, "description": "Minuman teh khas Thailand", "category": "Haus!"},
    {"name": "Green Tea", "price": 10000, "description": "Teh hijau segar", "category": "Haus!"},
    {"name": "Kopling (Kopi Keliling)", "price": 10000, "description": "Kopi susu nikmat", "category": "Haus!"},
    {"name": "Jasmine Tea", "price": 6000, "description": "Teh melati harum", "category": "Haus!"},
    {"name": "Lemon Tea", "price": 8000, "description": "Teh lemon menyegarkan", "category": "Haus!"},
    {"name": "Matcha Latte", "price": 14000, "description": "Green tea premium dengan susu", "category": "Haus!"},
    {"name": "Beng-Beng Drink", "price": 12000, "description": "Coklat Beng-Beng cair", "category": "Haus!"},
    {"name": "Taro Latte", "price": 12000, "description": "Rasa taro yang creamy", "category": "Haus!"},
    {"name": "Kopi Coklat", "price": 13000, "description": "Perpaduan kopi dan coklat", "category": "Haus!"},
    
    # Food/Toast (Ganjel Roti)
    {"name": "Roti Bakar Coklat", "price": 15000, "description": "Roti panggang dengan filling coklat melimpah", "category": "Ganjel Roti"},
    {"name": "Roti Bakar Keju", "price": 15000, "description": "Roti panggang dengan keju cheddar parut", "category": "Ganjel Roti"},
    {"name": "Roti Bakar Srikaya", "price": 14000, "description": "Roti panggang selai srikaya khas", "category": "Ganjel Roti"},

    # Snacks (Pedes Cyin)
    {"name": "Makaroni Pedas", "price": 10000, "description": "Makaroni goreng renyah bumbu pedas", "category": "Pedes Cyin"},
    {"name": "Basreng Pedas", "price": 12000, "description": "Bakso goreng iris dengan bumbu cabai asli", "category": "Pedes Cyin"},

    # Noodles (Hot Oppa)
    {"name": "Mie Pedas Korea", "price": 18000, "description": "Mie instan pedas gaya Korea dengan topping telur", "category": "Hot Oppa"}
]

with app.app_context():
    for p in products_data:
        existing = Product.query.filter_by(name=p['name']).first()
        if existing:
            # Update existing product with category
            existing.category = p['category']
            existing.price = p['price']
            existing.description = p['description']
        else:
            new_product = Product(
                name=p['name'], 
                price=p['price'], 
                description=p['description'],
                category=p['category']
            )
            db.session.add(new_product)
    
    db.session.commit()
    print("Katalog produk (Haus!, Ganjel Roti, Pedes Cyin, Hot Oppa) berhasil di-seed!")

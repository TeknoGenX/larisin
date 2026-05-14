from app import create_app, db
from app.models import User, Product, DailyStock, Order, OrderItem, Review, ChatMessage, AuditLog

app = create_app()
with app.app_context():
    print("Creating all tables...")
    db.create_all()
    print("Tables created successfully.")

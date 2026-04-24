from datetime import datetime, timedelta, timezone
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy_serializer import SerializerMixin
from werkzeug.security import generate_password_hash, check_password_hash

db = SQLAlchemy()

# Foreign key constants
USERS_ID_FK = 'users.id'

class User(db.Model, SerializerMixin):
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)
    role = db.Column(db.String(20), nullable=False) # admin, vendor, customer
    
    # Security fields
    is_verified = db.Column(db.Boolean, default=False) # For Vendor KYC
    ktp_image_url = db.Column(db.String(255), nullable=True)
    failed_login_attempts = db.Column(db.Integer, default=0)
    locked_until = db.Column(db.DateTime, nullable=True)
    
    # Profile / GPS
    latitude = db.Column(db.Float, nullable=True)
    longitude = db.Column(db.Float, nullable=True)
    is_active = db.Column(db.Boolean, default=True) # Toggle for vendors
    fcm_token = db.Column(db.String(255), nullable=True)

    serialize_only = ('id', 'username', 'role', 'is_verified', 'latitude', 'longitude', 'is_active')

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class Product(db.Model, SerializerMixin):
    __tablename__ = 'products'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text, nullable=True)
    price = db.Column(db.Integer, nullable=False) # In IDR
    image_url = db.Column(db.String(255), nullable=True)
    
    serialize_only = ('id', 'name', 'description', 'price', 'image_url')

class DailyStock(db.Model, SerializerMixin):
    __tablename__ = 'daily_stocks'
    
    id = db.Column(db.Integer, primary_key=True)
    vendor_id = db.Column(db.Integer, db.ForeignKey(USERS_ID_FK), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id'), nullable=False)
    quantity = db.Column(db.Integer, default=0)
    date = db.Column(db.Date, default=lambda: datetime.now(timezone.utc).date())
    
    vendor = db.relationship('User', backref=db.backref('stocks', lazy=True))
    product = db.relationship('Product', backref=db.backref('daily_stocks', lazy=True))

    serialize_only = ('id', 'product_id', 'quantity', 'date')

class Order(db.Model, SerializerMixin):
    __tablename__ = 'orders'
    
    id = db.Column(db.Integer, primary_key=True)
    customer_id = db.Column(db.Integer, db.ForeignKey(USERS_ID_FK), nullable=False)
    vendor_id = db.Column(db.Integer, db.ForeignKey(USERS_ID_FK), nullable=False)
    total_price = db.Column(db.Integer, nullable=False)
    status = db.Column(db.String(20), default='pending') # pending, paid, processing, on_delivery, delivered
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    items = db.relationship('OrderItem', backref='order', lazy=True)
    
    customer = db.relationship('User', foreign_keys=[customer_id])
    vendor = db.relationship('User', foreign_keys=[vendor_id])

    serialize_only = ('id', 'customer_id', 'vendor_id', 'total_price', 'status', 'created_at', 'items')

class OrderItem(db.Model, SerializerMixin):
    __tablename__ = 'order_items'
    
    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id'), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    price_at_order = db.Column(db.Integer, nullable=False)
    
    product = db.relationship('Product')

    serialize_only = ('id', 'product_id', 'quantity', 'price_at_order')

class Review(db.Model, SerializerMixin):
    __tablename__ = 'reviews'
    
    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id'), unique=True, nullable=False)
    customer_id = db.Column(db.Integer, db.ForeignKey(USERS_ID_FK), nullable=False)
    vendor_id = db.Column(db.Integer, db.ForeignKey(USERS_ID_FK), nullable=False)
    rating = db.Column(db.Integer, nullable=False) # 1-5
    comment = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    serialize_only = ('id', 'rating', 'comment', 'created_at')

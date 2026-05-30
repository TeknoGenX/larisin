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
    store_image_url = db.Column(db.String(255), nullable=True)
    failed_login_attempts = db.Column(db.Integer, default=0)
    locked_until = db.Column(db.DateTime, nullable=True)
    
    # Profile / GPS
    latitude = db.Column(db.Float, nullable=True)
    longitude = db.Column(db.Float, nullable=True)
    is_active = db.Column(db.Boolean, default=True) # Toggle for vendors
    fcm_token = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    serialize_only = ('id', 'username', 'role', 'is_verified', 'latitude', 'longitude', 'is_active', 'created_at')

    def to_dict(self):
        return {
            "id": self.id,
            "username": self.username,
            "role": self.role,
            "is_verified": self.is_verified,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "is_active": self.is_active,
            "ktp_image_url": self.ktp_image_url,
            "store_image_url": self.store_image_url,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class Product(db.Model, SerializerMixin):
    __tablename__ = 'products'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text, nullable=True)
    category = db.Column(db.String(50), nullable=True, default='Haus!') # Added for branding/grouping
    price = db.Column(db.Integer, nullable=False) # In IDR
    image_url = db.Column(db.String(255), nullable=True)
    
    # Relationships with cascade delete
    stocks = db.relationship('DailyStock', backref='product', cascade='all, delete-orphan', lazy=True)
    order_items = db.relationship('OrderItem', backref='product', cascade='all, delete-orphan', lazy=True)

    serialize_only = ('id', 'name', 'description', 'category', 'price', 'image_url')

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "description": self.description,
            "category": self.category,
            "price": self.price,
            "image_url": self.image_url
        }

class DailyStock(db.Model, SerializerMixin):
    __tablename__ = 'daily_stocks'
    
    id = db.Column(db.Integer, primary_key=True)
    vendor_id = db.Column(db.Integer, db.ForeignKey(USERS_ID_FK), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id'), nullable=False)
    quantity = db.Column(db.Integer, default=0)
    date = db.Column(db.Date, default=lambda: datetime.now(timezone.utc).date())
    
    vendor = db.relationship('User', backref=db.backref('stocks', lazy=True))

    serialize_only = ('id', 'product_id', 'quantity', 'date')

class Order(db.Model, SerializerMixin):
    __tablename__ = 'orders'
    
    id = db.Column(db.Integer, primary_key=True)
    customer_id = db.Column(db.Integer, db.ForeignKey(USERS_ID_FK), nullable=False)
    vendor_id = db.Column(db.Integer, db.ForeignKey(USERS_ID_FK), nullable=False)
    total_price = db.Column(db.Integer, nullable=False)
    status = db.Column(db.String(20), default='pending') # pending, paid, processing, on_delivery, delivered
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    
    items = db.relationship('OrderItem', backref='order', lazy=True)
    
    customer = db.relationship('User', foreign_keys=[customer_id])
    vendor = db.relationship('User', foreign_keys=[vendor_id])

    serialize_only = ('id', 'customer_id', 'vendor_id', 'total_price', 'status', 'created_at', 'items')

    def to_dict(self):
        return {
            "id": self.id,
            "customer_id": self.customer_id,
            "vendor_id": self.vendor_id,
            "total_price": self.total_price,
            "status": self.status,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "items": [item.to_dict() for item in self.items]
        }

class OrderItem(db.Model, SerializerMixin):
    __tablename__ = 'order_items'
    
    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id'), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    price_at_order = db.Column(db.Integer, nullable=False)
    
    serialize_only = ('id', 'product_id', 'quantity', 'price_at_order')

    def to_dict(self):
        return {
            "id": self.id,
            "product_id": self.product_id,
            "quantity": self.quantity,
            "price_at_order": self.price_at_order,
            "product_name": self.product.name if self.product else None
        }

class Review(db.Model, SerializerMixin):
    __tablename__ = 'reviews'
    
    id = db.Column(db.Integer, primary_key=True)
    order_id = db.Column(db.Integer, db.ForeignKey('orders.id'), unique=True, nullable=False)
    customer_id = db.Column(db.Integer, db.ForeignKey(USERS_ID_FK), nullable=False)
    vendor_id = db.Column(db.Integer, db.ForeignKey(USERS_ID_FK), nullable=False)
    rating = db.Column(db.Integer, nullable=False) # 1-5
    comment = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    
    serialize_only = ('id', 'rating', 'comment', 'created_at')

    def to_dict(self):
        return {
            "id": self.id,
            "rating": self.rating,
            "comment": self.comment,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }

class AuditLog(db.Model, SerializerMixin):
    __tablename__ = 'audit_logs'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey(USERS_ID_FK), nullable=True) # Who performed the action
    action = db.Column(db.String(100), nullable=False) # e.g., 'APPROVE_VENDOR', 'DELETE_PRODUCT'
    target_type = db.Column(db.String(50), nullable=True) # e.g., 'User', 'Product'
    target_id = db.Column(db.Integer, nullable=True)
    details = db.Column(db.Text, nullable=True) # JSON or string details
    ip_address = db.Column(db.String(45), nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    user = db.relationship('User', backref=db.backref('audit_logs', lazy=True))

    def to_dict(self):
        return {
            "id": self.id,
            "user": self.user.username if self.user else "System",
            "action": self.action,
            "target": f"{self.target_type} #{self.target_id}" if self.target_type else "-",
            "details": self.details,
            "created_at": self.created_at.isoformat()
        }

class ChatMessage(db.Model, SerializerMixin):
    __tablename__ = 'chat_messages'
    
    id = db.Column(db.Integer, primary_key=True)
    sender_id = db.Column(db.Integer, db.ForeignKey(USERS_ID_FK), nullable=False)
    receiver_id = db.Column(db.Integer, db.ForeignKey(USERS_ID_FK), nullable=False)
    message = db.Column(db.Text, nullable=True)
    message_type = db.Column(db.String(20), default='text')
    media_url = db.Column(db.String(255), nullable=True)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id'), nullable=True)
    is_read = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))

    sender = db.relationship('User', foreign_keys=[sender_id], backref='sent_messages')
    receiver = db.relationship('User', foreign_keys=[receiver_id], backref='received_messages')
    product = db.relationship('Product')

    def to_dict(self):
        product_data = self.product.to_dict() if self.product else None
        if product_data and self.product_id:
            # Find the vendor in this conversation to get their stock
            vendor = User.query.filter(User.id.in_([self.sender_id, self.receiver_id]), User.role == 'vendor').first()
            if vendor:
                stock = DailyStock.query.filter_by(
                    vendor_id=vendor.id, 
                    product_id=self.product_id, 
                    date=datetime.now(timezone.utc).date()
                ).first()
                product_data['stock_quantity'] = stock.quantity if stock else 0

        return {
            "id": self.id,
            "sender_id": self.sender_id,
            "sender_name": self.sender.username,
            "receiver_id": self.receiver_id,
            "message": self.message,
            "message_type": self.message_type,
            "media_url": self.media_url,
            "product_id": self.product_id,
            "product": product_data,
            "is_read": self.is_read,
            "created_at": self.created_at.isoformat()
        }

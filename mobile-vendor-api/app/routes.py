from flask import Blueprint, jsonify, request
from .models import db, User, Product, DailyStock, Order, OrderItem, Review
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity, verify_jwt_in_request, get_jwt
from functools import wraps
from datetime import datetime, timedelta, timezone

auth_bp = Blueprint('auth', __name__)
admin_bp = Blueprint('admin', __name__)
vendor_bp = Blueprint('vendor', __name__)
customer_bp = Blueprint('customer', __name__)
order_bp = Blueprint('order', __name__)

# RBAC Decorator
def role_required(role):
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            verify_jwt_in_request()
            claims = get_jwt()
            if claims.get("role") != role:
                return jsonify({"msg": "Forbidden"}), 403
            return f(*args, **kwargs)
        return decorated_function
    return decorator

@auth_bp.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    role = data.get('role', 'customer') # Default to customer
    
    if role == 'admin':
        return jsonify({"msg": "Admin registration is not allowed"}), 400
    
    if User.query.filter_by(username=username).first():
        return jsonify({"msg": "Username already exists"}), 400
    
    user = User(username=username, role=role)
    user.set_password(password)
    
    if role == 'vendor':
        user.ktp_image_url = data.get('ktp_image_url')
        user.is_verified = False # Must be approved by admin
        
    db.session.add(user)
    db.session.commit()
    
    return jsonify({"msg": "User created successfully", "user": user.to_dict()}), 201

@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    user = User.query.filter_by(username=username).first()
    
    if not user:
        return jsonify({"msg": "Invalid username or password"}), 401
    
    # Check if account is locked
    if user.locked_until and user.locked_until > datetime.now(timezone.utc):
        return jsonify({"msg": f"Account locked until {user.locked_until}"}), 403
    
    if user.check_password(password):
        # Reset failed attempts
        user.failed_login_attempts = 0
        user.locked_until = None
        db.session.commit()
        
        access_token = create_access_token(identity=user.id, additional_claims={"role": user.role})
        return jsonify(access_token=access_token, user=user.to_dict()), 200
    else:
        # Increment failed attempts
        user.failed_login_attempts += 1
        if user.failed_login_attempts >= 5:
            user.locked_until = datetime.now(timezone.utc) + timedelta(minutes=15)
        db.session.commit()
        return jsonify({"msg": "Invalid username or password"}), 401

# --- Admin Routes ---
@admin_bp.route('/products', methods=['POST'])
@role_required('admin')
def add_product():
    data = request.get_json()
    product = Product(
        name=data['name'],
        description=data.get('description'),
        price=data['price'],
        image_url=data.get('image_url')
    )
    db.session.add(product)
    db.session.commit()
    return jsonify({"msg": "Product added", "product": product.to_dict()}), 201

@admin_bp.route('/pending-vendors', methods=['GET'])
@role_required('admin')
def get_pending_vendors():
    vendors = User.query.filter_by(role='vendor', is_verified=False).all()
    return jsonify([v.to_dict() for v in vendors]), 200

@admin_bp.route('/verify-vendor/<int:user_id>', methods=['PATCH'])
@role_required('admin')
def verify_vendor(user_id):
    user = User.query.get_or_404(user_id)
    if user.role != 'vendor':
        return jsonify({"msg": "User is not a vendor"}), 400
    
    data = request.get_json()
    is_verified = data.get('is_verified', True)
    user.is_verified = is_verified
    db.session.commit()
    return jsonify({"msg": f"Vendor {user.username} verification status updated to {is_verified}"}), 200

# --- Vendor Routes ---
@vendor_bp.route('/products', methods=['GET'])
@jwt_required()
def list_products():
    products = Product.query.all()
    return jsonify([p.to_dict() for p in products]), 200

@vendor_bp.route('/stock', methods=['POST'])
@role_required('vendor')
def update_stock():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user.is_verified:
        return jsonify({"msg": "Vendor not verified"}), 403
        
    data = request.get_json() # List of {product_id, quantity}
    for item in data:
        stock = DailyStock.query.filter_by(vendor_id=user_id, product_id=item['product_id'], date=datetime.now(timezone.utc).date()).first()
        if stock:
            stock.quantity = item['quantity']
        else:
            stock = DailyStock(vendor_id=user_id, product_id=item['product_id'], quantity=item['quantity'])
            db.session.add(stock)
    
    db.session.commit()
    return jsonify({"msg": "Stock updated successfully"}), 200

@vendor_bp.route('/location', methods=['POST'])
@role_required('vendor')
def update_location():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user.is_verified:
        return jsonify({"msg": "Vendor not verified"}), 403
        
    data = request.get_json()
    user.latitude = data.get('latitude')
    user.longitude = data.get('longitude')
    user.is_active = data.get('is_active', True)
    
    db.session.commit()
    return jsonify({"msg": "Location updated successfully"}), 200

@vendor_bp.route('/orders', methods=['GET'])
@role_required('vendor')
def vendor_orders():
    user_id = get_jwt_identity()
    orders = Order.query.filter_by(vendor_id=user_id).order_by(Order.created_at.desc()).all()
    return jsonify([o.to_dict() for o in orders]), 200

@vendor_bp.route('/orders/<int:order_id>/status', methods=['PATCH'])
@role_required('vendor')
def update_order_status(order_id):
    user_id = get_jwt_identity()
    order = Order.query.filter_by(id=order_id, vendor_id=user_id).first_or_404()
    
    data = request.get_json()
    new_status = data.get('status')
    
    # Validasi transisi status sederhana
    valid_statuses = ['processing', 'on_delivery', 'delivered']
    if new_status not in valid_statuses:
        return jsonify({"msg": "Invalid status"}), 400
        
    order.status = new_status
    db.session.commit()
    return jsonify({"msg": f"Order status updated to {new_status}", "order": order.to_dict()}), 200

# --- Customer Routes ---
@customer_bp.route('/nearby-vendors', methods=['GET'])
@role_required('customer')
def nearby_vendors():
    # Return all active verified vendors
    vendors = User.query.filter_by(role='vendor', is_verified=True, is_active=True).all()
    return jsonify([v.to_dict() for v in vendors]), 200

@customer_bp.route('/vendor-stock/<int:vendor_id>', methods=['GET'])
@role_required('customer')
def get_vendor_stock(vendor_id):
    stocks = DailyStock.query.filter_by(
        vendor_id=vendor_id, 
        date=datetime.now(timezone.utc).date()
    ).all()
    
    result = []
    for s in stocks:
        result.append({
            "product_id": s.product_id,
            "name": s.product.name,
            "price": s.product.price,
            "quantity": s.quantity,
            "image_url": s.product.image_url
        })
    return jsonify(result), 200

# --- Order Routes ---
@order_bp.route('/', methods=['POST'])
@role_required('customer')
def create_order():
    user_id = get_jwt_identity()
    data = request.get_json()
    vendor_id = data.get('vendor_id')
    items = data.get('items') # List of {product_id, quantity}
    
    total_price = 0
    order_items_to_add = []
    
    try:
        # 1. Lock and Verify Stock
        for item in items:
            product = Product.query.get(item['product_id'])
            if not product:
                return jsonify({"msg": f"Product {item['product_id']} not found"}), 404
                
            # Pessimistic Locking on the stock row
            stock = DailyStock.query.filter_by(
                vendor_id=vendor_id, 
                product_id=item['product_id'], 
                date=datetime.now(timezone.utc).date()
            ).with_for_update().first()
            
            if not stock or stock.quantity < item['quantity']:
                db.session.rollback()
                return jsonify({"msg": f"Insufficient stock for {product.name}"}), 400
            
            # Deduct stock
            stock.quantity -= item['quantity']
            
            # Calculate price
            item_total = product.price * item['quantity']
            total_price += item_total
            
            # Prepare OrderItem
            order_items_to_add.append(OrderItem(
                product_id=item['product_id'],
                quantity=item['quantity'],
                price_at_order=product.price
            ))
            
        # 2. Create Order
        new_order = Order(
            customer_id=user_id,
            vendor_id=vendor_id,
            total_price=total_price,
            status='paid'
        )
        db.session.add(new_order)
        db.session.flush() # Get order ID
        
        for oi in order_items_to_add:
            oi.order_id = new_order.id
            db.session.add(oi)
            
        db.session.commit()
        return jsonify({"msg": "Order created successfully", "order_id": new_order.id}), 201
        
    except Exception as e:
        db.session.rollback()
        return jsonify({"msg": "Order failed", "error": str(e)}), 500

@order_bp.route('/history', methods=['GET'])
@jwt_required()
def order_history():
    user_id = get_jwt_identity()
    claims = get_jwt()
    role = claims.get("role")
    
    if role == 'customer':
        orders = Order.query.filter_by(customer_id=user_id).order_by(Order.created_at.desc()).all()
    elif role == 'vendor':
        orders = Order.query.filter_by(vendor_id=user_id).order_by(Order.created_at.desc()).all()
    else:
        orders = Order.query.order_by(Order.created_at.desc()).all()
        
    return jsonify([o.to_dict() for o in orders]), 200

@order_bp.route('/<int:order_id>/complete', methods=['PATCH'])
@role_required('customer')
def complete_order(order_id):
    user_id = get_jwt_identity()
    order = Order.query.filter_by(id=order_id, customer_id=user_id).first_or_404()
    
    if order.status != 'on_delivery':
        return jsonify({"msg": "Hanya pesanan dalam pengiriman yang bisa diselesaikan"}), 400
        
    order.status = 'delivered'
    db.session.commit()
    return jsonify({"msg": "Pesanan selesai", "order": order.to_dict()}), 200

# --- Review Routes ---
@customer_bp.route('/review', methods=['POST'])
@role_required('customer')
def submit_review():
    user_id = get_jwt_identity()
    data = request.get_json()
    order_id = data.get('order_id')
    
    # Validasi pesanan
    order = Order.query.get_or_404(order_id)
    if order.customer_id != user_id or order.status != 'delivered':
        return jsonify({"msg": "Tidak dapat memberikan ulasan untuk pesanan ini"}), 400
    
    # Cek ulasan ganda
    existing = Review.query.filter_by(order_id=order_id).first()
    if existing:
        return jsonify({"msg": "Ulasan sudah pernah diberikan"}), 400
        
    review = Review(
        order_id=order_id,
        customer_id=user_id,
        vendor_id=order.vendor_id,
        rating=data.get('rating'),
        comment=data.get('comment')
    )
    db.session.add(review)
    db.session.commit()
    return jsonify({"msg": "Ulasan berhasil dikirim", "review": review.to_dict()}), 201

@customer_bp.route('/vendor-reviews/<int:vendor_id>', methods=['GET'])
@jwt_required()
def get_vendor_reviews(vendor_id):
    reviews = Review.query.filter_by(vendor_id=vendor_id).order_by(Review.created_at.desc()).all()
    return jsonify([r.to_dict() for r in reviews]), 200

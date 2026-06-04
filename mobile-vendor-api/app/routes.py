from flask import Blueprint, jsonify, request
from .models import db, User, Product, DailyStock, Order, OrderItem, Review, ChatMessage
from . import limiter
from flask_jwt_extended import create_access_token, jwt_required, get_jwt_identity, verify_jwt_in_request, get_jwt
from functools import wraps
from datetime import datetime, timedelta, timezone
from sqlalchemy import or_, case, func

auth_bp = Blueprint('auth', __name__)
admin_bp = Blueprint('admin', __name__)
vendor_bp = Blueprint('vendor', __name__)
customer_bp = Blueprint('customer', __name__)
order_bp = Blueprint('order', __name__)
chat_bp = Blueprint('chat', __name__)

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

@auth_bp.route('/fcm-token', methods=['POST'])
@jwt_required()
def update_fcm_token():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    data = request.get_json()
    token = data.get('fcm_token')
    
    if not token:
        return jsonify({"msg": "Token is required"}), 400
        
    user.fcm_token = token
    db.session.commit()
    return jsonify({"msg": "FCM token updated successfully"}), 200

@auth_bp.route('/register', methods=['POST'])
@limiter.limit("5 per minute")
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
@limiter.limit("5 per minute")
def login():
    data = request.get_json()
    username = data.get('username')
    password = data.get('password')
    
    user = User.query.filter_by(username=username).first()
    
    if not user:
        return jsonify({"msg": "Invalid username or password"}), 401
    
    # Check if account is locked
    if user.locked_until:
        # Normalize to aware for comparison
        locked_until = user.locked_until.replace(tzinfo=timezone.utc) if user.locked_until.tzinfo is None else user.locked_until
        now = datetime.now(timezone.utc)
        
        if locked_until > now:
            return jsonify({"msg": f"Account locked until {user.locked_until.isoformat()}"}), 403
    
    if user.check_password(password):
        # Reset failed attempts
        user.failed_login_attempts = 0
        user.locked_until = None
        db.session.commit()
        
        access_token = create_access_token(identity=str(user.id), additional_claims={"role": user.role})
        return jsonify(access_token=access_token, user=user.to_dict()), 200
    else:
        # Increment failed attempts
        user.failed_login_attempts += 1
        if user.failed_login_attempts >= 5:
            # Store as naive UTC (SQLite best practice)
            user.locked_until = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(minutes=15)
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
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    products = Product.query.all()
    
    today = datetime.now(timezone.utc).date()
    result = []
    for p in products:
        d = p.to_dict()
        if user and user.role == 'vendor':
            stock = DailyStock.query.filter_by(
                vendor_id=user_id, 
                product_id=p.id, 
                date=today
            ).first()
            d['current_stock'] = stock.quantity if stock else 0
        result.append(d)
        
    return jsonify(result), 200

@vendor_bp.route('/stock', methods=['POST'])
@role_required('vendor')
def update_stock():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user.is_verified:
        return jsonify({"msg": "Vendor not verified"}), 403
        
    data = request.get_json() # List of {product_id, quantity}
    for item in data:
        product = Product.query.get(item['product_id'])
        if not product:
            return jsonify({"msg": f"Product {item['product_id']} not found"}), 404
            
        stock = DailyStock.query.filter_by(
            vendor_id=user_id, 
            product_id=item['product_id'], 
            date=datetime.now(timezone.utc).date()
        ).with_for_update().first()
        if stock:
            stock.quantity = item['quantity']
        else:
            stock = DailyStock(vendor_id=user_id, product_id=item['product_id'], quantity=item['quantity'])
            db.session.add(stock)
    
    db.session.commit()
    return jsonify({"msg": "Stock updated successfully"}), 200

@vendor_bp.route('/stock/my', methods=['GET'])
@role_required('vendor')
def get_my_stock():
    user_id = get_jwt_identity()
    stocks = DailyStock.query.filter_by(
        vendor_id=user_id, 
        date=datetime.now(timezone.utc).date()
    ).all()
    
    result = []
    for s in stocks:
        result.append({
            "product_id": s.product_id,
            "name": s.product.name,
            "quantity": s.quantity,
            "price": s.product.price
        })
    return jsonify(result), 200

@vendor_bp.route('/location', methods=['POST'])
@role_required('vendor')
def update_location():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    if not user.is_verified:
        return jsonify({"msg": "Vendor not verified"}), 403
        
    data = request.get_json()
    try:
        lat = float(data.get('latitude'))
        lng = float(data.get('longitude'))
        if not (-90 <= lat <= 90) or not (-180 <= lng <= 180):
            raise ValueError("Coordinates out of range")
    except (TypeError, ValueError):
        return jsonify({"msg": "Invalid coordinate data"}), 400

    user.latitude = lat
    user.longitude = lng
    user.is_active = data.get('is_active', True)
    
    db.session.commit()

    # Emit location update to Admin Dashboard
    from . import socketio
    socketio.emit('vendor_location_update', {
        'id': user.id,
        'username': user.username,
        'lat': user.latitude,
        'lng': user.longitude,
        'is_active': user.is_active,
        'is_verified': user.is_verified
    })

    return jsonify({"msg": "Location updated successfully"}), 200

@vendor_bp.route('/upload-store-image', methods=['POST'])
@role_required('vendor')
def upload_store_image():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)
    
    if 'file' not in request.files:
        return jsonify({"msg": "No file part"}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({"msg": "No selected file"}), 400
    
    if file:
        ext = os.path.splitext(file.filename)[1].lower()
        if ext not in ['.jpg', '.jpeg', '.png']:
            return jsonify({"msg": "Invalid file type"}), 400
            
        from .storage import upload_file
        image_url = upload_file(file, folder='stores')
        
        if not image_url:
            return jsonify({"msg": "Upload failed"}), 500
            
        user.store_image_url = image_url
        db.session.commit()
        
        return jsonify({"msg": "Store image updated", "store_image_url": user.store_image_url}), 200
    
    return jsonify({"msg": "Upload failed"}), 400

@vendor_bp.route('/store-image/<filename>', methods=['GET'])
def get_store_image(filename):
    from flask import send_from_directory
    return send_from_directory(os.path.join('static', 'uploads', 'stores'), filename)

@vendor_bp.route('/orders', methods=['GET'])
@role_required('vendor')
def vendor_orders():
    user_id = get_jwt_identity()
    orders = Order.query.filter_by(vendor_id=user_id).order_by(Order.created_at.desc()).all()
    return jsonify([o.to_dict() for o in orders]), 200

@vendor_bp.route('/orders/<int:order_id>', methods=['PATCH'])
@role_required('vendor')
def update_order_status_alias(order_id):
    return update_order_status(order_id)

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
    category = request.args.get('category')
    
    query = DailyStock.query.filter_by(
        vendor_id=vendor_id, 
        date=datetime.now(timezone.utc).date()
    )
    
    stocks = query.all()
    
    result = []
    for s in stocks:
        if s.product:
            if category and category != 'Semua' and s.product.category != category:
                continue
                
            result.append({
                "product_id": s.product_id,
                "name": s.product.name,
                "price": s.product.price,
                "quantity": s.quantity,
                "category": s.product.category,
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
    
    # 1. Lock and Verify Stock (Sorted by product_id to prevent deadlocks)
    sorted_items = sorted(items, key=lambda x: x['product_id'])

    try:
        for item in sorted_items:
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

        # 3. Trigger Notifications
        from .notifications import send_push_notification
        customer_name = User.query.get(user_id).username
        
        # SocketIO (Instant foreground update)
        from . import socketio
        socketio.emit('new_order', {
            'order_id': new_order.id,
            'total_price': new_order.total_price,
            'customer_name': customer_name
        }, room=f"user_{vendor_id}")
        
        # Push Notification (Background/System level)
        send_push_notification(
            vendor_id, 
            "Pesanan Baru!", 
            f"{customer_name} baru saja memesan Rp {new_order.total_price}",
            {"order_id": str(new_order.id), "type": "order"}
        )

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
    user_id = int(get_jwt_identity())
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

# --- Chat Routes ---
@chat_bp.route('/send', methods=['POST'])
@jwt_required()
def send_message():
    user_id = get_jwt_identity()
    data = request.get_json()
    receiver_id = data.get('receiver_id')
    message = data.get('message')

    if not receiver_id or not message:
        return jsonify({"msg": "Receiver and message are required"}), 400

    new_msg = ChatMessage(sender_id=user_id, receiver_id=receiver_id, message=message)
    db.session.add(new_msg)
    db.session.commit()

    # Trigger Notifications
    from .notifications import send_push_notification
    sender_name = User.query.get(user_id).username
    
    # SocketIO
    from . import socketio
    socketio.emit('new_chat_message', new_msg.to_dict(), room=f"user_{receiver_id}")
    
    # Push Notification
    send_push_notification(
        receiver_id, 
        f"Pesan dari {sender_name}", 
        new_msg.message,
        {"sender_id": str(user_id), "type": "chat"}
    )

    return jsonify(new_msg.to_dict()), 201

@chat_bp.route('/history/<int:other_id>', methods=['GET'])
@jwt_required()
def get_chat_history(other_id):
    user_id = get_jwt_identity()
    messages = ChatMessage.query.filter(
        or_(
            (ChatMessage.sender_id == user_id) & (ChatMessage.receiver_id == other_id),
            (ChatMessage.sender_id == other_id) & (ChatMessage.receiver_id == user_id)
        )
    ).order_by(ChatMessage.created_at.asc()).all()
    
    return jsonify([m.to_dict() for m in messages]), 200

@chat_bp.route('/read/<int:other_id>', methods=['PATCH'])
@jwt_required()
def mark_as_read(other_id):
    user_id = get_jwt_identity()
    # Mark all unread messages from other_id to user_id as read
    unread_messages = ChatMessage.query.filter_by(
        sender_id=other_id, 
        receiver_id=user_id, 
        is_read=False
    ).all()
    
    for msg in unread_messages:
        msg.is_read = True
    
    db.session.commit()

    # Notify the sender that their messages were read
    from . import socketio
    socketio.emit('messages_read', {
        'reader_id': user_id,
        'sender_id': other_id
    }, room=f"user_{other_id}")

    return jsonify({"msg": "Messages marked as read"}), 200

@chat_bp.route('/conversations', methods=['GET'])
@jwt_required()
def get_conversations():
    user_id = get_jwt_identity()
    # This is a bit complex in SQL, so we'll do it in a simplified way for the prototype
    # Get all unique users this user has chatted with
    sent_to = db.session.query(ChatMessage.receiver_id).filter_by(sender_id=user_id).distinct()
    received_from = db.session.query(ChatMessage.sender_id).filter_by(receiver_id=user_id).distinct()
    
    other_user_ids = set([r[0] for r in sent_to] + [r[0] for r in received_from])
    
    results = []
    for other_id in other_user_ids:
        other_user = User.query.get(other_id)
        if not other_user: continue
        
        last_msg = ChatMessage.query.filter(
            or_(
                (ChatMessage.sender_id == user_id) & (ChatMessage.receiver_id == other_id),
                (ChatMessage.sender_id == other_id) & (ChatMessage.receiver_id == user_id)
            )
        ).order_by(ChatMessage.created_at.desc()).first()
        
        unread_count = ChatMessage.query.filter_by(
            sender_id=other_id,
            receiver_id=user_id,
            is_read=False
        ).count()
        
        results.append({
            "other_user_id": other_id,
            "other_username": other_user.username,
            "last_message": last_msg.message if last_msg else "",
            "last_time": last_msg.created_at.isoformat() if last_msg else None,
            "unread_count": unread_count
        })
    
    # Sort by last message time
    results.sort(key=lambda x: x['last_time'] if x['last_time'] else "", reverse=True)
    return jsonify(results), 200
import uuid
import os
from flask import send_from_directory

@chat_bp.route('/upload/voice', methods=['POST'])
@jwt_required()
def upload_voice():
    user_id = get_jwt_identity()
    if 'file' not in request.files:
        return jsonify({"msg": "No file part"}), 400
    
    file = request.files['file']
    receiver_id = request.form.get('receiver_id')
    
    if file.filename == '':
        return jsonify({"msg": "No selected file"}), 400
    
    if file and receiver_id:
        from .storage import upload_file
        media_url = upload_file(file, folder='voice')
        
        if not media_url:
            return jsonify({"msg": "Upload failed"}), 500
            
        new_msg = ChatMessage(
            sender_id=user_id, 
            receiver_id=receiver_id, 
            message='[Voice Message]',
            message_type='voice',
            media_url=media_url
        )
        db.session.add(new_msg)
        db.session.commit()
        
        # Trigger Notifications
        from .notifications import send_push_notification
        sender_name = User.query.get(user_id).username
        
        # SocketIO
        from . import socketio
        socketio.emit('new_chat_message', new_msg.to_dict(), room=f"user_{receiver_id}")
        
        # Push Notification
        send_push_notification(
            receiver_id, 
            f"Pesan Suara dari {sender_name}", 
            "[Voice Message]",
            {"sender_id": str(user_id), "type": "chat"}
        )
        
        return jsonify(new_msg.to_dict()), 201
        
    return jsonify({"msg": "Upload failed"}), 400

@chat_bp.route('/voice/<filename>', methods=['GET'])
def get_voice(filename):
    return send_from_directory(os.path.join('static', 'uploads', 'voice'), filename)

@chat_bp.route('/upload/image', methods=['POST'])
@jwt_required()
def upload_image():
    user_id = get_jwt_identity()
    if 'file' not in request.files:
        return jsonify({"msg": "No file part"}), 400
    
    file = request.files['file']
    receiver_id = request.form.get('receiver_id')
    
    if file.filename == '':
        return jsonify({"msg": "No selected file"}), 400
    
    if file and receiver_id:
        # Get extension
        ext = os.path.splitext(file.filename)[1].lower()
        if ext not in ['.jpg', '.jpeg', '.png', '.gif']:
            return jsonify({"msg": "Invalid file type"}), 400
            
        from .storage import upload_file
        media_url = upload_file(file, folder='images')
        
        if not media_url:
            return jsonify({"msg": "Upload failed"}), 500
            
        new_msg = ChatMessage(
            sender_id=user_id, 
            receiver_id=receiver_id, 
            message='[Photo Message]',
            message_type='image',
            media_url=media_url
        )
        db.session.add(new_msg)
        db.session.commit()
        
        # Trigger Notifications
        from .notifications import send_push_notification
        sender_name = User.query.get(user_id).username
        
        # SocketIO
        from . import socketio
        socketio.emit('new_chat_message', new_msg.to_dict(), room=f"user_{receiver_id}")
        
        # Push Notification
        send_push_notification(
            receiver_id, 
            f"Pesan Foto dari {sender_name}", 
            "[Photo Message]",
            {"sender_id": str(user_id), "type": "chat"}
        )
        
        return jsonify(new_msg.to_dict()), 201
        
    return jsonify({"msg": "Upload failed"}), 400

@chat_bp.route('/image/<filename>', methods=['GET'])
def get_image(filename):
    return send_from_directory(os.path.join('static', 'uploads', 'images'), filename)

@chat_bp.route('/send-product', methods=['POST'])
@jwt_required()
def send_product_card():
    user_id = get_jwt_identity()
    data = request.get_json()
    receiver_id = data.get('receiver_id')
    product_id = data.get('product_id')

    if not receiver_id or not product_id:
        return jsonify({"msg": "Receiver and product are required"}), 400

    product = Product.query.get_or_404(product_id)
    
    new_msg = ChatMessage(
        sender_id=user_id, 
        receiver_id=receiver_id, 
        message_type='product',
        product_id=product_id,
        message=f"Cek produk ini: {product.name}"
    )
    db.session.add(new_msg)
    db.session.commit()

    # Trigger Notifications
    from .notifications import send_push_notification
    sender_name = User.query.get(user_id).username
    
    # SocketIO
    from . import socketio
    socketio.emit('new_chat_message', new_msg.to_dict(), room=f"user_{receiver_id}")
    
    # Push Notification
    send_push_notification(
        receiver_id, 
        f"Rekomendasi Produk dari {sender_name}", 
        f"Cek {product.name} sekarang!",
        {"sender_id": str(user_id), "type": "chat", "product_id": str(product_id)}
    )

    return jsonify(new_msg.to_dict()), 201
   {"sender_id": str(user_id), "type": "chat", "product_id": str(product_id)}
    )

    return jsonify(new_msg.to_dict()), 201
ame}", 
        f"Cek {product.name} sekarang!",
        {"sender_id": str(user_id), "type": "chat", "product_id": str(product_id)}
    )

    return jsonify(new_msg.to_dict()), 201

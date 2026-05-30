import csv
try:
    import psutil
except ImportError:
    psutil = None
try:
    import platform
except ImportError:
    platform = None
from io import StringIO
from flask import Blueprint, render_template, request, redirect, url_for, flash, session, make_response, jsonify
from .models import User, Order, OrderItem, Product, AuditLog, ChatMessage, db
from sqlalchemy import func, or_
from datetime import datetime, timedelta, timezone

web_admin_bp = Blueprint('web_admin', __name__, template_folder='templates')

def log_action(action, target_type=None, target_id=None, details=None):
    admin_id = session.get('admin_id')
    log = AuditLog(
        user_id=admin_id,
        action=action,
        target_type=target_type,
        target_id=target_id,
        details=details,
        ip_address=request.remote_addr
    )
    db.session.add(log)
    db.session.commit()

LOGIN_ROUTE = 'web_admin.login'

@web_admin_bp.context_processor
def inject_globals():
    try:
        pending_vendors = User.query.filter_by(role='vendor', is_verified=False).count()
        unread_messages = 0
        admin_id = session.get('admin_id')
        if admin_id:
            unread_messages = ChatMessage.query.filter_by(receiver_id=admin_id, is_read=False).count()
        return {
            'now': datetime.now(timezone.utc),
            'pending_vendor_count': pending_vendors,
            'unread_msg_count': unread_messages
        }
    except:
        return {'now': datetime.now(), 'pending_vendor_count': 0, 'unread_msg_count': 0}

@web_admin_bp.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        user = User.query.filter_by(username=username, role='admin').first()
        if user and user.check_password(password):
            # Security: Session Regeneration to prevent fixation
            session.clear()
            session.permanent = True
            session['admin_id'] = user.id
            try:
                log_action('LOGIN', 'User', user.id, f"Admin {username} logged in")
            except Exception as e:
                print(f"AUDIT LOG ERROR: {e}")
            return redirect(url_for('web_admin.dashboard'))
        flash('Invalid admin credentials')
    return render_template('admin/login.html')

@web_admin_bp.route('/dashboard', methods=['GET'])
def dashboard():
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    try:
        # Stats
        total_vendors = User.query.filter_by(role='vendor').count()
        total_customers = User.query.filter_by(role='customer').count()
        total_revenue = db.session.query(func.sum(Order.total_price)).filter(Order.status == 'delivered').scalar() or 0
        total_products = Product.query.count()
        
        # Last 7 days revenue
        seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)
        daily_revenue = db.session.query(
            func.date(Order.created_at), 
            func.sum(Order.total_price)
        ).filter(Order.created_at >= seven_days_ago, Order.status == 'delivered') \
         .group_by(func.date(Order.created_at)).all()
        
        chart_labels = [str(r[0]) for r in daily_revenue]
        chart_data = [int(r[1]) if r[1] else 0 for r in daily_revenue]

        # Recent Orders
        recent_orders = Order.query.order_by(Order.created_at.desc()).limit(5).all()

        # Advanced Analytics: Top Selling Products
        top_products = db.session.query(
            Product.name,
            func.sum(OrderItem.quantity).label('total_sold')
        ).join(OrderItem).group_by(Product.id).order_by(func.sum(OrderItem.quantity).desc()).limit(5).all()
        
        product_names = [str(p[0]) for p in top_products]
        product_sales = [int(p[1]) if p[1] is not None else 0 for p in top_products]

        # Advanced Analytics: Vendor Performance (by revenue)
        vendor_perf = db.session.query(
            User.username,
            func.sum(Order.total_price).label('revenue')
        ).filter(User.role == 'vendor').join(Order, User.id == Order.vendor_id)\
         .filter(Order.status == 'delivered')\
         .group_by(User.id).order_by(func.sum(Order.total_price).desc()).limit(5).all()
        
        vendor_names = [str(v[0]) for v in vendor_perf]
        vendor_revenues = [int(v[1]) if v[1] is not None else 0 for v in vendor_perf]

        # Global stocks report
        from .models import DailyStock
        global_stocks = DailyStock.query.filter_by(date=datetime.now(timezone.utc).date()).all()

        # Vendor Locations for Map
        active_vendors = User.query.filter_by(role='vendor', is_active=True).all()
        vendor_locations = []
        for v in active_vendors:
            if v.latitude and v.longitude:
                vendor_locations.append({
                    'username': v.username,
                    'lat': v.latitude,
                    'lng': v.longitude,
                    'is_verified': v.is_verified
                })

        return render_template('admin/dashboard.html', 
                               total_vendors=total_vendors, 
                               total_customers=total_customers, 
                               total_revenue=total_revenue,
                               total_products=total_products,
                               chart_labels=chart_labels,
                               chart_data=chart_data,
                               recent_orders=recent_orders,
                               top_product_names=product_names,
                               top_product_sales=product_sales,
                               top_vendor_names=vendor_names,
                               top_vendor_revenues=vendor_revenues,
                               global_stocks=global_stocks,
                               vendor_locations=vendor_locations)
    except Exception as e:
        import traceback
        with open('error_debug.log', 'a') as f:
            f.write(f"\n--- ERROR at {datetime.now()} ---\n")
            traceback.print_exc(file=f)
        print("DASHBOARD ERROR:", str(e))
        return f"<h1>Internal Server Error</h1><p>{str(e)}</p>", 500

@web_admin_bp.route('/vendors', methods=['GET'])
def vendors():
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    status_filter = request.args.get('status', 'all')
    query = User.query.filter_by(role='vendor')
    
    if status_filter == 'pending':
        query = query.filter_by(is_verified=False)
    elif status_filter == 'verified':
        query = query.filter_by(is_verified=True)
        
    all_vendors = query.order_by(User.id.desc()).all()
    return render_template('admin/vendors.html', vendors=all_vendors, current_filter=status_filter)

@web_admin_bp.route('/orders', methods=['GET'])
def orders():
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    all_orders = Order.query.order_by(Order.created_at.desc()).all()
    return render_template('admin/orders.html', orders=all_orders)

@web_admin_bp.route('/products', methods=['GET', 'POST'])
def products():
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    if request.method == 'POST':
        name = request.form.get('name')
        price = request.form.get('price')
        description = request.form.get('description')
        image_url = request.form.get('image_url')
        
        new_product = Product(name=name, price=int(price), description=description, image_url=image_url)
        db.session.add(new_product)
        db.session.commit()
        
        # Emit real-time notification to all vendors
        try:
            from . import socketio
            socketio.emit('catalog_updated', {'type': 'add', 'product': new_product.to_dict()})
        except Exception as e:
            print(f"Socket emit error: {e}")
            
        log_action('CREATE_PRODUCT', 'Product', new_product.id, f"Added product: {name}")
        flash('Product added successfully!')
        return redirect(url_for('web_admin.products'))
        
    all_products = Product.query.all()
    return render_template('admin/products.html', products=all_products)

@web_admin_bp.route('/products/delete/<int:id>', methods=['POST'])
def delete_product(id):
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    product = Product.query.get_or_404(id)
    product_name = product.name
    try:
        db.session.delete(product)
        db.session.commit()
        log_action('DELETE_PRODUCT', 'Product', id, f"Deleted product: {product_name}")
        flash(f'Product {product_name} deleted successfully!')
    except Exception as e:
        db.session.rollback()
        print(f"DELETE PRODUCT ERROR: {e}")
        flash(f'Error deleting product: {str(e)}')
        
    return redirect(url_for('web_admin.products'))

@web_admin_bp.route('/customers', methods=['GET'])
def customers():
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    all_customers = User.query.filter_by(role='customer').all()
    return render_template('admin/customers.html', customers=all_customers)

@web_admin_bp.route('/logs', methods=['GET'])
def logs():
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    all_logs = AuditLog.query.order_by(AuditLog.created_at.desc()).all()
    return render_template('admin/logs.html', logs=all_logs)

@web_admin_bp.route('/health', methods=['GET'])
def health():
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    # System Stats
    cpu_usage = psutil.cpu_percent(interval=1) if psutil else 0
    ram = psutil.virtual_memory() if psutil else None
    disk = psutil.disk_usage('/') if psutil else None
    
    # Database Stats
    db_stats = {
        'users': User.query.count(),
        'orders': Order.query.count(),
        'products': Product.query.count(),
        'audit_logs': AuditLog.query.count()
    }
    
    system_info = {
        'os': platform.system() if platform else "Unknown",
        'os_release': platform.release() if platform else "Unknown",
        'python_version': platform.python_version() if platform else "Unknown",
        'boot_time': datetime.fromtimestamp(psutil.boot_time()).strftime("%Y-%m-%d %H:%M:%S") if psutil else "Unknown"
    }
    
    return render_template('admin/health.html', 
                           cpu=cpu_usage, 
                           ram=ram, 
                           disk=disk, 
                           db_stats=db_stats,
                           system_info=system_info)

@web_admin_bp.route('/bulk-stock', methods=['GET'])
def bulk_stock():
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    vendors = User.query.filter_by(role='vendor', is_verified=True).all()
    products = Product.query.all()
    return render_template('admin/bulk_stock.html', vendors=vendors, products=products)

@web_admin_bp.route('/bulk-stock/apply', methods=['POST'])
def bulk_stock_action():
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    vendor_ids = request.form.getlist('vendor_ids')
    if not vendor_ids:
        flash('No vendors selected!')
        return redirect(url_for('web_admin.bulk_stock'))
        
    from .models import DailyStock
    today = datetime.now(timezone.utc).date()
    products = Product.query.all()
    
    count = 0
    for v_id in vendor_ids:
        for p in products:
            qty = request.form.get(f'stock_{p.id}', type=int)
            if qty is not None:
                # Security: Pessimistic Locking
                stock = DailyStock.query.filter_by(
                    vendor_id=int(v_id), 
                    product_id=p.id, 
                    date=today
                ).with_for_update().first()
                if stock:
                    stock.quantity = qty
                else:
                    stock = DailyStock(vendor_id=int(v_id), product_id=p.id, quantity=qty, date=today)
                    db.session.add(stock)
        count += 1
    
    db.session.commit()
    log_action('BULK_STOCK_DISTRIBUTION', 'User', None, f"Admin distributed stock to {count} vendors")
    flash(f'Berhasil mendistribusikan stok ke {count} penjual!')
    return redirect(url_for('web_admin.dashboard'))

@web_admin_bp.route('/vendors/<int:vendor_id>/stock', methods=['GET', 'POST'])
def update_vendor_stock(vendor_id):
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    vendor = User.query.get_or_404(vendor_id)
    if vendor.role != 'vendor':
        flash('User is not a vendor')
        return redirect(url_for('web_admin.vendors'))
        
    from .models import DailyStock
    today = datetime.now(timezone.utc).date()

    if request.method == 'POST':
        products = Product.query.all()
        for p in products:
            qty = request.form.get(f'stock_{p.id}', type=int)
            if qty is not None:
                # Security: Pessimistic Locking
                stock = DailyStock.query.filter_by(
                    vendor_id=vendor_id, 
                    product_id=p.id, 
                    date=today
                ).with_for_update().first()
                if stock:
                    stock.quantity = qty
                else:
                    stock = DailyStock(vendor_id=vendor_id, product_id=p.id, quantity=qty, date=today)
                    db.session.add(stock)
        
        db.session.commit()
        log_action('ADMIN_SET_STOCK', 'User', vendor_id, f"Admin set stock for vendor {vendor.username}")
        flash(f'Stok untuk {vendor.username} berhasil diperbarui!')
        return redirect(url_for('web_admin.vendors'))

    # GET: Load current stocks
    stocks = DailyStock.query.filter_by(vendor_id=vendor_id, date=today).all()
    current_stocks = {s.product_id: s.quantity for s in stocks}
    all_products = Product.query.all()
    
    return render_template('admin/vendor_stock.html', vendor=vendor, products=all_products, current_stocks=current_stocks)

@web_admin_bp.route('/verify/<int:user_id>/<string:action>', methods=['GET'])
def verify_action(user_id, action):
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    user = User.query.get_or_404(user_id)
    if action == 'approve':
        user.is_verified = True
        log_action('APPROVE_VENDOR', 'User', user_id, f"Approved vendor: {user.username}")
        flash(f'Vendor {user.username} berhasil disetujui!')
    else:
        username = user.username
        db.session.delete(user)
        log_action('REJECT_VENDOR', 'User', user_id, f"Rejected and deleted vendor: {username}")
        flash(f'Vendor {user.username} telah ditolak dan dihapus.')
    
    db.session.commit()
    return redirect(request.referrer or url_for('web_admin.dashboard'))

@web_admin_bp.route('/orders/export', methods=['GET'])
def export_orders():
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    orders = Order.query.order_by(Order.created_at.desc()).all()
    si = StringIO()
    cw = csv.writer(si)
    cw.writerow(['Order ID', 'Waktu', 'Customer', 'Vendor', 'Total Harga', 'Status', 'Item (Produk x Qty)'])
    
    for order in orders:
        items_str = ", ".join([f"{item.product.name} x {item.quantity}" for item in order.items])
        cw.writerow([
            order.id,
            order.created_at.strftime('%Y-%m-%d %H:%M'),
            order.customer.username,
            order.vendor.username,
            order.total_price,
            order.status.upper(),
            items_str
        ])
    
    output = make_response(si.getvalue())
    output.headers["Content-Disposition"] = f"attachment; filename=laporan_transaksi_{datetime.now().strftime('%Y%m%d')}.csv"
    output.headers["Content-type"] = "text/csv"
    return output

@web_admin_bp.route('/messages', methods=['GET'])
def messages():
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    vendors = User.query.filter_by(role='vendor').all()
    target_id = request.args.get('vendor_id', type=int)
    chat_history = []
    selected_vendor = None
    
    if target_id:
        selected_vendor = User.query.get(target_id)
        chat_history = ChatMessage.query.filter(
            or_(
                (ChatMessage.sender_id == session['admin_id']) & (ChatMessage.receiver_id == target_id),
                (ChatMessage.sender_id == target_id) & (ChatMessage.receiver_id == session['admin_id'])
            )
        ).order_by(ChatMessage.created_at.asc()).all()
        
    return render_template('admin/messages.html', vendors=vendors, chat_history=chat_history, selected_vendor=selected_vendor)

@web_admin_bp.route('/messages/send', methods=['POST'])
def send_message():
    if 'admin_id' not in session:
        return jsonify({"error": "Unauthorized"}), 401
    
    data = request.get_json()
    receiver_id = data.get('receiver_id')
    content = data.get('message')
    
    if not content or not receiver_id:
        return jsonify({"error": "Missing fields"}), 400
        
    msg = ChatMessage(
        sender_id=session['admin_id'],
        receiver_id=receiver_id,
        message=content
    )
    db.session.add(msg)
    db.session.commit()
    
    from . import socketio
    socketio.emit('new_chat_message', msg.to_dict(), room=f"user_{receiver_id}")
    
    return jsonify(msg.to_dict()), 201

@web_admin_bp.route('/logout', methods=['GET'])
def logout():
    session.pop('admin_id', None)
    return redirect(url_for(LOGIN_ROUTE))

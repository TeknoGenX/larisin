import csv
from io import StringIO
from flask import Blueprint, render_template, request, redirect, url_for, flash, session, make_response
from .models import User, Order, OrderItem, db
from sqlalchemy import func
from datetime import datetime, timedelta, timezone

web_admin_bp = Blueprint('web_admin', __name__, template_folder='templates')

LOGIN_ROUTE = 'web_admin.login'

@web_admin_bp.route('/orders/export', methods=['GET'])
def export_orders():
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    # Ambil semua data order
    orders = Order.query.order_by(Order.created_at.desc()).all()
    
    # Buat buffer CSV
    si = StringIO()
    cw = csv.writer(si)
    
    # Header CSV
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

@web_admin_bp.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        user = User.query.filter_by(username=username, role='admin').first()
        if user and user.check_password(password):
            session['admin_id'] = user.id
            return redirect(url_for('web_admin.dashboard'))
        flash('Invalid admin credentials')
    return render_template('admin/login.html')

@web_admin_bp.route('/dashboard', methods=['GET'])
def dashboard():
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    # Stats for the dashboard
    total_vendors = User.query.filter_by(role='vendor').count()
    total_customers = User.query.filter_by(role='customer').count()
    total_revenue = db.session.query(func.sum(Order.total_price)).filter(Order.status == 'delivered').scalar() or 0
    
    # Last 7 days revenue for Chart.js
    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=7)
    daily_revenue = db.session.query(
        func.date(Order.created_at), 
        func.sum(Order.total_price)
    ).filter(Order.created_at >= seven_days_ago, Order.status == 'delivered')     .group_by(func.date(Order.created_at)).all()
    
    chart_labels = [str(r[0]) for r in daily_revenue]
    chart_data = [int(r[1]) for r in daily_revenue]

    # Ambil vendor yang belum diverifikasi
    pending_vendors = User.query.filter_by(role='vendor', is_verified=False).all()

    # Ambil stok global seluruh vendor hari ini
    global_stocks = DailyStock.query.filter_by(date=datetime.now(timezone.utc).date()).all()

    return render_template('admin/dashboard.html', 
                           total_vendors=total_vendors, 
                           total_customers=total_customers, 
                           total_revenue=total_revenue,
                           chart_labels=chart_labels,
                           chart_data=chart_data,
                           pending_vendors=pending_vendors,
                           global_stocks=global_stocks)

@web_admin_bp.route('/verify/<int:user_id>/<string:action>', methods=['GET'])
def verify_action(user_id, action):
    if 'admin_id' not in session:
        return redirect(url_for(LOGIN_ROUTE))
    
    user = User.query.get_or_404(user_id)
    if action == 'approve':
        user.is_verified = True
        flash(f'Vendor {user.username} berhasil disetujui!')
    else:
        # Untuk reject, kita bisa hapus atau beri flag khusus. Di sini kita hapus.
        db.session.delete(user)
        flash(f'Vendor {user.username} telah ditolak dan dihapus.')
    
    db.session.commit()
    return redirect(url_for('web_admin.dashboard'))

@web_admin_bp.route('/logout', methods=['GET'])
def logout():
    session.pop('admin_id', None)
    return redirect(url_for(LOGIN_ROUTE))

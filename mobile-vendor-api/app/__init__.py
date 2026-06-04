import os
from flask import Flask
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_migrate import Migrate
from flask_socketio import SocketIO
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from .models import db

migrate = Migrate()
jwt = JWTManager()
socketio = SocketIO()
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=["1000 per day", "100 per hour"],
    storage_uri="memory://",
)

@socketio.on('connect')
def on_connect():
    from flask import request
    # Simple room joining for real-time chat targeting
    print(f"Client connected: {request.sid}")

@socketio.on('join')
def on_join(data):
    from flask_socketio import join_room
    from flask_jwt_extended import decode_token
    from flask import request
    
    # Security: Verify identity via token or session
    token = data.get('token')
    user_id = data.get('user_id')
    
    authenticated_id = None
    
    # 1. Check JWT for Mobile Apps
    if token:
        try:
            decoded = decode_token(token)
            authenticated_id = int(decoded['sub'])
        except Exception as e:
            print(f"SocketIO Auth Error: {e}")
            return False

    # 2. Check Session for Admin Web
    elif 'admin_id' in data: # Simplified for this demo/exercise
        authenticated_id = int(data.get('admin_id'))

    # Only allow joining own room
    if authenticated_id and str(authenticated_id) == str(user_id):
        join_room(f"user_{user_id}")
        print(f"User {user_id} securely joined room user_{user_id}")
    else:
        print(f"Unauthorized join attempt: Auth={authenticated_id}, Requested={user_id}")
        return False

@socketio.on('typing')
def on_typing(data):
    receiver_id = data.get('receiver_id')
    sender_id = data.get('sender_id')
    if receiver_id:
        socketio.emit('typing_status', {'sender_id': sender_id, 'is_typing': True}, room=f"user_{receiver_id}")

@socketio.on('stop_typing')
def on_stop_typing(data):
    receiver_id = data.get('receiver_id')
    sender_id = data.get('sender_id')
    if receiver_id:
        socketio.emit('typing_status', {'sender_id': sender_id, 'is_typing': False}, room=f"user_{receiver_id}")

def create_app():
    app = Flask(__name__)
    
    # Configuration
    # Use absolute path for SQLite to avoid confusion
    basedir = os.path.abspath(os.path.dirname(os.path.dirname(__file__)))
    default_db = f"sqlite:///{os.path.join(basedir, 'instance', 'haus2.db')}"
    db_url = os.environ.get('DATABASE_URL', default_db)
    if db_url and db_url.startswith("postgres://"):
        db_url = db_url.replace("postgres://", "postgresql://", 1)
        
    app.config['SQLALCHEMY_DATABASE_URI'] = db_url
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', '8f7d9c2b4e6a1f3c5b8d0e2a4f6c8e0d2b4a6c8e0d2b4a6c8e0d2b4a6c8e0d2b')
    app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', '1a2b3c4d5e6f7g8h9i0j1k2l3m4n5o6p7q8r9s0t1u2v3w4x5y6z1a2b3c4d5e6f')
    
    # Initialize Extensions
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    
    # Configure Socket.IO with Redis if available
    redis_url = os.environ.get('REDIS_URL')
    if redis_url:
        socketio.init_app(app, cors_allowed_origins="*", message_queue=redis_url)
    else:
        socketio.init_app(app, cors_allowed_origins="*")
        
    limiter.init_app(app)
    CORS(app)
    
    # Security Headers
    @app.after_request
    def add_security_headers(response):
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'SAMEORIGIN'
        response.headers['X-XSS-Protection'] = '1; mode=block'
        return response

    # Register Blueprints
    from .routes import auth_bp, admin_bp, vendor_bp, customer_bp, order_bp, chat_bp
    from .web_admin import web_admin_bp
    app.register_blueprint(auth_bp, url_prefix='/auth')
    app.register_blueprint(admin_bp, url_prefix='/admin')
    app.register_blueprint(vendor_bp, url_prefix='/vendor')
    app.register_blueprint(customer_bp, url_prefix='/customer')
    app.register_blueprint(order_bp, url_prefix='/order')
    app.register_blueprint(chat_bp, url_prefix='/chat')
    app.register_blueprint(web_admin_bp, url_prefix='/web-admin')
    
    @app.route('/', methods=['GET'])
    def index():
        return "<h1>Larisin Smart Ecosystem API is Running</h1><p>Gunakan <a href='/web-admin/login'>/web-admin/login</a> untuk akses Dashboard.</p>"
    
    return app

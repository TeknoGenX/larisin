import os
from flask import Flask
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from flask_migrate import Migrate
from flask_socketio import SocketIO
from .models import db

migrate = Migrate()
jwt = JWTManager()
socketio = SocketIO()

def create_app():
    app = Flask(__name__)
    
    # Configuration
    app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///haus2.db')
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY')
    app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY')
    
    # Initialize Extensions
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    socketio.init_app(app, cors_allowed_origins="*")
    CORS(app)
    
    # Register Blueprints
    from .routes import auth_bp, admin_bp, vendor_bp, customer_bp, order_bp
    from .web_admin import web_admin_bp
    app.register_blueprint(auth_bp, url_prefix='/auth')
    app.register_blueprint(admin_bp, url_prefix='/admin')
    app.register_blueprint(vendor_bp, url_prefix='/vendor')
    app.register_blueprint(customer_bp, url_prefix='/customer')
    app.register_blueprint(order_bp, url_prefix='/order')
    app.register_blueprint(web_admin_bp, url_prefix='/web-admin')
    
    @app.route('/', methods=['GET'])
    def index():
        return "<h1>Haus2 Ecosystem API is Running</h1><p>Gunakan <a href='/web-admin/login'>/web-admin/login</a> untuk akses Dashboard.</p>"
    
    return app

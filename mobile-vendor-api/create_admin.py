from app import create_app
from app.models import db, User

app = create_app()

def create_initial_admin():
    with app.app_context():
        username = "admin"
        password = "password123"
        
        # Cek apakah admin sudah ada
        existing_admin = User.query.filter_by(username=username).first()
        if existing_admin:
            print(f"User '{username}' sudah terdaftar sebagai Admin.")
            return

        # Buat admin baru
        admin = User(
            username=username,
            role="admin",
            is_verified=True
        )
        admin.set_password(password)
        
        db.session.add(admin)
        db.session.commit()
        print("-----------------------------------------")
        print("AKUN ADMIN BERHASIL DIBUAT!")
        print(f"Username: {username}")
        print(f"Password: {password}")
        print("-----------------------------------------")
        print("Silahkan login di: http://127.0.0.1:5001/web-admin/login")

if __name__ == "__main__":
    create_initial_admin()

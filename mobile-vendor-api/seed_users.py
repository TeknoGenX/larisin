import os
from app import create_app, db
from app.models import User

# Mocking environment variables for seeding
os.environ['SECRET_KEY'] = 'seed-secret-key'
os.environ['JWT_SECRET_KEY'] = 'seed-jwt-secret-key'

app = create_app()

def seed_users():
    with app.app_context():
        # Ensure tables are created
        db.create_all()
        
        # Roles and counts
        roles_config = {
            'admin': {'prefix': 'admin', 'password': 'adminPass123!'},
            'vendor': {'prefix': 'vendor', 'password': 'vendorPass123!'},
            'customer': {'prefix': 'customer', 'password': 'customerPass123!'}
        }

        print("Seeding users...")

        for role, config in roles_config.items():
            for i in range(1, 11):
                username = f"{config['prefix']}{i}"
                
                # Check if user already exists
                existing_user = User.query.filter_by(username=username).first()
                if not existing_user:
                    user = User(
                        username=username,
                        role=role,
                        is_verified=True # Pre-verify all for easy testing
                    )
                    user.set_password(config['password'])
                    db.session.add(user)
                    print(f"Created {role}: {username}")
                else:
                    print(f"User {username} already exists, skipping.")
        
        db.session.commit()
        print("Seeding completed successfully!")

if __name__ == "__main__":
    seed_users()

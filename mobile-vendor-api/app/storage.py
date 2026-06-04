import os
import uuid
import cloudinary
import cloudinary.uploader
from flask import current_app

# Cloudinary Configuration (Read from environment variable CLOUDINARY_URL)
# Format: cloudinary://API_KEY:API_SECRET@CLOUD_NAME
if os.environ.get('CLOUDINARY_URL'):
    cloudinary.config(secure=True)

def upload_file(file, folder='misc'):
    """
    Uploads a file to Cloudinary (Production) or Local Storage (Development).
    Returns the URL of the uploaded file.
    """
    if os.environ.get('CLOUDINARY_URL'):
        try:
            # Upload to Cloudinary
            result = cloudinary.uploader.upload(file, folder=f"larisin/{folder}")
            return result.get('secure_url')
        except Exception as e:
            print(f"Cloudinary Upload Error: {e}")
            return None
    else:
        # Local Storage Fallback (Development)
        ext = os.path.splitext(file.filename)[1].lower()
        filename = f"{uuid.uuid4().hex}{ext}"
        
        # Determine local path
        upload_folder = os.path.join('app', 'static', 'uploads', folder)
        if not os.path.exists(upload_folder):
            os.makedirs(upload_folder)
            
        file.save(os.path.join(upload_folder, filename))
        
        # Return local relative URL
        # Note: In a real app, this should be a full URL or handled by the frontend
        # For simplicity in this ecosystem, we keep the prefix structure
        if folder == 'stores':
            return f"/vendor/store-image/{filename}"
        elif folder == 'voice':
            return f"/chat/voice/{filename}"
        elif folder == 'images':
            return f"/chat/image/{filename}"
        else:
            return f"/static/uploads/{folder}/{filename}"

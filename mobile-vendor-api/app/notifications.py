import logging

# Configure logging to simulate push notification delivery
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("PushNotifications")

def send_push_notification(user_id, title, body, data=None):
    """
    Simulasi pengiriman Push Notification via FCM.
    Dalam produksi, gunakan: 
    import firebase_admin
    from firebase_admin import messaging
    """
    from .models import User
    user = User.query.get(user_id)
    
    if not user or not user.fcm_token:
        logger.warning(f"Gagal mengirim push ke User {user_id}: Token tidak ditemukan.")
        return False
        
    # LOGGING SIMULASI (Terlihat di log server jika level INFO aktif)
    logger.info("--- [PUSH NOTIFICATION SENT] ---")
    logger.info(f"To: {user.username} (Token: {user.fcm_token[:10]}...)")
    logger.info(f"Title: {title}")
    logger.info(f"Body: {body}")
    logger.info(f"Payload: {data}")
    logger.info("--------------------------------")
    
    return True

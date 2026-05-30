import socketio
import time

sio = socketio.Client()

@sio.event
def connect():
    print("Connected to Socket.IO")

@sio.event
def disconnect():
    print("Disconnected from Socket.IO")

@sio.on('typing_status')
def on_typing(data):
    print(f"Typing status received: {data}")

def test_tc04_socket_security():
    print("\n--- TC-04: Socket.IO Security Check ---")
    try:
        sio.connect("http://127.0.0.1:5003")
        # Try to join room 1 (Admin) without any credentials in data
        sio.emit('join', {'user_id': 1})
        time.sleep(2)
        print("Emitted join room 1 without auth token.")
        sio.disconnect()
        return True
    except Exception as e:
        print(f"Connection failed: {e}")
        return False

if __name__ == "__main__":
    test_tc04_socket_security()

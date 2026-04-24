from app import create_app, socketio

app = create_app()

if __name__ == '__main__':
    # Menjalankan dengan socketio di port standar 5002
    socketio.run(app, debug=False, port=5002, allow_unsafe_werkzeug=True)

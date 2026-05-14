from app import create_app, socketio

app = create_app()

if __name__ == '__main__':
    # Menjalankan dengan socketio di port standar 5003 sesuai instruksi user
    socketio.run(app, debug=False, port=5003, allow_unsafe_werkzeug=True)

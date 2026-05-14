import multiprocessing
import os

# Gunicorn configuration for SocketIO
bind = "0.0.0.0:5005"
workers = 1  # SocketIO requires 1 worker for sticky sessions unless using a message queue like Redis
worker_class = "eventlet"
timeout = 30
keepalive = 2

# Logging
accesslog = "access.log"
errorlog = "server.log"
loglevel = "info"

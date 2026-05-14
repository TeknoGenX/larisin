# Project Context: Marketplace Mobile Vendor Ecosystem

## Paths & Configuration
- **Backend Virtual Environment:** `/home/andi-liani/virtual/venv`
- **Flutter Binary:** `/home/andi-liani/flutter/bin/flutter`
- **Backend Port:** 5003
- **Admin Dashboard:** `http://127.0.0.1:5003/web-admin/login`

## Architecture
- **Backend:** Flask, SQLAlchemy, Alembic, JWT, SocketIO (Real-time).
- **Frontend:** Jinja2, Tailwind, Leaflet, Chart.js.
- **Mobile:** Flutter (Provider, Multi-Flavor, Socket.IO Client).
- **Media Storage:** Local storage for Chat Media (Voice & Images).

## Core Rules
- Adhere to RBAC (Admin, Vendor, Customer).
- Use `with_for_update()` for pessimistic locking in order transactions.
- Keep `mobile_vendor_app` flavors distinct.
- Use WebSocket (Socket.IO) for all live updates (GPS, Orders, Chat).
- Media uploads must be validated and stored in `static/uploads/`.

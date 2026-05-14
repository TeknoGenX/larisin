from datetime import datetime, timezone
print(f"UTC Date: {datetime.now(timezone.utc).date()}")
print(f"Local Date: {datetime.now().date()}")

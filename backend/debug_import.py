import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), './')))
print(f"Path: {sys.path}")

try:
    from app.main import app
    print("SUCCESS: app.main imported")
except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()

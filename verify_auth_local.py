from backend.auth import get_password_hash, verify_password

try:
    print("Testing hash...")
    h = get_password_hash("test")
    print(f"Hash: {h}")
    print("Testing verify...")
    v = verify_password("test", h)
    print(f"Verify: {v}")
except Exception as e:
    import traceback
    traceback.print_exc()

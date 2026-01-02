import httpx

try:
    print("Registering...")
    r = httpx.post("http://127.0.0.1:8000/users/register", json={"username": "login_fix_test", "password": "password", "email": "test@test.com"})
    print(f"Reg Status: {r.status_code}")
    
    print("Attempting login...")
    r = httpx.post("http://127.0.0.1:8000/users/login", json={"username": "login_fix_test", "password": "password"})
    print(f"Login Status: {r.status_code}")
    print(f"Response: {r.text}")
except Exception as e:
    print(e)

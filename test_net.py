import httpx
import datetime

try:
    print("Sending POST request to http://127.0.0.1:8000/events/")
    resp = httpx.post(
        "http://127.0.0.1:8000/events/", 
        json={
            "user_id": 1, 
            "consistency": "Normal", 
            "notes": "Real Net Test", 
            "timestamp": datetime.datetime.now().isoformat()
        },
        timeout=5.0
    )
    print(f"Status: {resp.status_code}")
    print(f"Response: {resp.text}")
except Exception as e:
    print(f"Network Request Failed: {e}")

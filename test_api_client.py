import urllib.request
import json
from datetime import datetime

url = "http://127.0.0.1:8000/events/"
payload = {
    "user_id": 1,
    "consistency": "Normal",
    "notes": "Test from script",
    # timestamp is tricky with urllib, backend expects ISO string.
    "timestamp": datetime.utcnow().isoformat()
}

data = json.dumps(payload).encode('utf-8')
req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'}, method='POST')

try:
    print(f"Sending payload: {payload}")
    with urllib.request.urlopen(req) as response:
        print(f"Status Code: {response.getcode()}")
        print(f"Response: {response.read().decode('utf-8')}")
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code}")
    print(f"Response: {e.read().decode('utf-8')}")
except Exception as e:
    print(f"Error: {e}")

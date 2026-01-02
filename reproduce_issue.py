from fastapi.testclient import TestClient
import sys
import os

# Ensure we can import from current directory
sys.path.append(os.getcwd())

from backend.main import app
from shared.models import KKEvent, Consistency
from datetime import datetime

client = TestClient(app)

def test_create_event():
    print("--- Starting Reproduction Test ---")
    # Simulate what mobile_app/src/kkcos/api.py does
    event = KKEvent(
        user_id=123,
        consistency=Consistency.JURASICA,
        notes="Integration test note",
        timestamp=datetime.now()
    )
    
    # model_dump(mode='json') behavior simulation
    payload = event.model_dump(mode='json', exclude={"id"})
    print(f"Payload being sent: {payload}")
    
    try:
        response = client.post("/events/", json=payload)
        print(f"Response Status: {response.status_code}")
        if response.status_code != 200:
            print(f"Response Body: {response.text}")
            print("FAILED!")
        else:
            print(f"Response Body: {response.json()}")
            print("SUCCESS!")
    except Exception as e:
        print(f"Exception during request: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_create_event()

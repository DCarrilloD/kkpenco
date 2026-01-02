import httpx
from shared.models import KKEvent

BASE_URL = "http://127.0.0.1:8000"

class APIClient:
    def __init__(self):
        self.client = httpx.Client(base_url=BASE_URL)

    def create_event(self, event: KKEvent) -> bool:
        try:
            # sqlmodel .model_dump(mode='json') convierte datetime a string ISO
            payload = event.model_dump(mode='json', exclude={"id"})
            response = self.client.post("/events/", json=payload)
            response.raise_for_status()
            return True
        except Exception as e:
            print(f"Error creating event: {e}")
            return False

    def get_events(self):
        try:
            response = self.client.get("/events/")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Error getting events: {e}")
            return []

    def delete_event(self, event_id: int) -> bool:
        try:
            response = self.client.delete(f"/events/{event_id}")
            response.raise_for_status()
            return True
        except Exception as e:
            print(f"Error deleting event: {e}")
            return False

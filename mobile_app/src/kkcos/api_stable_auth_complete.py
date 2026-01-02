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
            if hasattr(e, 'response') and e.response is not None:
                print(f"Response content: {e.response.text}")
            import traceback
            traceback.print_exc()
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

    def get_ranking(self) -> list:
        """Fetches the ranking list."""
        try:
            response = self.client.get("/events/ranking")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Error fetching ranking: {e}")
            return []

    def register(self, username, password, email) -> dict:
        """Registers a new user."""
        try:
            payload = {"username": username, "password": password, "email": email}
            response = self.client.post("/users/register", json=payload)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Error registering: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"Server response: {e.response.text}")
            return None

    def recover_password(self, email) -> bool:
        """Requests password recovery."""
        try:
            response = self.client.post("/users/recover-password", params={"email": email})
            response.raise_for_status()
            return True
        except Exception as e:
            print(f"Error recovering password: {e}")
            return False

    def change_password(self, username, current_password, new_password) -> bool:
        """Changes the user's password."""
        try:
            payload = {
                "username": username,
                "current_password": current_password,
                "new_password": new_password
            }
            response = self.client.post("/users/change-password", json=payload)
            response.raise_for_status()
            return True
        except Exception as e:
            print(f"Error changing password: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"Server response: {e.response.text}")
            return False

    def login(self, username, password) -> dict:
        """Logs in a user."""
        try:
            payload = {"username": username, "password": password}
            response = self.client.post("/users/login", json=payload)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Error logging in: {e}")
            return None

    def get_users(self) -> list:
        """Fetches all users."""
        try:
            response = self.client.get("/users/")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Error fetching users: {e}")
            return []

    def get_statistics(self) -> dict:
        """Fetches statistics and Hall of Fame."""
        try:
            response = self.client.get("/events/stats")
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Error fetching statistics: {e}")
            return None

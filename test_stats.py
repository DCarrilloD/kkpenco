import httpx

try:
    resp = httpx.get("http://127.0.0.1:8000/events/stats")
    print(resp.status_code)
    print(resp.json())
except Exception as e:
    print(e)

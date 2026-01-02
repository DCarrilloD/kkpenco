import httpx
try:
    print("Testing connection to https://kkpenco.duckdns.org/...")
    # Try with verification enabled first (default)
    r = httpx.get("https://kkpenco.duckdns.org/docs", timeout=10)
    print(f"Status Code: {r.status_code}")
    print("Success!")
except Exception as e:
    print(f"Error: {e}")
    # Try without verification just to see if it's an SSL issue
    try:
        print("Retrying with verify=False...")
        r = httpx.get("https://kkpenco.duckdns.org/docs", timeout=10, verify=False)
        print(f"Status Code (No Verify): {r.status_code}")
        print("Success (No Verify)!")
    except Exception as ex:
        print(f"Error (No Verify): {ex}")

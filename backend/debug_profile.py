
import requests
import datetime

adult_email = "adult@example.com"
adult_pass = "adult123"
BASE_URL = "http://127.0.0.1:8000"

try:
    r = requests.post(f"{BASE_URL}/login", json={"email": adult_email, "password": adult_pass})
    if r.status_code != 200:
        print(f"Login failed: {r.text}")
        exit()
    token = r.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    params = {
        "first_name": "Adult", "last_name": "User", 
        "date_of_birth": (datetime.datetime.now() - datetime.timedelta(days=365*25)).isoformat(),
        "passport_number": "ADULT123", "nationality": "US"
    }
    r = requests.post(f"{BASE_URL}/passenger/profile", headers=headers, json=params)
    print(f"Status: {r.status_code}")
    print(f"Body: {r.text}")
except Exception as e:
    print(f"Error: {e}")

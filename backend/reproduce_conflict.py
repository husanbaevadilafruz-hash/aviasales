
import requests
from datetime import datetime, timedelta

BASE_URL = "http://127.0.0.1:8000"

def test_conflict():
    print("Testing flight conflict logic...")
    
    # 1. Register/Login Staff
    staff_email = "staff_conflict_test@example.com"
    staff_pass = "staff123"
    
    try:
        requests.post(f"{BASE_URL}/register", json={"email": staff_email, "password": staff_pass, "role": "STAFF"})
    except:
        pass
        
    r = requests.post(f"{BASE_URL}/login", json={"email": staff_email, "password": staff_pass})
    if r.status_code != 200:
        print("Failed to login staff")
        return
    token = r.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    # 2. Get/Create Airplane
    r = requests.get(f"{BASE_URL}/airplanes", headers=headers)
    airplanes = r.json()
    if not airplanes:
         print("No airplanes found. Create one first.")
         return
    airplane_id = airplanes[0]['id']
    print(f"Using airplane {airplane_id}")
    
    # 3. Get/Create Airports
    r = requests.get(f"{BASE_URL}/airports", headers=headers)
    airports = r.json()
    id1 = airports[0]['id']
    id2 = airports[1]['id']

    # 4. Create Flight A: 2026-05-30 12:00 - 14:00
    date_a = "2026-05-30"
    payload_a = {
        "flight_number": "TEST_A",
        "departure_airport_id": id1,
        "arrival_airport_id": id2,
        "departure_time": f"{date_a}T12:00:00",
        "arrival_time": f"{date_a}T14:00:00",
        "airplane_id": airplane_id,
        "base_price": 100
    }
    r = requests.post(f"{BASE_URL}/flights", headers=headers, json=payload_a)
    if r.status_code == 201:
        print("Flight A created successfully")
        flight_a_id = r.json()['id']
    else:
        print(f"Flight A creation failed: {r.text}")
        return

    # 5. Create Flight B: 2026-05-31 12:00 - 14:00 (Next day, same time)
    date_b = "2026-05-31" 
    payload_b = {
        "flight_number": "TEST_B",
        "departure_airport_id": id1,
        "arrival_airport_id": id2,
        "departure_time": f"{date_b}T12:00:00",
        "arrival_time": f"{date_b}T14:00:00",
        "airplane_id": airplane_id,
        "base_price": 100
    }
    
    print(f"Attempting to create Flight B on {date_b} (should SUCCEED)...")
    r = requests.post(f"{BASE_URL}/flights", headers=headers, json=payload_b)
    if r.status_code == 201:
        print("PASS: Flight B created (Different days allowed)")
        # Cleanup
        requests.patch(f"{BASE_URL}/flights/{r.json()['id']}", headers=headers, json={"status": "CANCELLED"})
    else:
        print(f"FAIL: Flight B rejected: {r.text}")

    # Cleanup Flight A
    requests.patch(f"{BASE_URL}/flights/{flight_a_id}", headers=headers, json={"status": "CANCELLED"})

if __name__ == "__main__":
    test_conflict()

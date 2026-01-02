
import requests
from datetime import datetime, timedelta

BASE_URL = "http://127.0.0.1:8000"

def test_validations():
    print("Testing validations...")
    
    # 1. Login Staff
    staff_email = "staff_validation@example.com"
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
    
    # Get Airplane & Airports
    r = requests.get(f"{BASE_URL}/airplanes", headers=headers)
    airplanes = r.json()
    if not airplanes:
         print("No airplanes found. Create one first.")
         return
    airplane_id = airplanes[0]['id']
    
    r = requests.get(f"{BASE_URL}/airports", headers=headers)
    airports = r.json()
    id1 = airports[0]['id']
    id2 = airports[1]['id']

    # TEST 1: Same Origin and Destination
    print("\n[TEST 1] Create flight with Same Origin/Dest (Expect FAIL)")
    date_a = "2027-01-01"
    payload_fail = {
        "flight_number": "FAIL_100",
        "departure_airport_id": id1,
        "arrival_airport_id": id1, # SAME!
        "departure_time": f"{date_a}T12:00:00",
        "arrival_time": f"{date_a}T14:00:00",
        "airplane_id": airplane_id,
        "base_price": 100
    }
    r = requests.post(f"{BASE_URL}/flights", headers=headers, json=payload_fail)
    if r.status_code == 400 and "Аэропорт отправления и прибытия не могут совпадать" in r.text:
        print("PASS: Same airport check working.")
    else:
        print(f"FAIL: Expected 400, got {r.status_code} {r.text}")

    # TEST 2: Cancel DEPARTED flight
    print("\n[TEST 2] Cancel DEPARTED flight (Expect FAIL)")
    # Create valid flight
    payload_ok = payload_fail.copy()
    payload_ok["arrival_airport_id"] = id2
    payload_ok["flight_number"] = "TEST_DEPARTED"
    
    r = requests.post(f"{BASE_URL}/flights", headers=headers, json=payload_ok)
    if r.status_code == 201:
        flight_id = r.json()['id']
        
        # Set status to DEPARTED
        requests.patch(f"{BASE_URL}/flights/{flight_id}", headers=headers, json={"status": "DEPARTED"})
        
        # Try to CANCEL
        r = requests.patch(f"{BASE_URL}/flights/{flight_id}", headers=headers, json={"status": "CANCELLED"})
        if r.status_code == 400 and "Нельзя отменить рейс который уже вылетел" in r.text:
             print("PASS: Cancel departed check working.")
        else:
             print(f"FAIL: Expected 400, got {r.status_code} {r.text}")
    else:
        print(f"Could not create test flight: {r.text}")

if __name__ == "__main__":
    test_validations()

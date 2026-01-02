
import requests
import datetime

BASE_URL = "http://127.0.0.1:8000"

def test_passenger_features():
    print("=== STARTING PASSENGER FEATURES VERIFICATION ===")

    # 1. SETUP (As Staff)
    print("\n[SETUP] Creating Test Data...")
    staff_email = "staff_pax_test@example.com"
    staff_pass = "staff123"
    
    # Register/Login Staff
    try:
        requests.post(f"{BASE_URL}/register", json={"email": staff_email, "password": staff_pass, "role": "STAFF"})
    except: pass
    
    r_staff = requests.post(f"{BASE_URL}/login", json={"email": staff_email, "password": staff_pass})
    if r_staff.status_code != 200:
        print("FAIL: Could not login staff")
        return
    staff_token = r_staff.json()["access_token"]
    staff_headers = {"Authorization": f"Bearer {staff_token}"}

    # Create Airplane
    r = requests.post(f"{BASE_URL}/airplanes", headers=staff_headers, json={
        "model": "PaxTest Plane", "total_seats": 100, "rows": 20, "seats_per_row": 6, "seat_letters": "ABCDEF"
    })
    if r.status_code not in [200, 201]: print(f"FAIL: Create Airplane {r.text}"); return
    airplane_id = r.json()["id"]

    # Get Airports
    r = requests.get(f"{BASE_URL}/airports", headers=staff_headers)
    airports = r.json()
    if len(airports) < 2: print("FAIL: Need 2 airports"); return
    
    # Create Flight (Future)
    date_future = (datetime.datetime.now() + datetime.timedelta(days=30)).date().isoformat()
    r = requests.post(f"{BASE_URL}/flights", headers=staff_headers, json={
        "flight_number": "PAX-100",
        "departure_airport_id": airports[0]['id'],
        "arrival_airport_id": airports[1]['id'],
        "departure_time": f"{date_future}T10:00:00",
        "arrival_time": f"{date_future}T14:00:00",
        "airplane_id": airplane_id,
        "base_price": 5000
    })
    if r.status_code != 201: print(f"FAIL: Create Flight {r.text}"); return
    flight_id = r.json()["id"]
    print(f"PASS: Setup Complete. Flight ID: {flight_id}")


    # 2. TEST: Underage Registration (Backend Check?? No, Registration is just User. Profile is Separate)
    # Wait, implementation plan said Age Check is in create_passenger_profile.
    # So Registration succeeds, Profile creation fails.
    
    print("\n[TEST] Underage Passenger Profile")
    pax_email = "kid@example.com"
    pax_pass = "kid123"
    
    requests.post(f"{BASE_URL}/register", json={"email": pax_email, "password": pax_pass, "role": "PASSENGER"})
    r_kid = requests.post(f"{BASE_URL}/login", json={"email": pax_email, "password": pax_pass})
    kid_token = r_kid.json()["access_token"]
    kid_headers = {"Authorization": f"Bearer {kid_token}"}
    
    params_kid = {
        "first_name": "Kid", "last_name": "User", 
        "date_of_birth": (datetime.datetime.now() - datetime.timedelta(days=365*10)).isoformat(), # 10 years old
        "passport_number": "KID123", "nationality": "US"
    }
    r = requests.post(f"{BASE_URL}/passenger/profile", headers=kid_headers, json=params_kid)
    if r.status_code == 400 and "at least 16 years old" in r.text:
        print("PASS: Underage profile blocked.")
    else:
        print(f"FAIL: Expected 400 for underage, got {r.status_code} {r.text}")


    # 3. TEST: Adult Passenger
    print("\n[TEST] Adult Passenger Flow")
    adult_email = "adult@example.com"
    adult_pass = "adult123"
    
    requests.post(f"{BASE_URL}/register", json={"email": adult_email, "password": adult_pass, "role": "PASSENGER"})
    r_adult = requests.post(f"{BASE_URL}/login", json={"email": adult_email, "password": adult_pass})
    adult_token = r_adult.json()["access_token"]
    adult_headers = {"Authorization": f"Bearer {adult_token}"}
    
    params_adult = {
        "first_name": "Adult", "last_name": "User", 
        "date_of_birth": (datetime.datetime.now() - datetime.timedelta(days=365*25)).isoformat(), # 25 years old
        "passport_number": "ADULT123", "nationality": "US"
    }
    r = requests.post(f"{BASE_URL}/passenger/profile", headers=adult_headers, json=params_adult)
    if r.status_code not in [200, 201]:
        print(f"FAIL: Create Profile {r.text}")
        return
    print("PASS: Profile Created")
    
    # 4. TEST: Book Flight
    print("\n[TEST] Book Flight")
    # Get Seat
    r = requests.get(f"{BASE_URL}/flights/{flight_id}/seat-map", headers=adult_headers)
    seats = r.json()['seats']
    avail_seats = [s for s in seats if s['status'] == 'AVAILABLE']
    seat_id = avail_seats[0]['id']
    
    # Hold Seat
    requests.post(f"{BASE_URL}/seats/{seat_id}/hold", headers=adult_headers)
    
    # Book
    r = requests.post(f"{BASE_URL}/bookings", headers=adult_headers, json={
        "flight_id": flight_id, "seat_ids": [seat_id]
    })
    if r.status_code == 201:
        booking_id = r.json()['id']
        print(f"PASS: Flight Booked. Booking ID: {booking_id}")
    else:
        print(f"FAIL: Book Flight {r.text}")
        return

    # 5. TEST: Double Booking
    print("\n[TEST] Double Booking Validation")
    # Try book another seat on SAME flight
    seat_id_2 = avail_seats[1]['id']
    requests.post(f"{BASE_URL}/seats/{seat_id_2}/hold", headers=adult_headers)
    
    r = requests.post(f"{BASE_URL}/bookings", headers=adult_headers, json={
        "flight_id": flight_id, "seat_ids": [seat_id_2]
    })
    if r.status_code == 400 and "already have a booking" in r.text:
        print("PASS: Double booking blocked.")
    else:
        print(f"FAIL: Expected 400 for double booking, got {r.status_code} {r.text}")

    # 6. TEST: Cancel Booking
    print("\n[TEST] Cancel Booking")
    r = requests.post(f"{BASE_URL}/bookings/{booking_id}/cancel", headers=adult_headers)
    if r.status_code == 200:
        print("PASS: Booking Cancelled")
    else:
        print(f"FAIL: Cancel Booking {r.text}")

    print("\n=== VERIFICATION COMPLETE ===")

if __name__ == "__main__":
    test_passenger_features()

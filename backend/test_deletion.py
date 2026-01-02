
import requests
import json

BASE_URL = "http://localhost:8000"

def test_flow():
    # 1. Register/Login Staff
    staff_email = "staff_admin@example.com"
    staff_pass = "staff123"
    
    try:
        r = requests.post(f"{BASE_URL}/register", json={"email": staff_email, "password": staff_pass, "role": "STAFF"})
    except:
        pass # maybe already exists
        
    r = requests.post(f"{BASE_URL}/login", json={"email": staff_email, "password": staff_pass})
    if r.status_code != 200:
        print("Failed to login staff")
        return
    staff_token = r.json()["access_token"]
    staff_headers = {"Authorization": f"Bearer {staff_token}"}
    
    # 2. Register/Login Passenger
    pass_email = "passenger_test@example.com"
    pass_pass = "pass123"
    
    try:
        r = requests.post(f"{BASE_URL}/register", json={"email": pass_email, "password": pass_pass, "role": "PASSENGER"})
    except:
        pass
        
    r = requests.post(f"{BASE_URL}/login", json={"email": pass_email, "password": pass_pass})
    if r.status_code != 200:
        print("Failed to login passenger")
        return
    pass_token = r.json()["access_token"]
    pass_headers = {"Authorization": f"Bearer {pass_token}"}
    
    # Create profile for passenger
    requests.post(f"{BASE_URL}/passenger/profile", headers=pass_headers, json={
        "first_name": "Test", "last_name": "Passenger", 
        "date_of_birth": "1990-01-01T00:00:00", 
        "passport_number": "123456", "phone": "12345"
    })
    
    # 3. Create Airports (if not exist)
    requests.post(f"{BASE_URL}/airports", headers=staff_headers, json={
        "code": "TST1", "name": "Test1", "city": "City1", "country": "Country1"
    })
    requests.post(f"{BASE_URL}/airports", headers=staff_headers, json={
        "code": "TST2", "name": "Test2", "city": "City2", "country": "Country1"
    })
    
    # Get airport IDs
    airports = requests.get(f"{BASE_URL}/airports", headers=staff_headers).json()
    id1 = next(a['id'] for a in airports if a['code'] == 'TST1')
    id2 = next(a['id'] for a in airports if a['code'] == 'TST2')
    
    # 4. Create Airplane
    r = requests.post(f"{BASE_URL}/airplanes", headers=staff_headers, json={
        "model": "Test Plane Delete",
        "seats": [{"seat_number": "1A"}, {"seat_number": "1B"}]
    })
    if r.status_code != 201:
        print(f"Failed to create airplane: {r.text}")
        return
    airplane = r.json()
    airplane_id = airplane["id"]
    print(f"Created airplane {airplane_id}")
    
    # 5. Create Flight
    r = requests.post(f"{BASE_URL}/flights", headers=staff_headers, json={
        "flight_number": "DEL100",
        "departure_airport_id": id1,
        "arrival_airport_id": id2,
        "departure_time": "2026-01-01T10:00:00",
        "arrival_time": "2026-01-01T12:00:00",
        "airplane_id": airplane_id,
        "base_price": 100.0
    })
    if r.status_code != 201:
        print(f"Failed to create flight: {r.text}")
        return
    flight = r.json()
    flight_id = flight["id"]
    print(f"Created flight {flight_id} ({flight['flight_number']})")
    
    # 6. Create Booking
    # Get seats
    r = requests.get(f"{BASE_URL}/flights/{flight_id}/seat-map", headers=pass_headers)
    seats = r.json()["seats"]
    seat_id = seats[0]["id"]
    
    r = requests.post(f"{BASE_URL}/bookings", headers=pass_headers, json={
        "flight_id": flight_id,
        "seat_ids": [seat_id]
    })
    if r.status_code != 201:
        print(f"Failed to booking: {r.text}")
        return
    booking = r.json()
    booking_id = booking["id"]
    print(f"Created booking {booking_id}")
    
    # 7. DELETE AIRPLANE
    print("Deleting airplane...")
    r = requests.delete(f"{BASE_URL}/airplanes/{airplane_id}", headers=staff_headers)
    if r.status_code != 204:
        print(f"Failed to delete airplane: {r.text}")
        return
    print("Airplane deleted.")
    
    # 8. VERIFY
    print("Verifying...")
    
    # Check flight status
    r = requests.get(f"{BASE_URL}/flights/{flight_id}", headers=staff_headers) # using staff to see it
    flight_after = r.json()
    print(f"Flight status: {flight_after['status']}")
    
    if flight_after['status'] != 'CANCELLED':
        print("FAIL: Flight was not cancelled")
    else:
        print("PASS: Flight cancelled")
        
    # Check booking status
    r = requests.get(f"{BASE_URL}/bookings/all", headers=staff_headers)
    all_bookings = r.json()
    my_booking = next((b for b in all_bookings if b['id'] == booking_id), None)
    
    if my_booking and my_booking['status'] == 'CANCELLED':
        print("PASS: Booking cancelled")
    else:
        print(f"FAIL: Booking status is {my_booking['status'] if my_booking else 'Not Found'}")

if __name__ == "__main__":
    test_flow()


import sys
import os

# Assuming running from backend/ dir
# sys.path is already current dir

from main import create_passenger_profile
from schemas import PassengerProfileCreate
from models import User
from database import SessionLocal
import datetime

# Mock user
class MockUser:
    id = 1
    email = "test@test.com"

user = MockUser()

# Payload
profile_data = PassengerProfileCreate(
    first_name="Test", last_name="User",
    date_of_birth=datetime.datetime.now(),
    passport_number="123",
    nationality="US",
    phone="123456"
)

# DB
db = SessionLocal()

try:
    print("Calling create_passenger_profile...")
    create_passenger_profile(profile_data, user, db)
    print("SUCCESS")
except Exception as e:
    import traceback
    traceback.print_exc()
finally:
    db.close()

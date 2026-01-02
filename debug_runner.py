
import sys
import os

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from backend.main import create_passenger_profile
from backend.schemas import PassengerProfileCreate
from backend.models import User
from backend.database import SessionLocal
import datetime

# Mock user
# We need a user that exists or just an object with id if the function only uses id.
# Function uses current_user.id.
class MockUser:
    id = 1
    email = "test@test.com"

user = MockUser()

# Payload
# Pydantic model requires valid types
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

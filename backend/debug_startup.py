import traceback
import sys
import schemas
print(f"Schemas loaded from: {schemas.__file__}")
print(f"Has PassengerProfileResponse: {hasattr(schemas, 'PassengerProfileResponse')}")

try:
    import main
    print("Success")
except Exception:
    traceback.print_exc()
    sys.exit(1)

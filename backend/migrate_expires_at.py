import sqlite3
import os

DB_PATH = "aviasales.db"

def migrate():
    if not os.path.exists(DB_PATH):
        print(f"Error: Database {DB_PATH} not found.")
        return

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    try:
        # Check if column exists in bookings
        cursor.execute("PRAGMA table_info(bookings)")
        columns = [info[1] for info in cursor.fetchall()]
        
        if "expires_at" in columns:
            print("Column 'expires_at' already exists in 'bookings' table.")
        else:
            print("Adding 'expires_at' column to 'bookings' table...")
            # Add column with default value Null or some calculated value
            # Since it's nullable, Null is fine.
            cursor.execute("ALTER TABLE bookings ADD COLUMN expires_at DATETIME")
            conn.commit()
            print("Column 'expires_at' added successfully.")
            
        # Verify
        cursor.execute("PRAGMA table_info(bookings)")
        columns_after = [info[1] for info in cursor.fetchall()]
        if "expires_at" in columns_after:
             print("VERIFICATION: PASS - 'expires_at' column is present.")
        else:
             print("VERIFICATION: FAIL - 'expires_at' column is MISSING.")

    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()

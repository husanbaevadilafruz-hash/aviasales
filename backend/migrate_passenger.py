
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
        # Check if column exists
        cursor.execute("PRAGMA table_info(passenger_profiles)")
        columns = [info[1] for info in cursor.fetchall()]
        
        if "nationality" in columns:
            print("Column 'nationality' already exists in 'passenger_profiles' table.")
        else:
            print("Adding 'nationality' column to 'passenger_profiles' table...")
            # Add column
            cursor.execute("ALTER TABLE passenger_profiles ADD COLUMN nationality TEXT")
            conn.commit()
            print("Column added successfully.")
            
        # Verify
        cursor.execute("PRAGMA table_info(passenger_profiles)")
        columns_after = [info[1] for info in cursor.fetchall()]
        if "nationality" in columns_after:
             print("VERIFICATION: PASS - 'nationality' column is present.")
        else:
             print("VERIFICATION: FAIL - 'nationality' column is MISSING.")

    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()

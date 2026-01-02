
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
        cursor.execute("PRAGMA table_info(airplanes)")
        columns = [info[1] for info in cursor.fetchall()]
        
        if "is_active" in columns:
            print("Column 'is_active' already exists in 'airplanes' table.")
        else:
            print("Adding 'is_active' column to 'airplanes' table...")
            # Add column with default value True (1)
            cursor.execute("ALTER TABLE airplanes ADD COLUMN is_active BOOLEAN DEFAULT 1")
            conn.commit()
            print("Column added successfully.")
            
        # Verify
        cursor.execute("PRAGMA table_info(airplanes)")
        columns_after = [info[1] for info in cursor.fetchall()]
        if "is_active" in columns_after:
             print("VERIFICATION: PASS - 'is_active' column is present.")
        else:
             print("VERIFICATION: FAIL - 'is_active' column is MISSING.")

    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()

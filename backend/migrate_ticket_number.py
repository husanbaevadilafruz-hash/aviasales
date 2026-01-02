
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
        cursor.execute("PRAGMA table_info(passengers)")
        columns = [info[1] for info in cursor.fetchall()]
        
        if "ticket_number" in columns:
            print("Column 'ticket_number' already exists in 'passengers' table.")
        else:
            print("Adding 'ticket_number' column to 'passengers' table...")
            # Add column
            cursor.execute("ALTER TABLE passengers ADD COLUMN ticket_number TEXT")
            conn.commit()
            print("Column added successfully.")
            
        # Verify
        cursor.execute("PRAGMA table_info(passengers)")
        columns_after = [info[1] for info in cursor.fetchall()]
        if "ticket_number" in columns_after:
             print("VERIFICATION: PASS - 'ticket_number' column is present.")
        else:
             print("VERIFICATION: FAIL - 'ticket_number' column is MISSING.")

    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()

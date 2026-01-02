"""Add nationality column to passenger_profiles table"""
import sqlite3
from pathlib import Path

db_path = Path(__file__).parent / "aviasales.db"

if not db_path.exists():
    print(f"Database not found: {db_path}")
    raise SystemExit(1)

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    cursor.execute("PRAGMA table_info(passenger_profiles)")
    columns = [col[1] for col in cursor.fetchall()]

    if "nationality" in columns:
        print("Column 'nationality' already exists")
    else:
        cursor.execute("ALTER TABLE passenger_profiles ADD COLUMN nationality TEXT")
        conn.commit()
        print("Column 'nationality' added successfully!")
except Exception as e:
    print(f"Error: {e}")
finally:
    conn.close()



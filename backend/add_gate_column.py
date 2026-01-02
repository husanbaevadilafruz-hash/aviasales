"""Add gate column to flights table"""
import sqlite3
from pathlib import Path

db_path = Path(__file__).parent / "aviasales.db"

if not db_path.exists():
    print(f"Database not found: {db_path}")
    raise SystemExit(1)

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    cursor.execute("PRAGMA table_info(flights)")
    columns = [col[1] for col in cursor.fetchall()]

    if "gate" in columns:
        print("Column 'gate' already exists")
    else:
        cursor.execute("ALTER TABLE flights ADD COLUMN gate TEXT DEFAULT ''")
        conn.commit()
        print("Column 'gate' added successfully!")
except Exception as e:
    print(f"Error: {e}")
finally:
    conn.close()



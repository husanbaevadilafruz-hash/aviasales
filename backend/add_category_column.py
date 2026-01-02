"""Add category column to seats table"""
import sqlite3
from pathlib import Path

db_path = Path(__file__).parent / "aviasales.db"

if not db_path.exists():
    print(f"Database not found: {db_path}")
    exit(1)

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    # Check if column exists
    cursor.execute("PRAGMA table_info(seats)")
    columns = [col[1] for col in cursor.fetchall()]
    
    if "category" in columns:
        print("Column 'category' already exists")
    else:
        cursor.execute("ALTER TABLE seats ADD COLUMN category TEXT DEFAULT 'STANDARD'")
        conn.commit()
        print("Column 'category' added successfully!")
except Exception as e:
    print(f"Error: {e}")
finally:
    conn.close()


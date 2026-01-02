"""Add pnr column to bookings table, backfill missing values, and create unique index."""
import sqlite3
import random
import string
from pathlib import Path

db_path = Path(__file__).parent / "aviasales.db"

if not db_path.exists():
    print(f"Database not found: {db_path}")
    raise SystemExit(1)


def gen_pnr() -> str:
    alphabet = string.ascii_uppercase + string.digits
    return "".join(random.choice(alphabet) for _ in range(6))


conn = sqlite3.connect(db_path)
cursor = conn.cursor()

try:
    cursor.execute("PRAGMA table_info(bookings)")
    columns = [col[1] for col in cursor.fetchall()]

    if "pnr" not in columns:
        cursor.execute("ALTER TABLE bookings ADD COLUMN pnr TEXT")
        conn.commit()
        print("Column 'pnr' added successfully!")
    else:
        print("Column 'pnr' already exists")

    # Backfill NULL/empty pnr values
    cursor.execute("SELECT id, pnr FROM bookings")
    rows = cursor.fetchall()
    existing = {r[1] for r in rows if r[1]}
    updated = 0
    for booking_id, pnr in rows:
        if pnr:
            continue
        candidate = gen_pnr()
        while candidate in existing:
            candidate = gen_pnr()
        existing.add(candidate)
        cursor.execute("UPDATE bookings SET pnr = ? WHERE id = ?", (candidate, booking_id))
        updated += 1
    if updated:
        conn.commit()
    print(f"Backfilled PNR for {updated} bookings")

    # Create unique index (idempotent-ish)
    try:
        cursor.execute("CREATE UNIQUE INDEX idx_bookings_pnr ON bookings(pnr)")
        conn.commit()
        print("Unique index idx_bookings_pnr created")
    except Exception as e:
        # likely already exists
        print(f"Skipping unique index creation: {e}")

except Exception as e:
    print(f"Error: {e}")
finally:
    conn.close()



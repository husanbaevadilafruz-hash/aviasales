"""
Скрипт миграции: исправление NOT NULL ограничений в таблице passengers.

SQLite не поддерживает ALTER COLUMN, поэтому нужно пересоздать таблицу.
"""

import sqlite3

def migrate():
    # Подключаемся к базе данных
    conn = sqlite3.connect("aviasales.db")
    cursor = conn.cursor()
    
    try:
        # Получаем текущую схему таблицы passengers
        cursor.execute("PRAGMA table_info(passengers)")
        columns = cursor.fetchall()
        print("Current passengers table schema:")
        for col in columns:
            print(f"  {col}")
        
        # Проверяем, есть ли проблема с NOT NULL
        # В SQLite: col[3] = notnull (1 = NOT NULL, 0 = NULL allowed)
        full_name_col = next((col for col in columns if col[1] == 'full_name'), None)
        if full_name_col and full_name_col[3] == 1:
            print("\nPROBLEM DETECTED: full_name has NOT NULL constraint")
            print("Starting migration...")
            
            # 1. Создаём временную таблицу с правильной схемой
            cursor.execute("""
                CREATE TABLE passengers_new (
                    id INTEGER PRIMARY KEY,
                    seat_id INTEGER NOT NULL REFERENCES seats(id),
                    booking_id INTEGER NOT NULL REFERENCES bookings(id),
                    full_name TEXT,
                    birth_date DATETIME,
                    document_number TEXT,
                    ticket_number TEXT UNIQUE
                )
            """)
            print("Created new table with correct schema")
            
            # 2. Копируем данные
            cursor.execute("""
                INSERT INTO passengers_new (id, seat_id, booking_id, full_name, birth_date, document_number, ticket_number)
                SELECT id, seat_id, booking_id, full_name, birth_date, document_number, ticket_number
                FROM passengers
            """)
            print("Copied data to new table")
            
            # 3. Удаляем старую таблицу
            cursor.execute("DROP TABLE passengers")
            print("Dropped old table")
            
            # 4. Переименовываем новую таблицу
            cursor.execute("ALTER TABLE passengers_new RENAME TO passengers")
            print("Renamed new table to passengers")
            
            # Создаём индексы
            cursor.execute("CREATE INDEX IF NOT EXISTS ix_passengers_id ON passengers(id)")
            print("Created index")
            
            conn.commit()
            print("\nMigration completed successfully!")
            
            # Проверяем новую схему
            cursor.execute("PRAGMA table_info(passengers)")
            columns = cursor.fetchall()
            print("\nNew passengers table schema:")
            for col in columns:
                print(f"  {col}")
        else:
            print("\nNo migration needed - full_name already allows NULL")
            
    except Exception as e:
        conn.rollback()
        print(f"ERROR: {e}")
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    migrate()

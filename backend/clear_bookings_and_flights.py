"""
Скрипт для удаления всех рейсов и бронирований из базы данных
Использует прямой SQL для избежания циклических импортов
"""

import sqlite3
from pathlib import Path

def clear_all_bookings_and_flights():
    """Удаляет все брони и рейсы из базы данных"""
    db_path = Path(__file__).parent / "aviasales.db"
    
    if not db_path.exists():
        print(f"База данных не найдена: {db_path}")
        return
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Удаляем все связанные данные
        print("Удаление платежей...")
        cursor.execute("DELETE FROM payments")
        deleted_payments = cursor.rowcount
        print(f"Удалено платежей: {deleted_payments}")
        
        print("Удаление билетов...")
        cursor.execute("DELETE FROM tickets")
        deleted_tickets = cursor.rowcount
        print(f"Удалено билетов: {deleted_tickets}")
        
        print("Удаление бронирований...")
        cursor.execute("DELETE FROM bookings")
        deleted_bookings = cursor.rowcount
        print(f"Удалено бронирований: {deleted_bookings}")
        
        # Освобождаем все места
        print("Освобождение мест...")
        cursor.execute("UPDATE seats SET status = 'AVAILABLE', held_until = NULL WHERE status != 'AVAILABLE'")
        freed_seats = cursor.rowcount
        print(f"Освобождено мест: {freed_seats}")
        
        print("Удаление рейсов...")
        cursor.execute("DELETE FROM flights")
        deleted_flights = cursor.rowcount
        print(f"Удалено рейсов: {deleted_flights}")
        
        # Также удаляем места, так как они связаны с рейсами
        cursor.execute("DELETE FROM seats")
        deleted_seats = cursor.rowcount
        print(f"Удалено мест: {deleted_seats}")
        
        # Подтверждаем изменения
        conn.commit()
        print("\nУспешно! Все рейсы и бронирования удалены!")
        
    except Exception as e:
        print(f"\nОшибка: {e}")
        conn.rollback()
    finally:
        conn.close()

if __name__ == "__main__":
    confirm = input("Вы уверены, что хотите удалить ВСЕ рейсы и бронирования? (yes/no): ")
    if confirm.lower() == "yes":
        clear_all_bookings_and_flights()
    else:
        print("Операция отменена.")


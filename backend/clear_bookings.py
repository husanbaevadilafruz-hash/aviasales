"""
clear_bookings.py - Скрипт для удаления всех бронирований и освобождения мест
"""

from database import SessionLocal, engine
from models import Booking, Passenger, Seat, SeatStatus
from sqlalchemy import text

def clear_bookings():
    db = SessionLocal()
    try:
        # 1. Удаляем все платежи
        db.execute(text("DELETE FROM payments"))
        print("✓ Удалены все платежи")
        
        # 2. Удаляем всех пассажиров (билеты)
        db.execute(text("DELETE FROM passengers"))
        print("✓ Удалены все пассажиры (билеты)")
        
        # 3. Удаляем все бронирования
        db.execute(text("DELETE FROM bookings"))
        print("✓ Удалены все бронирования")
        
        # 4. Освобождаем все места
        db.execute(text("UPDATE seats SET status = ?, held_until = NULL"), [SeatStatus.AVAILABLE])
        print("✓ Все места освобождены")
        
        # 5. Удаляем все уведомления
        db.execute(text("DELETE FROM notifications"))
        print("✓ Удалены все уведомления")
        
        db.commit()
        print("\n✅ База данных очищена успешно!")
        
    except Exception as e:
        db.rollback()
        print(f"❌ Ошибка: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    clear_bookings()

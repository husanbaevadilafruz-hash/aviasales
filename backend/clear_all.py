"""
clear_all.py - Скрипт для удаления всех рейсов, бронирований и очистки БД
"""

from database import SessionLocal, engine
from models import Booking, Passenger, Seat, SeatStatus, Flight, Payment, Notification, CheckIn
from sqlalchemy import text

def clear_all():
    db = SessionLocal()
    try:
        # 1. Удаляем все check-ins
        db.execute(text("DELETE FROM check_ins"))
        print("✓ Удалены все check-ins")
        
        # 2. Удаляем все платежи
        db.execute(text("DELETE FROM payments"))
        print("✓ Удалены все платежи")
        
        # 3. Удаляем всех пассажиров (билеты)
        db.execute(text("DELETE FROM passengers"))
        print("✓ Удалены все пассажиры (билеты)")
        
        # 4. Удаляем все бронирования
        db.execute(text("DELETE FROM bookings"))
        print("✓ Удалены все бронирования")
        
        # 5. Удаляем все уведомления
        db.execute(text("DELETE FROM notifications"))
        print("✓ Удалены все уведомления")
        
        # 6. Освобождаем все места
        db.execute(text("UPDATE seats SET status = ?, held_until = NULL"), [SeatStatus.AVAILABLE])
        print("✓ Все места освобождены")
        
        # 7. Удаляем все рейсы
        db.execute(text("DELETE FROM flights"))
        print("✓ Удалены все рейсы")
        
        db.commit()
        print("\n✅ База данных полностью очищена!")
        
    except Exception as e:
        db.rollback()
        print(f"❌ Ошибка: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    clear_all()

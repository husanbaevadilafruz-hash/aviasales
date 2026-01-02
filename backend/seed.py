"""
seed.py - Скрипт для создания тестовых данных

Этот скрипт создаёт начальные данные в базе:
- Тестовых пользователей (пассажир и сотрудник)
- Аэропорты
- Самолёты с местами
- Рейсы

Запускается один раз для заполнения базы тестовыми данными.
"""

from sqlalchemy.orm import Session
from database import SessionLocal, engine, Base
from models import User, PassengerProfile, Airport, Airplane, Seat, Flight, UserRole, SeatStatus, FlightStatus
from auth import get_password_hash
from datetime import datetime, timedelta

# Создаём все таблицы
Base.metadata.create_all(bind=engine)

db: Session = SessionLocal()


def seed_data():
    """Создание тестовых данных"""
    
    print("Начинаем заполнение базы данных тестовыми данными...")
    
    # ============================================
    # 1. СОЗДАНИЕ ПОЛЬЗОВАТЕЛЕЙ
    # ============================================
    
    print("Создаём пользователей...")
    
    # Пассажир
    passenger_user = db.query(User).filter(User.email == "passenger@test.com").first()
    if not passenger_user:
        passenger_user = User(
            email="passenger@test.com",
            hashed_password=get_password_hash("password123"),
            role=UserRole.PASSENGER
        )
        db.add(passenger_user)
        db.flush()
        
        # Профиль пассажира
        passenger_profile = PassengerProfile(
            user_id=passenger_user.id,
            first_name="Иван",
            last_name="Иванов",
            date_of_birth=datetime(1990, 5, 15),
            passport_number="1234567890",
            phone="+79991234567"
        )
        db.add(passenger_profile)
        print("[OK] Создан пассажир: passenger@test.com / password123")
    else:
        print("[INFO] Пассажир уже существует")
    
    # ============================================
    # СОЗДАНИЕ STAFF ПОЛЬЗОВАТЕЛЕЙ
    # ============================================
    # STAFF - это сотрудники авиакомпании
    # Они НЕ регистрируются через публичный API
    # Создаются ТОЛЬКО через seed.py с заранее заданными данными
    # Затем входят через обычный /login и получают JWT токен
    
    staff_users_data = [
        {"email": "staff@test.com", "password": "password123"},
        {"email": "staff1@airline.com", "password": "staff123"},
    ]
    
    for staff_data in staff_users_data:
        staff_user = db.query(User).filter(User.email == staff_data["email"]).first()
        if not staff_user:
            staff_user = User(
                email=staff_data["email"],
                hashed_password=get_password_hash(staff_data["password"]),
                role=UserRole.STAFF
            )
            db.add(staff_user)
            print(f"[OK] Создан сотрудник: {staff_data['email']} / {staff_data['password']}")
        else:
            print(f"[INFO] Сотрудник {staff_data['email']} уже существует")
    
    db.commit()
    
    # ============================================
    # 2. СОЗДАНИЕ АЭРОПОРТОВ
    # ============================================
    
    print("Создаём аэропорты...")
    
    airports_data = [
        {"code": "SVO", "name": "Шереметьево", "city": "Москва", "country": "Россия"},
        {"code": "LED", "name": "Пулково", "city": "Санкт-Петербург", "country": "Россия"},
        {"code": "DME", "name": "Домодедово", "city": "Москва", "country": "Россия"},
        {"code": "AER", "name": "Сочи", "city": "Сочи", "country": "Россия"},
        {"code": "KRR", "name": "Пашковский", "city": "Краснодар", "country": "Россия"},
    ]
    
    airports = {}
    for airport_data in airports_data:
        airport = db.query(Airport).filter(Airport.code == airport_data["code"]).first()
        if not airport:
            airport = Airport(**airport_data)
            db.add(airport)
        airports[airport_data["code"]] = airport
    
    db.commit()
    print(f"[OK] Создано {len(airports)} аэропортов")
    
    # ============================================
    # 3. СОЗДАНИЕ САМОЛЁТОВ
    # ============================================
    
    print("Создаём самолёты...")
    
    # Самолёт 1: Boeing 737 (маленький, 12 мест)
    airplane1 = db.query(Airplane).filter(Airplane.model == "Boeing 737").first()
    if not airplane1:
        airplane1 = Airplane(model="Boeing 737", total_seats=12)
        db.add(airplane1)
        db.flush()
        
        # Создаём места: 3 ряда по 4 места (A, B, C, D)
        seat_numbers = []
        for row in range(1, 4):
            for letter in ["A", "B", "C", "D"]:
                seat_numbers.append(f"{row}{letter}")
        
        for seat_num in seat_numbers:
            seat = Seat(
                airplane_id=airplane1.id,
                seat_number=seat_num,
                status=SeatStatus.AVAILABLE
            )
            db.add(seat)
        print("[OK] Создан самолёт Boeing 737 с 12 местами")
    else:
        print("[INFO] Самолёт Boeing 737 уже существует")
    
    # Самолёт 2: Airbus A320 (средний, 30 мест)
    airplane2 = db.query(Airplane).filter(Airplane.model == "Airbus A320").first()
    if not airplane2:
        airplane2 = Airplane(model="Airbus A320", total_seats=30)
        db.add(airplane2)
        db.flush()
        
        # Создаём места: 10 рядов по 3 места (A, B, C)
        seat_numbers = []
        for row in range(1, 11):
            for letter in ["A", "B", "C"]:
                seat_numbers.append(f"{row}{letter}")
        
        for seat_num in seat_numbers:
            seat = Seat(
                airplane_id=airplane2.id,
                seat_number=seat_num,
                status=SeatStatus.AVAILABLE
            )
            db.add(seat)
        print("[OK] Создан самолёт Airbus A320 с 30 местами")
    else:
        print("[INFO] Самолёт Airbus A320 уже существует")
    
    db.commit()
    
    # ============================================
    # 4. СОЗДАНИЕ РЕЙСОВ
    # ============================================
    
    print("Создаём рейсы...")
    
    # Рейс 1: Москва -> Санкт-Петербург (сегодня)
    flight1 = db.query(Flight).filter(Flight.flight_number == "SU100").first()
    if not flight1:
        departure_time = datetime.now().replace(hour=10, minute=0, second=0, microsecond=0)
        arrival_time = departure_time + timedelta(hours=1, minutes=30)
        
        flight1 = Flight(
            flight_number="SU100",
            departure_airport_id=airports["SVO"].id,
            arrival_airport_id=airports["LED"].id,
            departure_time=departure_time,
            arrival_time=arrival_time,
            airplane_id=airplane1.id,
            base_price=5000.0,
            status=FlightStatus.SCHEDULED
        )
        db.add(flight1)
        print("[OK] Создан рейс SU100: Москва -> Санкт-Петербург")
    
    # Рейс 2: Санкт-Петербург -> Москва (сегодня)
    flight2 = db.query(Flight).filter(Flight.flight_number == "SU101").first()
    if not flight2:
        departure_time = datetime.now().replace(hour=14, minute=0, second=0, microsecond=0)
        arrival_time = departure_time + timedelta(hours=1, minutes=30)
        
        flight2 = Flight(
            flight_number="SU101",
            departure_airport_id=airports["LED"].id,
            arrival_airport_id=airports["SVO"].id,
            departure_time=departure_time,
            arrival_time=arrival_time,
            airplane_id=airplane1.id,
            base_price=5000.0,
            status=FlightStatus.SCHEDULED
        )
        db.add(flight2)
        print("[OK] Создан рейс SU101: Санкт-Петербург -> Москва")
    
    # Рейс 3: Москва -> Сочи (завтра)
    flight3 = db.query(Flight).filter(Flight.flight_number == "SU200").first()
    if not flight3:
        departure_time = (datetime.now() + timedelta(days=1)).replace(hour=8, minute=0, second=0, microsecond=0)
        arrival_time = departure_time + timedelta(hours=2, minutes=30)
        
        flight3 = Flight(
            flight_number="SU200",
            departure_airport_id=airports["SVO"].id,
            arrival_airport_id=airports["AER"].id,
            departure_time=departure_time,
            arrival_time=arrival_time,
            airplane_id=airplane2.id,
            base_price=8000.0,
            status=FlightStatus.SCHEDULED
        )
        db.add(flight3)
        print("[OK] Создан рейс SU200: Москва -> Сочи")
    
    # Рейс 4: Сочи -> Краснодар (послезавтра)
    flight4 = db.query(Flight).filter(Flight.flight_number == "SU300").first()
    if not flight4:
        departure_time = (datetime.now() + timedelta(days=2)).replace(hour=12, minute=0, second=0, microsecond=0)
        arrival_time = departure_time + timedelta(hours=1, minutes=0)
        
        flight4 = Flight(
            flight_number="SU300",
            departure_airport_id=airports["AER"].id,
            arrival_airport_id=airports["KRR"].id,
            departure_time=departure_time,
            arrival_time=arrival_time,
            airplane_id=airplane1.id,
            base_price=3000.0,
            status=FlightStatus.SCHEDULED
        )
        db.add(flight4)
        print("[OK] Создан рейс SU300: Сочи -> Краснодар")
    
    db.commit()
    
    print("\n[SUCCESS] Тестовые данные успешно созданы!")
    print("\n" + "="*60)
    print("УЧЁТНЫЕ ДАННЫЕ ДЛЯ ВХОДА")
    print("="*60)
    print("\nПАССАЖИРЫ (PASSENGER):")
    print("   passenger@test.com / password123")
    print("\nСОТРУДНИКИ (STAFF):")
    print("   staff@test.com / password123")
    print("   staff1@airline.com / staff123")
    print("\nВАЖНО:")
    print("   - STAFF НЕ регистрируются через /register")
    print("   - STAFF создаются ТОЛЬКО через seed.py")
    print("   - STAFF входят через обычный /login")
    print("   - После входа STAFF получают JWT токен")
    print("="*60)
    print("\nРейсы:")
    print("   SU100: Москва (SVO) -> Санкт-Петербург (LED) - сегодня")
    print("   SU101: Санкт-Петербург (LED) -> Москва (SVO) - сегодня")
    print("   SU200: Москва (SVO) -> Сочи (AER) - завтра")
    print("   SU300: Сочи (AER) -> Краснодар (KRR) - послезавтра")


if __name__ == "__main__":
    try:
        seed_data()
    except Exception as e:
        print(f"[ERROR] Ошибка при создании тестовых данных: {e}")
        db.rollback()
    finally:
        db.close()


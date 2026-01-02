"""
main.py - FastAPI application entry point

This file contains all API endpoints (routes).
Each endpoint is a function that handles HTTP requests.

FastAPI automatically creates documentation at /docs
"""

from fastapi import FastAPI, Depends, HTTPException, status, Body, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import secrets
import json
import logging

from app.core.database import Base, engine, get_db
from app.core.auth import (
    get_password_hash,
    verify_password,
    create_access_token,
    get_current_user,
    get_current_passenger,
    get_current_staff,
)
from app.core.config import (
    CORS_ORIGINS,
    CORS_ALLOW_CREDENTIALS,
    CORS_ALLOW_METHODS,
    CORS_ALLOW_HEADERS,
    APP_TITLE,
    APP_DESCRIPTION,
    APP_VERSION,
)
from app.models import (
    User,
    PassengerProfile,
    Airport,
    Airplane,
    Seat,
    Flight,
    Booking,
    Ticket,
    Payment,
    CheckIn,
    Announcement,
    Notification,
    UserRole,
    SeatStatus,
    SeatCategory,
    FlightStatus,
    PaymentMethod,
    PaymentStatus,
)
from app.schemas import (
    UserRegister,
    UserLogin,
    StaffCreate,
    Token,
    PassengerProfileCreate,
    PassengerProfileResponse,
    AirportCreate,
    AirportResponse,
    AirplaneCreate,
    AirplaneResponse,
    FlightCreate,
    FlightUpdate,
    FlightResponse,
    FlightSearch,
    FlightWithAirportsResponse,
    SeatResponse,
    SeatMapResponse,
    SeatHoldRequest,
    BookingCreate,
    BookingResponse,
    BookingWithDetailsResponse,
    TicketResponse,
    TicketWithCheckInResponse,
    PaymentCreate,
    PaymentResponse,
    CheckInResponse,
    BoardingPassResponse,
    AnnouncementCreate,
    AnnouncementResponse,
    NotificationCreate,
    NotificationResponse,
    NotificationSendResponse,
    PassengerInfoResponse,
)
from app.utils import create_flight_response

# Настройка логирования
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Кастомный JSONResponse с UTF-8 поддержкой
class UTF8JSONResponse(JSONResponse):
    def render(self, content) -> bytes:
        return json.dumps(
            content,
            ensure_ascii=False,
            allow_nan=False,
            indent=None,
            separators=(",", ":"),
        ).encode("utf-8")

# Create FastAPI application
app = FastAPI(
    title=APP_TITLE,
    description=APP_DESCRIPTION,
    version=APP_VERSION,
    default_response_class=UTF8JSONResponse,  # Используем UTF-8 JSON по умолчанию
)

# CORS - allow Flutter app to access our API
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=CORS_ALLOW_CREDENTIALS,
    allow_methods=CORS_ALLOW_METHODS,
    allow_headers=CORS_ALLOW_HEADERS,
    expose_headers=CORS_ALLOW_HEADERS,
)

# Простое логирование запросов
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Логирование всех входящих запросов"""
    logger.info(f">>> {request.method} {request.url.path}")
    response = await call_next(request)
    logger.info(f"<<< {response.status_code} {request.url.path}")
    return response


# ============================================
# DATABASE INITIALIZATION
# ============================================

# Импорт фоновых задач
from app.services.background_tasks import background_task_manager
from app.services.notification_service import NotificationService

@app.on_event("startup")
async def startup_event():
    """Create all database tables on startup and start background tasks"""
    Base.metadata.create_all(bind=engine)
    
    # Запускаем фоновые задачи (автоматическое обновление статусов)
    background_task_manager.start()
    
    print("=" * 50)
    print("SERVER STARTED - All routes registered")
    print("Background tasks: RUNNING")
    print("=" * 50)


@app.on_event("shutdown")
async def shutdown_event():
    """Stop background tasks on shutdown"""
    background_task_manager.stop()
    print("=" * 50)
    print("SERVER SHUTDOWN - Background tasks stopped")
    print("=" * 50)


# Тестовый эндпоинт для проверки работы сервера
@app.get("/health")
def health_check():
    """Проверка работоспособности сервера"""
    return {"status": "ok", "message": "Server is running"}


# ============================================
# AUTHENTICATION
# ============================================

@app.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def register(user_data: UserRegister, db: Session = Depends(get_db)):
    """Register new user"""
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    hashed_password = get_password_hash(user_data.password)
    new_user = User(
        email=user_data.email,
        hashed_password=hashed_password,
        role=user_data.role
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    access_token = create_access_token(data={"sub": new_user.email, "role": new_user.role.value})
    return {"access_token": access_token, "token_type": "bearer"}


@app.post("/login", response_model=Token)
def login(credentials: UserLogin, db: Session = Depends(get_db)):
    """Login user"""
    user = db.query(User).filter(User.email == credentials.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    if not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    access_token = create_access_token(data={"sub": user.email, "role": user.role.value})
    return {"access_token": access_token, "token_type": "bearer"}


# Continue with the rest of the endpoints...
# (I'll need to copy the rest from the original main.py)



# ============================================
# ПРОФИЛЬ ПАССАЖИРА
# ============================================

@app.post("/passenger/profile", response_model=PassengerProfileResponse, status_code=status.HTTP_201_CREATED)
def create_passenger_profile(
    profile_data: PassengerProfileCreate,
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """
    Создание или обновление профиля пассажира.
    
    Обязательно нужно заполнить перед бронированием билетов.
    """
    # Проверяем, есть ли уже профиль
    # Валидация обязательных полей (phone + nationality)
    if not profile_data.phone or not profile_data.phone.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Phone is required")
    if not profile_data.nationality or not profile_data.nationality.strip():
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Nationality is required")

    existing_profile = db.query(PassengerProfile).filter(PassengerProfile.user_id == current_user.id).first()
    
    if existing_profile:
        # Обновляем существующий профиль
        existing_profile.first_name = profile_data.first_name
        existing_profile.last_name = profile_data.last_name
        existing_profile.date_of_birth = profile_data.date_of_birth
        existing_profile.passport_number = profile_data.passport_number
        existing_profile.phone = profile_data.phone
        existing_profile.nationality = profile_data.nationality
        existing_profile.updated_at = datetime.utcnow()
        db.commit()
        db.refresh(existing_profile)
        return existing_profile
    else:
        # Создаём новый профиль
        new_profile = PassengerProfile(
            user_id=current_user.id,
            first_name=profile_data.first_name,
            last_name=profile_data.last_name,
            date_of_birth=profile_data.date_of_birth,
            passport_number=profile_data.passport_number,
            phone=profile_data.phone,
            nationality=profile_data.nationality
        )
        db.add(new_profile)
        db.commit()
        db.refresh(new_profile)
        return new_profile


@app.get("/passenger/profile", response_model=PassengerProfileResponse)
def get_passenger_profile(
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """Получение профиля пассажира"""
    profile = db.query(PassengerProfile).filter(PassengerProfile.user_id == current_user.id).first()
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile not found"
        )
    return profile


# ============================================
# АЭРОПОРТЫ (для staff)
# ============================================
# STAFF может создавать аэропорты для системы
# Это нужно для добавления новых пунктов назначения

@app.post("/airports", response_model=AirportResponse, status_code=status.HTTP_201_CREATED)
def create_airport(
    airport_data: AirportCreate,
    current_user: User = Depends(get_current_staff),  # Проверка: только STAFF может создавать
    db: Session = Depends(get_db)
):
    """
    Создание аэропорта (только для staff)
    
    STAFF создаёт новый аэропорт в системе.
    Это нужно перед созданием рейсов, которые используют этот аэропорт.
    """
    existing = db.query(Airport).filter(Airport.code == airport_data.code).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Airport with this code already exists"
        )
    
    new_airport = Airport(
        code=airport_data.code,
        name=airport_data.name,
        city=airport_data.city,
        country=airport_data.country
    )
    db.add(new_airport)
    db.commit()
    db.refresh(new_airport)
    return new_airport


@app.get("/airports", response_model=list[AirportResponse])
def get_airports(db: Session = Depends(get_db)):
    """Получение списка всех аэропортов"""
    airports = db.query(Airport).all()
    return airports


# ============================================
# САМОЛЁТЫ (для staff)
# ============================================
# STAFF управляет самолётами в системе
# Создаёт самолёты и определяет их вместимость (количество мест)

@app.post("/airplanes", response_model=AirplaneResponse, status_code=status.HTTP_201_CREATED)
async def create_airplane(
    request: Request,
    airplane_data: AirplaneCreate,
    current_user: User = Depends(get_current_staff),  # Проверка: только STAFF
    db: Session = Depends(get_db)
):
    """
    Создание самолёта с местами (только для staff).
    
    STAFF создаёт новый самолёт в системе:
    - Указывает модель (например, "Boeing 737")
    - Определяет все места в самолёте (seat map)
    - Система автоматически создаёт все места в базе данных
    
    Это нужно перед созданием рейсов, которые будут использовать этот самолёт.
    """
    # ЛОГИРОВАНИЕ: Выводим что пришло на бэкенд
    body = await request.body()
    print("=" * 50)
    print("BACKEND LOG: Received request body:")
    print(body.decode('utf-8'))
    print("BACKEND LOG: Parsed airplane_data:")
    print(f"  model: {airplane_data.model}")
    print(f"  rows: {airplane_data.rows}")
    print(f"  seats_per_row: {airplane_data.seats_per_row}")
    print(f"  seat_letters: {airplane_data.seat_letters}")
    print(f"  seats: {airplane_data.seats}")
    print("=" * 50)
    
    # airplane_data уже провалидирован FastAPI через Pydantic
    # Определяем ряды с extra legroom
    extra_legroom_rows = set(airplane_data.extra_legroom_rows or [])
    
    # Структура для хранения данных о местах: [(seat_number, category), ...]
    seats_data = []
    
    # Генерируем места автоматически, если не указан ручной список
    if airplane_data.seats and len(airplane_data.seats) > 0:
        # Ручной режим: используем указанные места с их категориями
        for seat in airplane_data.seats:
            category = SeatCategory.EXTRA_LEGROOM if seat.category == "EXTRA_LEGROOM" else SeatCategory.STANDARD
            seats_data.append((seat.seat_number, category))
        total_seats = len(seats_data)
    elif airplane_data.rows is not None and airplane_data.seats_per_row is not None:
        # Автоматический режим: генерируем места на основе rows и seats_per_row
        if airplane_data.rows <= 0 or airplane_data.seats_per_row <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Rows and seats_per_row must be greater than 0"
            )
        
        if airplane_data.seats_per_row > len(airplane_data.seat_letters):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"seats_per_row ({airplane_data.seats_per_row}) cannot exceed available seat letters ({len(airplane_data.seat_letters)})"
            )
        
        for row in range(1, airplane_data.rows + 1):
            # Определяем категорию для ряда
            category = SeatCategory.EXTRA_LEGROOM if row in extra_legroom_rows else SeatCategory.STANDARD
            for seat_idx in range(airplane_data.seats_per_row):
                seat_letter = airplane_data.seat_letters[seat_idx]
                seats_data.append((f"{row}{seat_letter}", category))
        total_seats = len(seats_data)
    else:
        # Не указаны ни seats, ни rows/seats_per_row
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either 'seats' list or 'rows' and 'seats_per_row' must be provided"
        )
    
    new_airplane = Airplane(
        model=airplane_data.model,
        total_seats=total_seats
    )
    db.add(new_airplane)
    db.flush()  # Получаем ID самолёта
    
    # Создаём все места с категориями
    for seat_number, category in seats_data:
        new_seat = Seat(
            airplane_id=new_airplane.id,
            seat_number=seat_number,
            status=SeatStatus.AVAILABLE,
            category=category
        )
        db.add(new_seat)
    
    db.commit()
    db.refresh(new_airplane)
    return new_airplane


@app.get("/airplanes", response_model=list[AirplaneResponse])
def get_airplanes(db: Session = Depends(get_db)):
    """Получение списка всех активных самолётов"""
    # Фильтруем только активные самолёты (is_active=True или NULL для старых записей)
    airplanes = db.query(Airplane).filter(
        (Airplane.is_active == True) | (Airplane.is_active == None)
    ).all()
    return airplanes


@app.get("/airplanes/{airplane_id}/seats", response_model=list[SeatResponse])
def get_airplane_seats(airplane_id: int, db: Session = Depends(get_db)):
    """Получение всех мест самолёта по его ID"""
    airplane = db.query(Airplane).filter(Airplane.id == airplane_id).first()
    if not airplane:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Airplane not found"
        )
    
    seats = db.query(Seat).filter(Seat.airplane_id == airplane_id).order_by(Seat.seat_number).all()
    
    return [SeatResponse(
        id=seat.id,
        airplane_id=seat.airplane_id,
        seat_number=seat.seat_number,
        status=seat.status,
        category=seat.category.value if getattr(seat, "category", None) is not None else "STANDARD",
        held_until=seat.held_until
    ) for seat in seats]


@app.delete("/airplanes/{airplane_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_airplane(
    airplane_id: int,
    current_user: User = Depends(get_current_staff),
    db: Session = Depends(get_db)
):
    """
    Удаление самолёта (Soft Delete).
    
    При удалении самолёта:
    1. Самолёт помечается как неактивный (is_active=False)
    2. Р’СЃРµ Р‘РЈР”РЈР©Р˜Р• Рё РђРљРўР˜Р’РќР«Р• СЂРµР№СЃС‹ СЌС‚РѕРіРѕ самолёта автоматически ОТМЕНЯЮТСЯ
    3. Пассажиры этих рейсов получают уведомления
    """
    airplane = db.query(Airplane).filter(Airplane.id == airplane_id).first()
    if not airplane:
        raise HTTPException(status_code=404, detail="Airplane not found")
        
    # 1. РџРѕРјРµС‡Р°РµРј РєР°Рє неактивный
    airplane.is_active = False
    
    # 2. Находим активные рейсы (не завершенные и не отмененные)
    active_statuses = [
        FlightStatus.SCHEDULED, FlightStatus.DELAYED, FlightStatus.BOARDING
    ]
    
    active_flights = db.query(Flight).filter(
        Flight.airplane_id == airplane_id,
        Flight.status.in_(active_statuses)
    ).all()
    
    # 3. РћС‚РјРµРЅСЏРµРј СЂРµР№СЃС‹ Рё СѓРІРµРґРѕРјР»СЏРµРј пассажиров
    for flight in active_flights:
        print(f"DEBUG: Отмена рейса {flight.flight_number} из-за удаления самолёта")
        old_status = flight.status
        flight.status = FlightStatus.CANCELLED
        
        # РћС‚РјРµРЅСЏРµРј РІСЃРµ бронирования СЌС‚РѕРіРѕ СЂРµР№СЃР°
        bookings = db.query(Booking).filter(Booking.flight_id == flight.id).all()
        for booking in bookings:
            booking.status = "CANCELLED"
            
        # Логика уведомления
        user_ids = set(booking.user_id for booking in bookings)
        
        for user_id in user_ids:
            notification = Notification(
                user_id=user_id,
                flight_id=flight.id,
                title="Рейс отменён",
                content=f"Ваш рейс {flight.flight_number} был отменён из-за вывода самолёта из эксплуатации."
            )
            db.add(notification)
            
    db.commit()
    return None


# ============================================
# РЕЙСЫ
# ============================================

@app.post("/flights", response_model=FlightResponse, status_code=status.HTTP_201_CREATED)
def create_flight(
    flight_data: FlightCreate,
    current_user: User = Depends(get_current_staff),
    db: Session = Depends(get_db)
):
    """
    Создание рейса (только для staff).
    
    STAFF создаёт новый рейс в системе:
    - Указывает номер рейса (например, "SU100")
    - Выбирает аэропорты отправления и прибытия
    - Устанавливает дату и время вылета/прилёта
    - Назначает самолёт для рейса
    - Устанавливает базовую цену билета
    
    После создания рейс получает статус SCHEDULED (запланирован).
    Рейс должен быть создан минимум за 24 часа до вылета.
    """
    # Проверка: рейс должен быть создан минимум за 24 часа до вылета
    min_departure_time = datetime.utcnow() + timedelta(hours=24)
    if flight_data.departure_time < min_departure_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Рейс можно создать минимум за 24 часа до вылета. Минимальное время вылета: {min_departure_time.strftime('%d.%m.%Y %H:%M')} UTC"
        )
    
    # Проверка: аэропорты отправления и прибытия не должны быть одинаковыми
    if flight_data.departure_airport_id == flight_data.arrival_airport_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Аэропорт отправления и аэропорт прибытия не могут быть одинаковыми"
        )
    
    # Проверка: самолёт не должен быть занят в это время
    # Ищем рейсы с этим самолётом, которые пересекаются по времени
    # Проверяем все статусы кроме CANCELLED и COMPLETED (самолет может быть занят в любом активном статусе)
    conflicting_flights = db.query(Flight).filter(
        Flight.airplane_id == flight_data.airplane_id,
        ~Flight.status.in_([FlightStatus.CANCELLED, FlightStatus.COMPLETED]),
        # Проверяем пересечение временных интервалов:
        # Интервалы пересекаются, если: departure_time < existing.arrival_time AND arrival_time > existing.departure_time
        Flight.departure_time < flight_data.arrival_time,
        Flight.arrival_time > flight_data.departure_time
    ).first()
    
    if conflicting_flights:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Этот самолёт занят в это время. Конфликт с рейсом {conflicting_flights.flight_number} ({conflicting_flights.departure_time.strftime('%d.%m.%Y %H:%M')} - {conflicting_flights.arrival_time.strftime('%H:%M')})"
        )
    
    new_flight = Flight(
        flight_number=flight_data.flight_number,
        departure_airport_id=flight_data.departure_airport_id,
        arrival_airport_id=flight_data.arrival_airport_id,
        departure_time=flight_data.departure_time,
        arrival_time=flight_data.arrival_time,
        airplane_id=flight_data.airplane_id,
        base_price=flight_data.base_price,
        gate=(flight_data.gate or "")
    )
    db.add(new_flight)
    db.commit()
    db.refresh(new_flight)
    return new_flight


@app.get("/flights/search", response_model=list[FlightWithAirportsResponse])
def search_flights(
    from_code: str = None,
    to_code: str = None,
    date: str = None,
    show_all: bool = False,  # Для сотрудника - показать все рейсы
    db: Session = Depends(get_db)
):
    """
    Поиск рейсов.
    
    Параметры:
    - from_code: код аэропорта отправления (например, "SVO")
    - to_code: код аэропорта прибытия (например, "LED")
    - date: дата в формате YYYY-MM-DD
    - show_all: если True, показать все рейсы (для сотрудника)
    """
    query = db.query(Flight)
    
    # Фильтр по статусам - для пассажиров показываем только доступные для бронирования
    # Для сотрудников (show_all=True) показываем все, кроме CANCELLED
    if show_all:
        # Сотрудник видит все рейсы кроме отменённых
        query = query.filter(Flight.status != FlightStatus.CANCELLED)
    else:
        # Пассажир видит только рейсы, на которые можно забронировать
        available_statuses = [FlightStatus.SCHEDULED, FlightStatus.DELAYED]
        query = query.filter(Flight.status.in_(available_statuses))
    
    # Фильтр по аэропорту отправления
    if from_code:
        from_airport = db.query(Airport).filter(Airport.code == from_code).first()
        if from_airport:
            query = query.filter(Flight.departure_airport_id == from_airport.id)
    
    # Фильтр по аэропорту прибытия
    if to_code:
        to_airport = db.query(Airport).filter(Airport.code == to_code).first()
        if to_airport:
            query = query.filter(Flight.arrival_airport_id == to_airport.id)
    
    # Фильтр по дате
    if date:
        try:
            search_date = datetime.strptime(date, "%Y-%m-%d").date()
            # Для SQLite используем сравнение дат через строки
            start_of_day = datetime.combine(search_date, datetime.min.time())
            end_of_day = datetime.combine(search_date, datetime.max.time())
            query = query.filter(
                Flight.departure_time >= start_of_day,
                Flight.departure_time < end_of_day + timedelta(days=1)
            )
        except ValueError:
            pass  # Игнорируем неправильный формат даты
    
    flights = query.all()
    
   
    return [create_flight_response(flight) for flight in flights]


@app.get("/flights/{flight_id}", response_model=FlightWithAirportsResponse)
def get_flight(flight_id: int, db: Session = Depends(get_db)):
    """Получение информации о рейсе"""
    flight = db.query(Flight).filter(Flight.id == flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    
    return create_flight_response(flight)


@app.patch("/flights/{flight_id}", response_model=FlightWithAirportsResponse)
def update_flight_status(
    flight_id: int,
    flight_update: FlightUpdate,
    current_user: User = Depends(get_current_staff),  # РџСЂРѕРІРµСЂРєР°: С‚РѕР»СЊРєРѕ STAFF
    db: Session = Depends(get_db)
):
    """
    Обновление статуса рейса (С‚РѕР»СЊРєРѕ для staff).
    
    STAFF может изменять статус рейса:
    - SCHEDULED - запланирован
    - DELAYED - задержан
    - BOARDING - идёт посадка
    - DEPARTED - вылетел
    - ARRIVED - прибыл
    - CANCELLED - отменён
    - COMPLETED - завершён
    
    При изменении статуса автоматически отправляются уведомления всем пассажирам рейса.
    """
    flight = db.query(Flight).filter(Flight.id == flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    
    # Проверка: нельзя изменить статус рейса, если он уже COMPLETED
    if flight.status == FlightStatus.COMPLETED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot change status of a completed flight"
        )
    
    old_status = flight.status
    
    # Обновляем статус
    flight.status = flight_update.status
    
    # Обновляем время вылета/прилёта, если передано (для DELAYED)
    time_changed = False
    new_departure_time = flight.departure_time
    new_arrival_time = flight.arrival_time
    
    if flight_update.departure_time is not None:
        new_departure_time = flight_update.departure_time
        time_changed = True
    if flight_update.arrival_time is not None:
        new_arrival_time = flight_update.arrival_time
        time_changed = True
    
    # Проверка: если время изменилось, проверяем конфликты с другими рейсами того же самолета
    if time_changed:
        # Ищем рейсы с этим самолётом, которые пересекаются по времени
        # Исключаем текущий рейс и рейсы со статусами CANCELLED и COMPLETED
        conflicting_flights = db.query(Flight).filter(
            Flight.airplane_id == flight.airplane_id,
            Flight.id != flight_id,  # Исключаем текущий рейс
            ~Flight.status.in_([FlightStatus.CANCELLED, FlightStatus.COMPLETED]),
            # Проверяем пересечение временных интервалов
            Flight.departure_time < new_arrival_time,
            Flight.arrival_time > new_departure_time
        ).first()
        
        if conflicting_flights:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Этот самолёт занят в это время. Конфликт с рейсом {conflicting_flights.flight_number} ({conflicting_flights.departure_time.strftime('%d.%m.%Y %H:%M')} - {conflicting_flights.arrival_time.strftime('%H:%M')})"
            )
        
        # Применяем изменения времени только после проверки
        if flight_update.departure_time is not None:
            flight.departure_time = new_departure_time
        if flight_update.arrival_time is not None:
            flight.arrival_time = new_arrival_time
    
    # Обработка изменения gate
    gate_changed = False
    old_gate = flight.gate
    if flight_update.gate is not None and flight_update.gate != flight.gate:
        flight.gate = flight_update.gate
        gate_changed = True
    
    db.commit()
    
    # Отправляем уведомления всем пассажирам рейса при изменении статуса, времени или gate
    status_changed = old_status != flight_update.status
    if status_changed or time_changed:
        # Используем NotificationService для отправки уведомлений
        NotificationService.notify_flight_passengers(
            db=db,
            flight=flight,
            new_status=flight_update.status,
            custom_message=None # Будет использован стандартный шаблон из сервиса
        )
        
        # Если рейс отменён, отменяем все бронирования
        if flight_update.status == FlightStatus.CANCELLED:
            bookings = db.query(Booking).filter(Booking.flight_id == flight_id).all()
            for booking in bookings:
                booking.status = "CANCELLED"
        
        db.commit()
    
    # Отправляем уведомление при изменении gate (отдельно от статуса)
    if gate_changed and not status_changed:
        # Получаем всех пассажиров рейса
        bookings = db.query(Booking).filter(
            Booking.flight_id == flight_id,
            Booking.status != "CANCELLED"
        ).all()
        
        for booking in bookings:
            NotificationService.create_notification(
                db=db,
                user_id=booking.user_id,
                title="Изменение выхода на посадку",
                message=f"Для рейса {flight.flight_number} изменён выход на посадку: {old_gate or 'Н/Д'} → {flight.gate}",
                flight_id=flight.id
            )
        
        db.commit()
    
    db.refresh(flight)
    
    # Возвращаем полную информацию с аэропортами
    return create_flight_response(flight)


# ============================================
# SEAT MAP
# ============================================

@app.get("/flights/{flight_id}/seat-map", response_model=SeatMapResponse)
def get_seat_map(flight_id: int, db: Session = Depends(get_db)):
    """
    Получение карты мест для рейса.
    
    Показывает все места в самолёте и их статусы.
    """
    flight = db.query(Flight).filter(Flight.id == flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    
    # Получаем все места самолёта
    seats = db.query(Seat).filter(Seat.airplane_id == flight.airplane_id).all()
    
    # Проверяем истечение удержаний
    now = datetime.utcnow()
    for seat in seats:
        if seat.status == SeatStatus.HELD and seat.held_until and seat.held_until < now:
            seat.status = SeatStatus.AVAILABLE
            seat.held_until = None
    
    db.commit()
    
    return SeatMapResponse(
        flight_id=flight_id,
        seats=[SeatResponse(
            id=seat.id,
            airplane_id=seat.airplane_id,
            seat_number=seat.seat_number,
            status=seat.status,
            category=seat.category.value if getattr(seat, "category", None) is not None else "STANDARD",
            held_until=seat.held_until
        ) for seat in seats]
    )


@app.post("/seats/{seat_id}/hold")
def hold_seat(
    seat_id: int,
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """
    Удержание места на 10 минут.
    
    Когда пользователь выбирает место, оно временно удерживается.
    Если за 10 минут не произойдёт оплата, место освобождается.
    """
    seat = db.query(Seat).filter(Seat.id == seat_id).first()
    if not seat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Seat not found"
        )
    
    # Проверяем, не истекло ли предыдущее удержание
    now = datetime.utcnow()
    if seat.status == SeatStatus.HELD and seat.held_until and seat.held_until < now:
        seat.status = SeatStatus.AVAILABLE
        seat.held_until = None
    
    # Проверяем, свободно ли место
    if seat.status != SeatStatus.AVAILABLE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Seat is not available"
        )
    
    # Удерживаем место на 10 минут
    seat.status = SeatStatus.HELD
    seat.held_until = now + timedelta(minutes=10)
    db.commit()
    
    return {"message": "Seat held for 10 minutes", "held_until": seat.held_until}


# ============================================
# БРОНИРОВАНИЯ
# ============================================

@app.post("/bookings", response_model=BookingResponse, status_code=status.HTTP_201_CREATED)
def create_booking(
    booking_data: BookingCreate,
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """
    Создание бронирования.
    
    Проверяет, что у пользователя есть профиль,
    что места свободны, и создаёт бронирование со статусом CREATED.
    """
    print("=" * 50)
    print("POST /bookings - CREATE BOOKING REQUEST")
    print(f"User ID: {current_user.id}, Email: {current_user.email}")
    print(f"Flight ID: {booking_data.flight_id}")
    print(f"Seat IDs: {booking_data.seat_ids}")
    print("=" * 50)
    # Проверяем наличие профиля
    profile = db.query(PassengerProfile).filter(PassengerProfile.user_id == current_user.id).first()
    if not profile:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Passenger profile required. Please complete your profile first."
        )
    
    # Проверяем рейс
    flight = db.query(Flight).filter(Flight.id == booking_data.flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    
    # Проверяем и освобождаем истёкшие удержания
    now = datetime.utcnow()
    held_seats = db.query(Seat).filter(
        Seat.id.in_(booking_data.seat_ids),
        Seat.status == SeatStatus.HELD
    ).all()
    for seat in held_seats:
        if seat.held_until and seat.held_until < now:
            seat.status = SeatStatus.AVAILABLE
            seat.held_until = None
    
    # Проверяем, что все места свободны
    seats = db.query(Seat).filter(Seat.id.in_(booking_data.seat_ids)).all()
    for seat in seats:
        if seat.status != SeatStatus.AVAILABLE and seat.status != SeatStatus.HELD:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Seat {seat.seat_number} is not available"
            )
    
    # Генерируем уникальный PNR для бронирования
    # Формат: 6 символов A-Z0-9 (как типичный PNR)
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    pnr = None
    for _ in range(20):
        candidate = "".join(secrets.choice(alphabet) for _ in range(6))
        exists = db.query(Booking).filter(Booking.pnr == candidate).first()
        if not exists:
            pnr = candidate
            break
    if pnr is None:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to generate PNR")

    # Создаём бронирование со статусом CREATED
    new_booking = Booking(
        user_id=current_user.id,
        flight_id=booking_data.flight_id,
        status="CREATED",
        created_at=datetime.utcnow(),
        pnr=pnr
    )
    db.add(new_booking)
    db.flush()
    
    # Создаём билеты для каждого места
    for seat in seats:
        # Генерируем уникальный номер билета
        ticket_number = f"TK{secrets.token_hex(4).upper()}"
        
        new_ticket = Ticket(
            booking_id=new_booking.id,
            seat_id=seat.id,
            passenger_first_name=profile.first_name,
            passenger_last_name=profile.last_name,
            ticket_number=ticket_number
        )
        db.add(new_ticket)
        
        # Помечаем место как удержанное (HELD) до оплаты
        seat.status = SeatStatus.HELD
        seat.held_until = datetime.utcnow() + timedelta(minutes=10)
    
    db.commit()
    db.refresh(new_booking)
    print(f"Booking created: ID={new_booking.id}, Status={new_booking.status}, Created_at={new_booking.created_at}")
    
    # Отправляем уведомление пассажиру о создании бронирования
    seat_numbers = ", ".join([seat.seat_number for seat in seats])
    NotificationService.create_notification(
        db=db,
        user_id=current_user.id,
        title="Бронирование создано",
        message=f"Вы забронировали место(а) {seat_numbers} на рейс {flight.flight_number}. Оплатите в течение 10 минут, иначе бронь будет отменена.",
        flight_id=flight.id
    )
    db.commit()
    
    print(f"==============================")
    return new_booking


@app.get("/bookings/my", response_model=list[BookingWithDetailsResponse])
def get_my_bookings(
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """
    Получение всех бронирований текущего пользователя.
    
    Возвращает ВСЕ бронирования пользователя, где статус НЕ равен CANCELLED.
    Автоматически отменяет истёкшие бронирования (CREATED > 10 минут).
    Всегда возвращает 200 OK, даже если список пуст.
    """
    print("=" * 50)
    print("GET /bookings/my - GET MY BOOKINGS REQUEST")
    print(f"User ID: {current_user.id}, Email: {current_user.email}")
    print("=" * 50)
    
    # Автоматически отменяем истёкшие бронирования пользователя
    expired_bookings = db.query(Booking).filter(
        Booking.user_id == current_user.id,
        Booking.status == "CREATED"
    ).all()
    
    for booking in expired_bookings:
        if booking.is_expired():
            print(f"Cancelling expired booking ID={booking.id}")
            booking.status = "CANCELLED"
            for ticket in booking.tickets:
                if ticket.seat:
                    ticket.seat.status = SeatStatus.AVAILABLE
                    ticket.seat.held_until = None
    
    db.commit()
    
    try:
        bookings = db.query(Booking).filter(
            Booking.user_id == current_user.id,
            Booking.status != "CANCELLED"
        ).all()
        
        print(f"Found {len(bookings)} bookings in database")
        
        result = []
        for booking in bookings:
            # Получаем рейс с аэропортами
            flight = booking.flight
            
            # Пропускаем бронирования, у которых рейс удалён
            if flight is None:
                print(f"Skipping booking ID={booking.id} - flight is deleted")
                continue
            
            flight_response = create_flight_response(flight)
            
            # Получаем билеты
            tickets_response = []
            for ticket in booking.tickets:
                # Формируем полное имя пассажира
                full_name = f"{ticket.passenger_first_name} {ticket.passenger_last_name}"
                tickets_response.append(TicketResponse(
                    id=ticket.id,
                    booking_id=ticket.booking_id,
                    seat=SeatResponse(
                        id=ticket.seat.id,
                        airplane_id=ticket.seat.airplane_id,
                        seat_number=ticket.seat.seat_number,
                        status=ticket.seat.status,
                        held_until=ticket.seat.held_until
                    ),
                    passenger_first_name=ticket.passenger_first_name,
                    passenger_last_name=ticket.passenger_last_name,
                    ticket_number=ticket.ticket_number,
                    full_name=full_name,
                    check_in=CheckInResponse(
                        id=ticket.check_in.id,
                        ticket_id=ticket.check_in.ticket_id,
                        boarding_pass_number=ticket.check_in.boarding_pass_number,
                        checked_in_at=ticket.check_in.checked_in_at
                    ) if ticket.check_in else None
                ))
            
            # Получаем платежи
            payments_response = []
            for payment in booking.payments:
                payments_response.append(PaymentResponse(
                    id=payment.id,
                    booking_id=payment.booking_id,
                    amount=payment.amount,
                    method=payment.method,
                    status=payment.status,
                    created_at=payment.created_at
                ))
            
            result.append(BookingWithDetailsResponse(
                id=booking.id,
                flight=flight_response,
                status=booking.status,
                pnr=booking.pnr or "",
                tickets=tickets_response,
                payments=payments_response,
                created_at=booking.created_at
            ))
        
        # Всегда возвращаем 200 OK, даже если список пуст
        print(f"Returning {len(result)} bookings (status 200 OK)")
        print("=" * 50)
        # Возвращаем список напрямую - FastAPI автоматически сериализует через UTF8JSONResponse
        return result
    except Exception as e:
        print(f"ERROR in get_my_bookings: {e}")
        import traceback
        traceback.print_exc()
        print("=" * 50)
        # Всегда возвращаем пустой список при ошибке со статусом 200, а не 404
        return []


@app.get("/bookings/all", response_model=list[BookingWithDetailsResponse])
def get_all_bookings(
    current_user: User = Depends(get_current_staff),
    db: Session = Depends(get_db)
):
    """
    Получение всех бронирований (только для staff).
    
    STAFF может просматривать ВСЕ бронирования в системе.
    Это нужно для:
    - Контроля загрузки рейсов
    - Просмотра информации о пассажирах
    - Аналитики и отчётности
    
    ВАЖНО: STAFF НЕ может изменять или отменять чужие бронирования.
    """
    bookings = db.query(Booking).filter(Booking.status != "CANCELLED").all()
    
    result = []
    for booking in bookings:
        flight = booking.flight
        
        # Пропускаем бронирования, у которых рейс удалён
        if flight is None:
            continue
        
        flight_response = create_flight_response(flight)
        
        # Получаем билеты
        tickets_response = []
        for ticket in booking.tickets:
            full_name = f"{ticket.passenger_first_name} {ticket.passenger_last_name}"
            tickets_response.append(TicketResponse(
                id=ticket.id,
                booking_id=ticket.booking_id,
                seat=SeatResponse(
                    id=ticket.seat.id,
                    airplane_id=ticket.seat.airplane_id,
                    seat_number=ticket.seat.seat_number,
                    status=ticket.seat.status,
                    held_until=ticket.seat.held_until
                ),
                passenger_first_name=ticket.passenger_first_name,
                passenger_last_name=ticket.passenger_last_name,
                ticket_number=ticket.ticket_number,
                    full_name=full_name,
                    check_in=CheckInResponse(
                        id=ticket.check_in.id,
                        ticket_id=ticket.check_in.ticket_id,
                        boarding_pass_number=ticket.check_in.boarding_pass_number,
                        checked_in_at=ticket.check_in.checked_in_at
                    ) if ticket.check_in else None
            ))
        
        # Получаем платежи
        payments_response = []
        for payment in booking.payments:
            payments_response.append(PaymentResponse(
                id=payment.id,
                booking_id=payment.booking_id,
                amount=payment.amount,
                method=payment.method,
                status=payment.status,
                created_at=payment.created_at
            ))
        
        result.append(BookingWithDetailsResponse(
            id=booking.id,
            flight=flight_response,
            status=booking.status,
            pnr=booking.pnr or "",
            tickets=tickets_response,
            payments=payments_response,
            created_at=booking.created_at
        ))
    
    return result


@app.get("/flights/{flight_id}/bookings", response_model=list[BookingResponse])
def get_flight_bookings(
    flight_id: int,
    current_user: User = Depends(get_current_staff),  # РџСЂРѕРІРµСЂРєР°: С‚РѕР»СЊРєРѕ STAFF
    db: Session = Depends(get_db)
):
    """
    Получение всех бронирований по конкретному рейсу (С‚РѕР»СЊРєРѕ для staff).
    
    STAFF может просматривать все бронирования для конкретного рейса.
    Это полезно для:
    - Проверки загрузки рейса
    - Просмотра списка пассажиров на рейс
    - Подготовки списка для регистрации
    
    ВАЖНО: STAFF НЕ может изменять бронирования через этот эндпоинт.
    """
    # Проверяем, что рейс существует
    flight = db.query(Flight).filter(Flight.id == flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    
    # РџРѕР»СѓС‡Р°РµРј РІСЃРµ бронирования РґР»СЏ СЌС‚РѕРіРѕ СЂРµР№СЃР°
    bookings = db.query(Booking).filter(Booking.flight_id == flight_id).all()
    return bookings


# ============================================
# РџР›РђРўР•Р–Р
# ============================================

@app.post("/payments", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
def create_payment(
    payment_data: PaymentCreate,
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """
    Создание и обработка платежа (мок).
    
    Проверяет бронирование, создаёт платёж,
    симулирует успешную оплату и подтверждает бронирование.
    """
    # Проверяем бронирование
    booking = db.query(Booking).filter(Booking.id == payment_data.booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    # Проверяем, что бронирование принадлежит пользователю
    if booking.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not your booking"
        )
    
    # Проверяем, не истекло ли время для оплаты
    if booking.status == "CREATED" and booking.is_expired():
        # Отменяем просроченное бронирование
        booking.status = "CANCELLED"
        for ticket in booking.tickets:
            if ticket.seat:
                ticket.seat.status = SeatStatus.AVAILABLE
                ticket.seat.held_until = None
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Booking has expired. Please book again."
        )
    
    # Проверяем, что бронирование еще не оплачено
    if booking.status == "CONFIRMED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Booking is already paid"
        )
    
    # Проверяем, что бронирование в статусе CREATED
    if booking.status != "CREATED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Booking is not in CREATED status"
        )
    
    # Вычисляем сумму (цена рейса * количество билетов)
    amount = booking.flight.base_price * len(booking.tickets)
    
    # Создаём платёж
    new_payment = Payment(
        booking_id=payment_data.booking_id,
        amount=amount,
        method=payment_data.method,
        status=PaymentStatus.PENDING
    )
    db.add(new_payment)
    db.flush()
    
    # МОК ОПЛАТЫ: всегда успешно
    # В реальном проекте здесь был бы вызов платёжного шлюза
    new_payment.status = PaymentStatus.PAID
    booking.status = "CONFIRMED"  # Меняем статус с CREATED на CONFIRMED
    
    # Помечаем места как забронированные (BOOKED) после оплаты
    for ticket in booking.tickets:
        if ticket.seat:
            ticket.seat.status = SeatStatus.BOOKED
            ticket.seat.held_until = None
    
    db.commit()
    db.refresh(new_payment)
    
    # Отправляем уведомление пассажиру об успешной оплате
    seat_numbers = ", ".join([t.seat.seat_number for t in booking.tickets if t.seat])
    NotificationService.create_notification(
        db=db,
        user_id=current_user.id,
        title="Оплата прошла успешно",
        message=f"Ваш билет на рейс {booking.flight.flight_number} (место(а): {seat_numbers}) успешно оплачен. Приятного полёта!",
        flight_id=booking.flight_id
    )
    db.commit()
    return new_payment


# ============================================
# ПОДТВЕРЖДЕНИЕ БРОНИРОВАНИЯ
# ============================================

@app.post("/bookings/{booking_id}/confirm", status_code=status.HTTP_200_OK)
def confirm_booking(
    booking_id: int,
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """
    Подтверждение бронирования.
    
    Проверяет, что все данные пассажиров заполнены и бронирование можно подтвердить.
    """
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    # Проверяем, что бронирование принадлежит пользователю
    if booking.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not your booking"
        )
    
    # Проверяем, что бронирование в статусе CREATED
    if booking.status not in ["CREATED", "PENDING"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Booking cannot be confirmed in status {booking.status}"
        )
    
    # Проверяем, что есть билеты
    if not booking.tickets or len(booking.tickets) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Booking has no tickets"
        )
    
    # Помечаем бронирование как ожидающее оплату
    booking.status = "PENDING_PAYMENT"
    
    db.commit()
    
    return {"message": "Бронирование подтверждено, ожидает оплаты", "status": booking.status}


# ============================================
# ОТМЕНА БРОНИРОВАНИЙ
# ============================================

@app.post("/bookings/{booking_id}/cancel", status_code=status.HTTP_200_OK)
def cancel_booking(
    booking_id: int,
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """
    Отмена всего бронирования.
    
    - Нельзя отменить бронирование за час до рейса
    - Освобождает все места
    - Удаляет все check-ins
    """
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    # Проверяем, что бронирование принадлежит пользователю
    if booking.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not your booking"
        )
    
    # Проверяем, что бронирование можно отменить (не за час до рейса)
    flight = booking.flight
    time_until_departure = flight.departure_time - datetime.utcnow()
    if time_until_departure < timedelta(hours=1):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Нельзя отменить бронирование за час до вылета"
        )
    
    # Освобождаем все места и удаляем check-ins
    for ticket in booking.tickets:
        if ticket.seat:
            ticket.seat.status = SeatStatus.AVAILABLE
            ticket.seat.held_until = None
        # Удаляем check-in если есть
        checkin = db.query(CheckIn).filter(CheckIn.ticket_id == ticket.id).first()
        if checkin:
            db.delete(checkin)
    
    # Отменяем бронирование
    booking.status = "CANCELLED"
    
    db.commit()
    
    return {"message": "Бронирование успешно отменено"}


# ============================================
# STAFF BOOKING MANAGEMENT
# ============================================

@app.get("/staff/bookings/search", response_model=BookingWithDetailsResponse)
def search_booking_by_pnr(
    pnr: str,
    current_user: User = Depends(get_current_staff),
    db: Session = Depends(get_db)
):
    """
    Поиск бронирования по PNR (только для staff).
    
    Позволяет сотруднику быстро найти бронирование по коду PNR.
    """
    booking = db.query(Booking).filter(Booking.pnr == pnr.upper()).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Бронирование с таким PNR не найдено"
        )
    
    flight = booking.flight
    if flight is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Рейс для данного бронирования не найден"
        )
    
    flight_response = create_flight_response(flight)
    
    # Собираем информацию о билетах
    tickets_response = []
    for ticket in booking.tickets:
        full_name = f"{ticket.passenger_first_name} {ticket.passenger_last_name}"
        tickets_response.append(TicketResponse(
            id=ticket.id,
            booking_id=ticket.booking_id,
            seat=SeatResponse(
                id=ticket.seat.id,
                airplane_id=ticket.seat.airplane_id,
                seat_number=ticket.seat.seat_number,
                status=ticket.seat.status,
                held_until=ticket.seat.held_until
            ),
            passenger_first_name=ticket.passenger_first_name,
            passenger_last_name=ticket.passenger_last_name,
            ticket_number=ticket.ticket_number,
            full_name=full_name,
            check_in=CheckInResponse(
                id=ticket.check_in.id,
                ticket_id=ticket.check_in.ticket_id,
                boarding_pass_number=ticket.check_in.boarding_pass_number,
                checked_in_at=ticket.check_in.checked_in_at
            ) if ticket.check_in else None
        ))
    
    # Собираем информацию о платежах
    payments_response = []
    for payment in booking.payments:
        payments_response.append(PaymentResponse(
            id=payment.id,
            booking_id=payment.booking_id,
            amount=payment.amount,
            method=payment.method,
            status=payment.status,
            created_at=payment.created_at
        ))
    
    return BookingWithDetailsResponse(
        id=booking.id,
        flight=flight_response,
        status=booking.status,
        pnr=booking.pnr or "",
        tickets=tickets_response,
        payments=payments_response,
        created_at=booking.created_at
    )


@app.post("/staff/bookings/{booking_id}/cancel", status_code=status.HTTP_200_OK)
def staff_cancel_booking(
    booking_id: int,
    current_user: User = Depends(get_current_staff),
    db: Session = Depends(get_db)
):
    """
    Отмена бронирования сотрудником (только для staff).
    
    - Сотрудник может отменить любое бронирование
    - Нельзя отменить бронирование после вылета рейса
    - Освобождает все места
    - Удаляет все check-ins
    """
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Бронирование не найдено"
        )
    
    # Проверяем, что бронирование ещё не отменено
    if booking.status == "CANCELLED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Бронирование уже отменено"
        )
    
    # Проверяем, что рейс ещё не вылетел
    flight = booking.flight
    if flight is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Рейс не найден"
        )
    
    # Проверка: нельзя отменить после вылета
    if datetime.utcnow() > flight.departure_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Нельзя отменить бронирование после вылета рейса"
        )
    
    # Освобождаем все места и удаляем check-ins
    for ticket in booking.tickets:
        if ticket.seat:
            ticket.seat.status = SeatStatus.AVAILABLE
            ticket.seat.held_until = None
        # Удаляем check-in если есть
        checkin = db.query(CheckIn).filter(CheckIn.ticket_id == ticket.id).first()
        if checkin:
            db.delete(checkin)
    
    # Отменяем бронирование
    booking.status = "CANCELLED"
    
    db.commit()
    
    # Отправляем уведомление пассажиру
    NotificationService.create_notification(
        db=db,
        user_id=booking.user_id,
        title="Бронирование отменено",
        message=f"Ваше бронирование {booking.pnr} на рейс {flight.flight_number} было отменено сотрудником авиакомпании.",
        flight_id=flight.id
    )
    db.commit()
    
    return {"message": "Бронирование успешно отменено"}


@app.put("/staff/bookings/{booking_id}/reassign-seat", status_code=status.HTTP_200_OK)
def staff_reassign_seat(
    booking_id: int,
    ticket_id: int = Body(..., embed=False),
    new_seat_id: int = Body(..., embed=False),
    current_user: User = Depends(get_current_staff),
    db: Session = Depends(get_db)
):
    """
    Переназначение места для билета (только для staff).
    
    - Сотрудник может переназначить место на любое другое
    - Нельзя назначить место, занятое другим пассажиром
    - Освобождает старое место
    - Нельзя изменять места после вылета
    """
    # Находим бронирование
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Бронирование не найдено"
        )
    
    # Проверяем, что бронирование не отменено
    if booking.status == "CANCELLED":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Нельзя изменить отменённое бронирование"
        )
    
    # Проверяем, что рейс ещё не вылетел
    flight = booking.flight
    if flight is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Рейс не найден"
        )
    
    if datetime.utcnow() > flight.departure_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Нельзя изменить место после вылета рейса"
        )
    
    # Находим билет
    ticket = db.query(Ticket).filter(
        Ticket.id == ticket_id,
        Ticket.booking_id == booking_id
    ).first()
    if not ticket:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Билет не найден в данном бронировании"
        )
    
    # Находим новое место
    new_seat = db.query(Seat).filter(Seat.id == new_seat_id).first()
    if not new_seat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Место не найдено"
        )
    
    # Проверяем, что место относится к тому же самолёту
    if new_seat.airplane_id != flight.airplane_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Место не принадлежит самолёту данного рейса"
        )
    
    # Проверяем, что новое место не занято другим пассажиром (BOOKED)
    # Staff может переназначить на AVAILABLE или HELD места
    if new_seat.status == SeatStatus.BOOKED:
        # Проверяем, нет ли уже билета на это место для этого рейса
        existing_ticket = db.query(Ticket).join(Booking).filter(
            Ticket.seat_id == new_seat_id,
            Booking.flight_id == flight.id,
            Booking.status != "CANCELLED"
        ).first()
        if existing_ticket and existing_ticket.id != ticket_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Место {new_seat.seat_number} уже занято другим пассажиром"
            )
    
    # Освобождаем старое место
    old_seat = ticket.seat
    old_seat_number = old_seat.seat_number
    old_seat.status = SeatStatus.AVAILABLE
    old_seat.held_until = None
    
    # Назначаем новое место
    ticket.seat_id = new_seat_id
    new_seat.status = SeatStatus.BOOKED
    new_seat.held_until = None
    
    db.commit()
    
    # Отправляем уведомление пассажиру
    NotificationService.create_notification(
        db=db,
        user_id=booking.user_id,
        title="Место изменено",
        message=f"Ваше место на рейсе {flight.flight_number} было изменено с {old_seat_number} на {new_seat.seat_number}.",
        flight_id=flight.id
    )
    db.commit()
    
    return {
        "message": f"Место успешно изменено с {old_seat_number} на {new_seat.seat_number}",
        "old_seat": old_seat_number,
        "new_seat": new_seat.seat_number
    }


# ============================================
# ОТМЕНА БИЛЕТОВ
# ============================================

@app.delete("/tickets/{ticket_id}", status_code=status.HTTP_200_OK)
def cancel_ticket(
    ticket_id: int,
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """
    Отмена отдельного билета.
    
    - Нельзя отменить билет за час до рейса
    - Освобождает место
    - Если это последний билет в бронировании, отменяет всё бронирование
    """
    ticket = db.query(Ticket).filter(Ticket.id == ticket_id).first()
    if not ticket:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ticket not found"
        )
    
    booking = ticket.booking
    if not booking:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Booking not found"
        )
    
    # Проверяем, что бронирование принадлежит пользователю
    if booking.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not your ticket"
        )
    
    # Проверяем, что билет можно отменить (не за час до рейса)
    flight = booking.flight
    time_until_departure = flight.departure_time - datetime.utcnow()
    if time_until_departure < timedelta(hours=1):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Нельзя отменить билет за час до вылета"
        )
    
    # Освобождаем место
    if ticket.seat:
        ticket.seat.status = SeatStatus.AVAILABLE
        ticket.seat.held_until = None
    
    # Удаляем check-in если есть
    checkin = db.query(CheckIn).filter(CheckIn.ticket_id == ticket_id).first()
    if checkin:
        db.delete(checkin)
    
    # Удаляем билет
    db.delete(ticket)
    
    # Если это последний билет, отменяем бронирование
    remaining_tickets = db.query(Ticket).filter(
        Ticket.booking_id == booking.id,
        Ticket.id != ticket_id
    ).count()
    
    if remaining_tickets == 0:
        booking.status = "CANCELLED"
    
    db.commit()
    
    return {"message": "Билет успешно отменён", "booking_cancelled": remaining_tickets == 0}


# ============================================
# CHECK-IN
# ============================================

@app.post("/tickets/{ticket_id}/check-in", response_model=CheckInResponse, status_code=status.HTTP_201_CREATED)
def check_in(
    ticket_id: int,
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """
    Регистрация на рейс (check-in).
    
    Создаёт посадочный талон для билета.
    """
    ticket = db.query(Ticket).filter(Ticket.id == ticket_id).first()
    if not ticket:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ticket not found"
        )
    
    # Проверяем, что билет принадлежит пользователю
    if ticket.booking.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not your ticket"
        )
    
    # Check-in доступен только для оплаченных бронирований
    if ticket.booking.status not in ["CONFIRMED", "PAID"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Check-in is available only for paid bookings"
        )

    # Check-in доступен только в окне 24ч..1ч до вылета
    flight = ticket.booking.flight
    if not flight:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Flight not found")

    now = datetime.now()
    time_until_departure = flight.departure_time - now
    if time_until_departure > timedelta(hours=24) or time_until_departure < timedelta(hours=1):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Check-in is available from 24 hours to 1 hour before departure"
        )

    # РџСЂРѕРІРµСЂСЏРµРј, РЅРµ Р·Р°СЂРµРіРёСЃС‚СЂРёСЂРѕРІР°РЅ Р»Рё СѓР¶Рµ
    existing_checkin = db.query(CheckIn).filter(CheckIn.ticket_id == ticket_id).first()
    if existing_checkin:
        return existing_checkin
    
    # Р“РµРЅРµСЂРёСЂСѓРµРј РЅРѕРјРµСЂ РїРѕСЃР°РґРѕС‡РЅРѕРіРѕ С‚Р°Р»РѕРЅР°
    boarding_pass_number = f"BP{secrets.token_hex(6).upper()}"
    
    new_checkin = CheckIn(
        ticket_id=ticket_id,
        boarding_pass_number=boarding_pass_number
    )
    db.add(new_checkin)
    db.commit()
    db.refresh(new_checkin)
    return new_checkin


@app.get("/tickets/{ticket_id}/boarding-pass", response_model=BoardingPassResponse)
def get_boarding_pass(
    ticket_id: int,
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """Получение посадочного талона"""
    ticket = db.query(Ticket).filter(Ticket.id == ticket_id).first()
    if not ticket:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ticket not found"
        )
    
    if ticket.booking.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not your ticket"
        )

    # Талон доступен только для оплаченных бронирований
    if ticket.booking.status not in ["CONFIRMED", "PAID"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Boarding pass is available only for paid bookings"
        )
    
    checkin = db.query(CheckIn).filter(CheckIn.ticket_id == ticket_id).first()
    if not checkin:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ticket not checked in"
        )
    
    flight = ticket.booking.flight
    if not flight:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Flight not found")

    boarding_time = flight.departure_time - timedelta(minutes=30)
    gate = getattr(flight, "gate", "") or ""
    qr_payload = f"BP:{checkin.boarding_pass_number}|FN:{flight.flight_number}|SEAT:{ticket.seat.seat_number}|GATE:{gate}|BT:{boarding_time.isoformat()}"
    
    return BoardingPassResponse(
        ticket=TicketWithCheckInResponse(
            id=ticket.id,
            booking_id=ticket.booking_id,
            seat=SeatResponse(
                id=ticket.seat.id,
                airplane_id=ticket.seat.airplane_id,
                seat_number=ticket.seat.seat_number,
                status=ticket.seat.status,
                held_until=ticket.seat.held_until
            ),
            passenger_first_name=ticket.passenger_first_name,
            passenger_last_name=ticket.passenger_last_name,
            ticket_number=ticket.ticket_number,
            check_in=CheckInResponse(
                id=checkin.id,
                ticket_id=checkin.ticket_id,
                boarding_pass_number=checkin.boarding_pass_number,
                checked_in_at=checkin.checked_in_at
            )
        ),
        flight=create_flight_response(flight),
        boarding_pass_number=checkin.boarding_pass_number,
        passenger_name=f"{ticket.passenger_first_name} {ticket.passenger_last_name}",
        seat_number=ticket.seat.seat_number,
        gate=gate,
        boarding_time=boarding_time,
        qr_payload=qr_payload,
        departure_time=flight.departure_time,
        arrival_time=flight.arrival_time
    )


# ============================================
# РћР‘РЄРЇР’Р›Р•РќРРЇ
# ============================================

@app.post("/announcements", response_model=AnnouncementResponse, status_code=status.HTTP_201_CREATED)
def create_announcement(
    announcement_data: AnnouncementCreate,
    current_user: User = Depends(get_current_staff),  # Проверка: только STAFF
    db: Session = Depends(get_db)
):
    """
    Создание объявления (только для staff).
    
    STAFF создаёт объявление для пассажиров конкретного рейса.
    Объявление автоматически отправляется как уведомление всем пассажирам указанного рейса.
    
    Объявление обязательно привязано к рейсу (flight_id).
    """
    # Проверяем, что рейс существует
    flight = db.query(Flight).filter(Flight.id == announcement_data.flight_id).first()
    if not flight:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Flight not found"
        )
    
    # Создаём объявление
    new_announcement = Announcement(
        title=announcement_data.title,
        content=announcement_data.content,
        flight_id=announcement_data.flight_id,
        created_by_user_id=current_user.id
    )
    db.add(new_announcement)
    db.flush()
    
    # Отправляем уведомления всем пассажирам рейса
    bookings = db.query(Booking).filter(Booking.flight_id == announcement_data.flight_id).all()
    user_ids = set(booking.user_id for booking in bookings)
    
    for user_id in user_ids:
        notification = Notification(
            user_id=user_id,
            flight_id=announcement_data.flight_id,
            title=announcement_data.title,
            content=announcement_data.content
        )
        db.add(notification)
    
    db.commit()
    db.refresh(new_announcement)
    return new_announcement


@app.get("/announcements", response_model=list[AnnouncementResponse])
def get_announcements(db: Session = Depends(get_db)):
    """Получение всех объявлений"""
    announcements = db.query(Announcement).order_by(Announcement.created_at.desc()).all()
    return announcements


# ============================================
# УВЕДОМЛЕНИЯ
# ============================================

@app.get("/notifications", response_model=list[NotificationResponse])
def get_my_notifications(
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """Получение всех уведомлений текущего пользователя (пассажира)"""
    notifications = db.query(Notification).filter(
        Notification.user_id == current_user.id
    ).order_by(Notification.created_at.desc()).all()
    return notifications


@app.post("/notifications", response_model=NotificationSendResponse, status_code=status.HTTP_201_CREATED)
def send_notification(
    payload: NotificationCreate,
    current_user: User = Depends(get_current_staff),  # только STAFF
    db: Session = Depends(get_db),
):
    """
    Отправка уведомления пассажирам (только для STAFF).

    - Если указан flight_id: отправляет всем пассажирам выбранного рейса
    - Если указан user_id: отправляет только этому пользователю
    """
    if payload.flight_id is None and payload.user_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="flight_id или user_id обязателен",
        )

    sent = 0

    # Отправка всем пассажирам рейса
    if payload.flight_id is not None:
        flight = db.query(Flight).filter(Flight.id == payload.flight_id).first()
        if not flight:
            raise HTTPException(status_code=404, detail="Flight not found")

        bookings = db.query(Booking).filter(
            Booking.flight_id == payload.flight_id,
            Booking.status != "CANCELLED",
        ).all()

        user_ids = {b.user_id for b in bookings if b.user_id is not None}
        for user_id in user_ids:
            db.add(
                Notification(
                    user_id=user_id,
                    flight_id=payload.flight_id,
                    title=payload.title,
                    content=payload.content,
                )
            )
        sent = len(user_ids)

        logger.info(
            f"[POST /notifications] sent={sent} flight_id={payload.flight_id} by staff={current_user.email}"
        )

    # Отправка одному пользователю
    if payload.user_id is not None and payload.flight_id is None:
        user = db.query(User).filter(User.id == payload.user_id).first()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        db.add(
            Notification(
                user_id=payload.user_id,
                flight_id=None,
                title=payload.title,
                content=payload.content,
            )
        )
        sent = 1
        logger.info(
            f"[POST /notifications] sent=1 user_id={payload.user_id} by staff={current_user.email}"
        )

    db.commit()
    return NotificationSendResponse(sent=sent, flight_id=payload.flight_id, user_id=payload.user_id)


@app.get("/notifications/all", response_model=list[NotificationResponse])
def get_all_notifications(
    current_user: User = Depends(get_current_staff),  # Проверка: только STAFF
    db: Session = Depends(get_db)
):
    """
    Получение всех уведомлений в системе (только для staff).
    
    STAFF может просматривать все уведомления, которые были отправлены пассажирам.
    Это нужно для контроля и отслеживания отправленных уведомлений.
    """
    try:
        notifications = db.query(Notification).order_by(Notification.created_at.desc()).all()
        return notifications
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to load notifications: {str(e)}"
        )


# ============================================
# СПИСОК ПАССАЖИРОВ (РґР»СЏ STAFF)
# ============================================

@app.get("/passengers", response_model=list[PassengerInfoResponse])
def get_all_passengers(
    current_user: User = Depends(get_current_staff),  # РџСЂРѕРІРµСЂРєР°: С‚РѕР»СЊРєРѕ STAFF
    db: Session = Depends(get_db)
):
    """
    Получение списка всех зарегистрированных пассажиров (только для staff).
    
    STAFF РјРѕР¶РµС‚ просматривать информацию о всех пассажирах:
    - Email
    - Имя и фамилия
    - Р”Р°С‚Р° СЂРѕР¶РґРµРЅРёСЏ
    - РќРѕРјРµСЂ РїР°СЃРїРѕСЂС‚Р°
    - РўРµР»РµС„РѕРЅ
    
    Р­С‚Рѕ РЅСѓР¶РЅРѕ для работы с пассажирами Рё РѕС‚РїСЂР°РІРєРё уведомлений.
    """
    # Получаем всех пользователей-пассажиров с их профилями
    passengers = db.query(User).filter(User.role == UserRole.PASSENGER).all()
    
    result = []
    for passenger in passengers:
        profile = db.query(PassengerProfile).filter(
            PassengerProfile.user_id == passenger.id
        ).first()
        
        if profile:
            result.append(PassengerInfoResponse(
                user_id=passenger.id,
                email=passenger.email,
                first_name=profile.first_name,
                last_name=profile.last_name,
                date_of_birth=profile.date_of_birth,
                passport_number=profile.passport_number,
                phone=profile.phone,
                created_at=profile.created_at
            ))
    
    return result


@app.post("/staff/create-staff", status_code=status.HTTP_201_CREATED)
def create_staff(
    staff_data: StaffCreate,
    current_user: User = Depends(get_current_staff),
    db: Session = Depends(get_db)
):
    """
    Создание нового сотрудника (только для существующих staff).
    
    Требуется:
    - email: Email нового сотрудника
    - password: Пароль нового сотрудника
    
    Новый сотрудник будет иметь те же права и функции, что и существующие сотрудники.
    """
    # Проверяем, не существует ли уже пользователь с таким email
    existing_user = db.query(User).filter(User.email == staff_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Создаём нового сотрудника
    hashed_password = get_password_hash(staff_data.password)
    new_staff = User(
        email=staff_data.email,
        hashed_password=hashed_password,
        role=UserRole.STAFF
    )
    db.add(new_staff)
    db.commit()
    db.refresh(new_staff)
    
    return {"message": "Staff created successfully", "email": new_staff.email}


# ============================================
# КОРНЕВОЙ ЭНДПОИНТ
# ============================================

@app.get("/")
def root():
    """Корневой эндпоинт - информация об API"""
    return {
        "message": "Airline Booking API",
        "version": "1.0.0",
        "docs": "/docs",
        "status": "running"
    }

@app.get("/")
def root():
    """Корневой эндпоинт - проверка работы API"""
    return {
        "message": "Airline Booking API is running",
        "docs": "/docs",
        "version": "1.0.0"
    }



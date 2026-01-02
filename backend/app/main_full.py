"""
main.py - Главный файл FastAPI приложения

Этот файл содержит ВСЕ эндпоинты (маршруты) нашего API.
Каждый эндпоинт - это функция, которая обрабатывает HTTP запрос.

Например:
- POST /register - регистрация пользователя
- POST /login - вход в систему
- GET /flights/search - поиск рейсов

FastAPI автоматически создаёт документацию по адресу /docs
"""

from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import secrets

from database import Base, engine, get_db
from models import (
    User, PassengerProfile, Airport, Airplane, Seat, Flight, Booking,
    Ticket, Payment, CheckIn, Announcement, Notification,
    UserRole, SeatStatus, FlightStatus, PaymentMethod, PaymentStatus
)
from schemas import (
    UserRegister, UserLogin, Token,
    PassengerProfileCreate, PassengerProfileResponse,
    AirportCreate, AirportResponse,
    AirplaneCreate, AirplaneResponse,
    FlightCreate, FlightUpdate, FlightResponse, FlightSearch, FlightWithAirportsResponse,
    SeatResponse, SeatMapResponse, SeatHoldRequest,
    BookingCreate, BookingResponse, BookingWithDetailsResponse,
    TicketResponse, TicketWithCheckInResponse,
    PaymentCreate, PaymentResponse,
    CheckInResponse, BoardingPassResponse,
    AnnouncementCreate, AnnouncementResponse,
    NotificationCreate, NotificationResponse,
    PassengerInfoResponse
)
from auth import (
    get_password_hash, verify_password, create_access_token,
    get_current_user, get_current_passenger, get_current_staff
)
from utils import create_flight_response

# Создаём приложение FastAPI
app = FastAPI(
    title="Airline Booking API",
    description="API для системы бронирования авиабилетов",
    version="1.0.0"
)

# CORS - разрешаем Flutter приложению обращаться к нашему API
# Без этого Flutter не сможет делать запросы
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В продакшене нужно указать конкретные домены
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)


# ============================================
# СОЗДАНИЕ ТАБЛИЦ ПРИ ЗАПУСКЕ
# ============================================

@app.on_event("startup")
async def startup_event():
    """
    Эта функция выполняется при запуске сервера.
    Создаёт все таблицы в базе данных, если их ещё нет.
    """
    Base.metadata.create_all(bind=engine)


# ============================================
# АУТЕНТИФИКАЦИЯ
# ============================================

@app.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def register(user_data: UserRegister, db: Session = Depends(get_db)):
    """
    Регистрация нового пользователя.
    
    Принимает email и пароль, создаёт пользователя в базе,
    возвращает JWT токен для дальнейших запросов.
    """
    # Проверяем, нет ли уже пользователя с таким email
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Создаём нового пользователя
    hashed_password = get_password_hash(user_data.password)
    new_user = User(
        email=user_data.email,
        hashed_password=hashed_password,
        role=user_data.role
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    # Создаём JWT токен
    access_token = create_access_token(data={"sub": new_user.email, "role": new_user.role.value})
    return {"access_token": access_token, "token_type": "bearer"}


@app.post("/login", response_model=Token)
def login(credentials: UserLogin, db: Session = Depends(get_db)):
    """
    Вход в систему.
    
    Проверяет email и пароль, возвращает JWT токен.
    """
    # Ищем пользователя
    user = db.query(User).filter(User.email == credentials.email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    # Проверяем пароль
    if not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )
    
    # Создаём JWT токен
    access_token = create_access_token(data={"sub": user.email, "role": user.role.value})
    return {"access_token": access_token, "token_type": "bearer"}


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
    existing_profile = db.query(PassengerProfile).filter(PassengerProfile.user_id == current_user.id).first()
    
    if existing_profile:
        # Обновляем существующий профиль
        existing_profile.first_name = profile_data.first_name
        existing_profile.last_name = profile_data.last_name
        existing_profile.date_of_birth = profile_data.date_of_birth
        existing_profile.passport_number = profile_data.passport_number
        existing_profile.phone = profile_data.phone
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
            phone=profile_data.phone
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
def create_airplane(
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
    new_airplane = Airplane(
        model=airplane_data.model,
        total_seats=len(airplane_data.seats)
    )
    db.add(new_airplane)
    db.flush()  # Получаем ID самолёта
    
    # Создаём все места
    for seat_template in airplane_data.seats:
        new_seat = Seat(
            airplane_id=new_airplane.id,
            seat_number=seat_template.seat_number,
            status=SeatStatus.AVAILABLE
        )
        db.add(new_seat)
    
    db.commit()
    db.refresh(new_airplane)
    return new_airplane


@app.get("/airplanes", response_model=list[AirplaneResponse])
def get_airplanes(db: Session = Depends(get_db)):
    """Получение списка всех самолётов"""
    airplanes = db.query(Airplane).all()
    return airplanes


# ============================================
# РЕЙСЫ
# ============================================

@app.post("/flights", response_model=FlightResponse, status_code=status.HTTP_201_CREATED)
def create_flight(
    flight_data: FlightCreate,
    current_user: User = Depends(get_current_staff),  # Проверка: только STAFF
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
    """
    new_flight = Flight(
        flight_number=flight_data.flight_number,
        departure_airport_id=flight_data.departure_airport_id,
        arrival_airport_id=flight_data.arrival_airport_id,
        departure_time=flight_data.departure_time,
        arrival_time=flight_data.arrival_time,
        airplane_id=flight_data.airplane_id,
        base_price=flight_data.base_price
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
    db: Session = Depends(get_db)
):
    """
    Поиск рейсов.
    
    Параметры:
    - from_code: код аэропорта отправления (например, "SVO")
    - to_code: код аэропорта прибытия (например, "LED")
    - date: дата в формате YYYY-MM-DD
    """
    query = db.query(Flight)
    
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
    
    # Преобразуем в ответ с аэропортами
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
    current_user: User = Depends(get_current_staff),  # Проверка: только STAFF
    db: Session = Depends(get_db)
):
    """
    Обновление статуса рейса (только для staff).
    
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
    
    old_status = flight.status
    flight.status = flight_update.status
    db.commit()
    
    # Отправляем уведомления всем пассажирам рейса при изменении статуса
    if old_status != flight_update.status:
        # Получаем всех пассажиров, у которых есть бронирования на этот рейс
        bookings = db.query(Booking).filter(Booking.flight_id == flight_id).all()
        user_ids = set(booking.user_id for booking in bookings)
        
        # Создаём уведомления
        status_messages = {
            FlightStatus.DELAYED: "Ваш рейс задержан",
            FlightStatus.CANCELLED: "Ваш рейс отменён",
            FlightStatus.BOARDING: "Началась посадка на ваш рейс",
            FlightStatus.DEPARTED: "Ваш рейс вылетел",
            FlightStatus.ARRIVED: "Ваш рейс прибыл",
            FlightStatus.COMPLETED: "Ваш рейс завершён",
        }
        
        title = status_messages.get(flight_update.status, f"Изменение статуса рейса {flight.flight_number}")
        content = f"Статус рейса {flight.flight_number} изменён на: {flight_update.status.value}"
        
        for user_id in user_ids:
            notification = Notification(
                user_id=user_id,
                flight_id=flight_id,
                title=title,
                content=content
            )
            db.add(notification)
        
        db.commit()
    
    db.refresh(flight)
    
    # Возвращаем полную информацию с аэропортами
    return create_flight_response(flight)


# ============================================
# МЕСТА И SEAT MAP
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
    что места свободны, и создаёт бронирование.
    """
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
    
    # Создаём бронирование
    new_booking = Booking(
        user_id=current_user.id,
        flight_id=booking_data.flight_id,
        status="PENDING"
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
        
        # Помечаем место как забронированное
        seat.status = SeatStatus.BOOKED
        seat.held_until = None
    
    db.commit()
    db.refresh(new_booking)
    return new_booking


@app.get("/bookings", response_model=list[BookingWithDetailsResponse])
def get_my_bookings(
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """Получение всех бронирований текущего пользователя"""
    bookings = db.query(Booking).filter(Booking.user_id == current_user.id).all()
    
    result = []
    for booking in bookings:
        # Получаем рейс с аэропортами
        flight = booking.flight
        flight_response = create_flight_response(flight)
        
        # Получаем билеты
        tickets_response = []
        for ticket in booking.tickets:
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
                ticket_number=ticket.ticket_number
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
            tickets=tickets_response,
            payments=payments_response,
            created_at=booking.created_at
        ))
    
    return result


@app.get("/bookings/all", response_model=list[BookingResponse])
def get_all_bookings(
    current_user: User = Depends(get_current_staff),  # Проверка: только STAFF
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
    bookings = db.query(Booking).all()
    return bookings


@app.get("/flights/{flight_id}/bookings", response_model=list[BookingResponse])
def get_flight_bookings(
    flight_id: int,
    current_user: User = Depends(get_current_staff),  # Проверка: только STAFF
    db: Session = Depends(get_db)
):
    """
    Получение всех бронирований по конкретному рейсу (только для staff).
    
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
    
    # Получаем все бронирования для этого рейса
    bookings = db.query(Booking).filter(Booking.flight_id == flight_id).all()
    return bookings


# ============================================
# ПЛАТЕЖИ
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
    booking.status = "CONFIRMED"
    
    db.commit()
    db.refresh(new_payment)
    return new_payment


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
    
    # Проверяем, не зарегистрирован ли уже
    existing_checkin = db.query(CheckIn).filter(CheckIn.ticket_id == ticket_id).first()
    if existing_checkin:
        return existing_checkin
    
    # Генерируем номер посадочного талона
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
    
    checkin = db.query(CheckIn).filter(CheckIn.ticket_id == ticket_id).first()
    if not checkin:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ticket not checked in"
        )
    
    flight = ticket.booking.flight
    
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
        departure_time=flight.departure_time,
        arrival_time=flight.arrival_time
    )


# ============================================
# ОБЪЯВЛЕНИЯ
# ============================================

@app.post("/announcements", response_model=AnnouncementResponse, status_code=status.HTTP_201_CREATED)
def create_announcement(
    announcement_data: AnnouncementCreate,
    current_user: User = Depends(get_current_staff),  # Проверка: только STAFF
    db: Session = Depends(get_db)
):
    """
    Создание объявления (только для staff).
    
    STAFF может создавать объявления для пассажиров:
    - Информация о задержках рейсов
    - Важные уведомления
    - Изменения в расписании
    - Общая информация для всех пассажиров
    
    Объявления видны всем пользователям (и пассажирам, и staff).
    """
    new_announcement = Announcement(
        title=announcement_data.title,
        content=announcement_data.content,
        created_by_user_id=current_user.id
    )
    db.add(new_announcement)
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

@app.post("/notifications", response_model=NotificationResponse, status_code=status.HTTP_201_CREATED)
def create_notification(
    notification_data: NotificationCreate,
    current_user: User = Depends(get_current_staff),  # Проверка: только STAFF
    db: Session = Depends(get_db)
):
    """
    Создание уведомления (только для staff).
    
    STAFF может отправлять уведомления:
    - Одному пассажиру (если указан user_id)
    - Всем пассажирам рейса (если указан flight_id, но не user_id)
    - Всем пассажирам (если не указаны ни user_id, ни flight_id)
    """
    if notification_data.user_id:
        # Отправка одному пассажиру
        notification = Notification(
            user_id=notification_data.user_id,
            flight_id=notification_data.flight_id,
            title=notification_data.title,
            content=notification_data.content
        )
        db.add(notification)
        db.commit()
        db.refresh(notification)
        return notification
    elif notification_data.flight_id:
        # Отправка всем пассажирам рейса
        bookings = db.query(Booking).filter(Booking.flight_id == notification_data.flight_id).all()
        user_ids = set(booking.user_id for booking in bookings)
        
        notifications = []
        for user_id in user_ids:
            notification = Notification(
                user_id=user_id,
                flight_id=notification_data.flight_id,
                title=notification_data.title,
                content=notification_data.content
            )
            db.add(notification)
            notifications.append(notification)
        
        db.commit()
        if notifications:
            db.refresh(notifications[0])
            return notifications[0]
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No passengers found for this flight"
            )
    else:
        # Отправка всем пассажирам
        all_passengers = db.query(User).filter(User.role == UserRole.PASSENGER).all()
        
        notifications = []
        for passenger in all_passengers:
            notification = Notification(
                user_id=passenger.id,
                flight_id=None,
                title=notification_data.title,
                content=notification_data.content
            )
            db.add(notification)
            notifications.append(notification)
        
        db.commit()
        if notifications:
            db.refresh(notifications[0])
            return notifications[0]
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No passengers found"
            )


@app.get("/notifications", response_model=list[NotificationResponse])
def get_my_notifications(
    current_user: User = Depends(get_current_passenger),
    db: Session = Depends(get_db)
):
    """Получение всех уведомлений текущего пользователя"""
    notifications = db.query(Notification).filter(
        Notification.user_id == current_user.id
    ).order_by(Notification.created_at.desc()).all()
    return notifications


# ============================================
# СПИСОК ПАССАЖИРОВ (для STAFF)
# ============================================

@app.get("/passengers", response_model=list[PassengerInfoResponse])
def get_all_passengers(
    current_user: User = Depends(get_current_staff),  # Проверка: только STAFF
    db: Session = Depends(get_db)
):
    """
    Получение списка всех зарегистрированных пассажиров (только для staff).
    
    STAFF может просматривать информацию о всех пассажирах:
    - Email
    - Имя и фамилия
    - Дата рождения
    - Номер паспорта
    - Телефон
    
    Это нужно для работы с пассажирами и отправки уведомлений.
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


"""
schemas.py - Схемы для валидации данных

Этот файл описывает, какие данные мы принимаем и отдаём через API.

Pydantic автоматически проверяет:
- правильный ли тип данных (строка, число, дата)
- есть ли обязательные поля
- правильный ли формат (например, email)

Есть два типа схем:
1. Request schemas - что приходит от клиента (Flutter)
2. Response schemas - что мы отдаём клиенту
"""

from __future__ import annotations
from typing import Optional, List, Any
from datetime import datetime
from pydantic import BaseModel, EmailStr, Field, AliasChoices, model_validator
from models import UserRole, SeatStatus, FlightStatus, PaymentMethod, PaymentStatus


# ============================================
# АУТЕНТИФИКАЦИЯ
# ============================================

class UserRegister(BaseModel):
    """Схема для регистрации пользователя"""
    email: EmailStr
    password: str
    role: UserRole = UserRole.PASSENGER  # По умолчанию пассажир

    @model_validator(mode='before')
    @classmethod
    def allow_username_as_email(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if 'username' in data and 'email' not in data:
                data['email'] = data['username']
        return data


class UserLogin(BaseModel):
    """Схема для входа"""
    email: EmailStr
    password: str

    @model_validator(mode='before')
    @classmethod
    def allow_username_as_email(cls, data: Any) -> Any:
        if isinstance(data, dict):
            if 'username' in data and 'email' not in data:
                data['email'] = data['username']
        return data


class Token(BaseModel):
    """Схема для JWT токена"""
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    """Данные внутри JWT токена"""
    email: Optional[str] = None
    role: Optional[str] = None


# ============================================
# ПРОФИЛЬ ПАССАЖИРА
# ============================================

class PassengerProfileCreate(BaseModel):
    """Схема для создания профиля пассажира"""
    first_name: str
    last_name: str
    date_of_birth: datetime
    passport_number: str
    nationality: Optional[str] = None
    phone: Optional[str] = None


class PassProfileResponse(BaseModel):
    """Схема для ответа с профилем пассажира"""
    id: int
    user_id: int
    first_name: str
    last_name: str
    date_of_birth: datetime
    passport_number: str
    nationality: Optional[str]
    phone: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True  # Позволяет создавать из SQLAlchemy модели


# ============================================
# АЭРОПОРТЫ
# ============================================

class AirportCreate(BaseModel):
    """Схема для создания аэропорта"""
    code: str
    name: str
    city: str
    country: str


class AirportResponse(BaseModel):
    """Схема для ответа с аэропортом"""
    id: int
    code: str
    name: str
    city: str
    country: str
    
    class Config:
        from_attributes = True


# ============================================
# САМОЛЁТЫ
# ============================================

class SeatTemplateCreate(BaseModel):
    """Схема для создания шаблона мест в самолёте"""
    seat_number: str  # Например, "1A", "1B", "2A", "2B"


class AirplaneCreate(BaseModel):
    """Схема для создания самолёта"""
    model: str
    seats: Optional[List[SeatTemplateCreate]] = None  # Список вручную заданных мест
    rows: Optional[int] = None
    seats_per_row: Optional[int] = None
    seat_letters: Optional[str] = "ABCDEFGH"


class AirplaneResponse(BaseModel):
    """Схема для ответа с самолётом"""
    id: int
    model: str
    total_seats: int
    
    class Config:
        from_attributes = True


# ============================================
# РЕЙСЫ
# ============================================

class FlightCreate(BaseModel):
    """Схема для создания рейса"""
    flight_number: str
    departure_airport_id: int
    arrival_airport_id: int
    departure_time: datetime
    arrival_time: datetime
    airplane_id: int
    base_price: float


class FlightUpdate(BaseModel):
    """Схема для обновления статуса рейса"""
    status: FlightStatus


class FlightResponse(BaseModel):
    """Схема для ответа с рейсом"""
    id: int
    flight_number: str
    departure_airport_id: int
    arrival_airport_id: int
    departure_time: datetime
    arrival_time: datetime
    airplane_id: int
    status: FlightStatus
    base_price: float
    created_at: datetime
    
    class Config:
        from_attributes = True


class FlightSearch(BaseModel):
    """Схема для поиска рейсов"""
    from_airport_code: Optional[str] = None
    to_airport_code: Optional[str] = None
    date: Optional[datetime] = None


class FlightWithAirportsResponse(BaseModel):
    """Схема для ответа с рейсом и аэропортами"""
    id: int
    flight_number: str
    departure_airport: AirportResponse
    arrival_airport: AirportResponse
    departure_time: datetime
    arrival_time: datetime
    airplane_id: int
    status: FlightStatus
    base_price: float
    
    class Config:
        from_attributes = True


# ============================================
# МЕСТА
# ============================================

class SeatResponse(BaseModel):
    """Схема для ответа с местом"""
    id: int
    airplane_id: int
    seat_number: str
    status: SeatStatus
    held_until: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class SeatMapResponse(BaseModel):
    """Схема для ответа с картой мест (seat map)"""
    flight_id: int
    seats: List[SeatResponse]


class SeatHoldRequest(BaseModel):
    """Схема для удержания места"""
    seat_id: int


# ============================================
# БРОНИРОВАНИЯ
# ============================================

class BookingCreate(BaseModel):
    """Схема для создания бронирования"""
    flight_id: int
    seat_ids: List[int]  # Список ID мест, которые хотим забронировать


class BookingResponse(BaseModel):
    """Схема для ответа с бронированием"""
    id: int
    user_id: int
    flight_id: int
    status: str
    created_at: datetime
    expires_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class BookingWithDetailsResponse(BaseModel):
    """Схема для ответа с детальной информацией о бронировании"""
    id: int
    flight: FlightWithAirportsResponse
    status: str
    tickets: List['TicketResponse']
    payments: List['PaymentResponse']
    created_at: datetime
    expires_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class PassengerPerSeatCreate(BaseModel):
    """Схема для предоставления данных пассажира для места"""
    full_name: str
    birth_date: datetime
    document_number: str


class PassengerPerSeatResponse(BaseModel):
    """Схема для ответа с данными пассажира для места"""
    id: int
    seat_id: int
    booking_id: int
    full_name: str
    birth_date: datetime
    document_number: str
    ticket_number: Optional[str] = None

    class Config:
        from_attributes = True


# ============================================
# БИЛЕТЫ
# ============================================

class TicketResponse(BaseModel):
    """Схема для ответа с билетом (фактически это Passenger)"""
    id: int
    booking_id: int
    seat: SeatResponse
    full_name: Optional[str] = None
    ticket_number: Optional[str] = None
    
    class Config:
        from_attributes = True


class TicketWithCheckInResponse(BaseModel):
    """Схема для ответа с билетом и check-in"""
    id: int
    booking_id: int
    seat: SeatResponse
    full_name: Optional[str] = None
    ticket_number: Optional[str] = None
    check_in: Optional[CheckInResponse] = None
    
    class Config:
        from_attributes = True


# ============================================
# ПЛАТЕЖИ
# ============================================

class PaymentCreate(BaseModel):
    """Схема для создания платежа"""
    booking_id: int
    method: PaymentMethod


class PaymentResponse(BaseModel):
    """Схема для ответа с платежом"""
    id: int
    booking_id: int
    amount: float
    method: PaymentMethod
    status: PaymentStatus
    created_at: datetime
    
    class Config:
        from_attributes = True

 
# ============================================
# CHECK-IN
# ============================================

class CheckInResponse(BaseModel):
    """Схема для ответа с check-in"""
    id: int
    passenger_id: int
    boarding_pass_number: str
    checked_in_at: datetime
    
    class Config:
        from_attributes = True


class BoardingPassResponse(BaseModel):
    """Схема для посадочного талона"""
    ticket: 'TicketWithCheckInResponse'
    flight: FlightWithAirportsResponse
    boarding_pass_number: str
    passenger_name: str
    seat_number: str
    departure_time: datetime
    arrival_time: datetime


# ============================================
# ОБЪЯВЛЕНИЯ
# ============================================

class AnnouncementCreate(BaseModel):
    """Схема для создания объявления"""
    title: str
    content: str


class AnnouncementResponse(BaseModel):
    """Схема для ответа с объявлением"""
    id: int
    title: str
    content: str
    created_by_user_id: int
    created_at: datetime
    
    class Config:
        from_attributes = True


# ============================================
# УВЕДОМЛЕНИЯ
# ============================================

class NotificationCreate(BaseModel):
    """Схема для создания уведомления"""
    user_id: Optional[int] = None  # Если None - отправляется всем пассажирам
    flight_id: Optional[int] = None  # Если указан - только пассажирам этого рейса
    title: str
    content: str


class NotificationResponse(BaseModel):
    """Схема для ответа с уведомлением"""
    id: int
    user_id: int
    flight_id: Optional[int] = None
    title: str
    content: str
    is_read: bool
    created_at: datetime
    
    class Config:
        from_attributes = True


# ============================================
# СПИСОК ПАССАЖИРОВ (для STAFF)
# ============================================

class PassengerInfoResponse(BaseModel):
    """Схема для информации о пассажире"""
    user_id: int
    email: str
    first_name: str
    last_name: str
    date_of_birth: datetime
    passport_number: str
    phone: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True


# Разрешаем forward references после определения всех классов
# Это нужно для того, чтобы Pydantic мог правильно обработать типы,
# которые ссылаются на классы, определённые позже в файле
BookingWithDetailsResponse.model_rebuild()
TicketWithCheckInResponse.model_rebuild()
BoardingPassResponse.model_rebuild()


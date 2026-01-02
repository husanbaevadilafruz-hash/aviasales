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
from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator
from typing import Optional, List, Any
from datetime import datetime
from app.models.models import UserRole, SeatStatus, FlightStatus, PaymentMethod, PaymentStatus


# ============================================
# АУТЕНТИФИКАЦИЯ
# ============================================

class UserRegister(BaseModel):
    """Схема для регистрации пользователя"""
    email: EmailStr
    password: str
    role: UserRole = UserRole.PASSENGER  # По умолчанию пассажир


class UserLogin(BaseModel):
    """Схема для входа"""
    email: EmailStr
    password: str


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
    phone: str
    nationality: str


class PassengerProfileResponse(BaseModel):
    """Схема для ответа с профилем пассажира"""
    id: int
    user_id: int
    first_name: str
    last_name: str
    date_of_birth: datetime
    passport_number: str
    phone: Optional[str]
    nationality: Optional[str]
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
    category: str = "STANDARD"  # Категория: "STANDARD" или "EXTRA_LEGROOM"


class AirplaneCreate(BaseModel):
    """Схема для создания самолёта
    
    Поддерживает два режима:
    1. Автоматическая генерация: укажите rows и seats_per_row
    2. Ручной список: укажите seats
    
    Для указания категорий мест используйте extra_legroom_rows (номера рядов с доп. местом для ног)
    """
    model: str
    rows: Optional[int] = None  # Количество рядов (например, 30) - для автоматической генерации
    seats_per_row: Optional[int] = None  # Количество мест в ряду (например, 6) - для автоматической генерации
    seat_letters: str = "ABCDEFGH"  # Буквы для мест (по умолчанию A-H)
    seats: Optional[List[SeatTemplateCreate]] = None  # Опционально: ручной список мест (если не указан, генерируется автоматически)
    extra_legroom_rows: Optional[List[int]] = None  # Ряды с дополнительным местом для ног (например, [1, 12, 13])
    
    @model_validator(mode='before')
    @classmethod
    def validate_and_set_defaults(cls, data: Any) -> Any:
        """Устанавливаем seats в None, если оно не передано"""
        if isinstance(data, dict):
            # Если seats не передано, устанавливаем в None
            if 'seats' not in data:
                data['seats'] = None
        return data


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
    gate: str = ""  # Gate (выход на посадку). Может быть пустой строкой.


class FlightUpdate(BaseModel):
    """Схема для обновления статуса рейса и времени вылета/прилёта"""
    status: FlightStatus
    departure_time: Optional[datetime] = None  # Новое время вылета (для DELAYED)
    arrival_time: Optional[datetime] = None    # Новое время прилёта (для DELAYED)


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
    gate: str = ""
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
    gate: str = ""
    
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
    category: str = "STANDARD"  # Категория: "STANDARD" или "EXTRA_LEGROOM"
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
    pnr: str
    created_at: datetime
    
    class Config:
        from_attributes = True


class BookingWithDetailsResponse(BaseModel):
    """Схема для ответа с детальной информацией о бронировании"""
    id: int
    flight: FlightWithAirportsResponse
    status: str
    pnr: str
    tickets: List['TicketResponse']
    payments: List['PaymentResponse']
    created_at: datetime
    
    class Config:
        from_attributes = True


# ============================================
# БИЛЕТЫ
# ============================================

class TicketResponse(BaseModel):
    """Схема для ответа с билетом"""
    id: int
    booking_id: int
    seat: SeatResponse
    passenger_first_name: str
    passenger_last_name: str
    ticket_number: str
    full_name: Optional[str] = None  # Полное имя пассажира для Flutter
    check_in: Optional['CheckInResponse'] = None  # Если пассажир сделал check-in
    
    class Config:
        from_attributes = True


class TicketWithCheckInResponse(BaseModel):
    """Схема для ответа с билетом и check-in"""
    id: int
    booking_id: int
    seat: SeatResponse
    passenger_first_name: str
    passenger_last_name: str
    ticket_number: str
    check_in: Optional['CheckInResponse'] = None
    
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
    ticket_id: int
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
    gate: str
    boarding_time: datetime
    qr_payload: str
    departure_time: datetime
    arrival_time: datetime


# ============================================
# ОБЪЯВЛЕНИЯ
# ============================================

class AnnouncementCreate(BaseModel):
    """Схема для создания объявления"""
    title: str
    content: str
    flight_id: int  # Обязательно - объявление отправляется только пассажирам этого рейса


class AnnouncementResponse(BaseModel):
    """Схема для ответа с объявлением"""
    id: int
    title: str
    content: str
    flight_id: int
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


class NotificationSendResponse(BaseModel):
    """Ответ на отправку уведомления (сколько получателей)"""
    sent: int
    flight_id: Optional[int] = None
    user_id: Optional[int] = None


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


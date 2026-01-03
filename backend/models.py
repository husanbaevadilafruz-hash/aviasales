"""
models.py - Модели базы данных (таблицы)

Этот файл описывает ВСЕ таблицы нашей базы данных.
Каждый класс - это одна таблица.

Например:
- User - таблица пользователей
- Flight - таблица рейсов
- Booking - таблица бронирований

SQLAlchemy автоматически создаст эти таблицы в базе данных.
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import relationship
from datetime import datetime
import enum

try:
    # При запуске из корневой папки backend
    from database import Base
except ImportError:
    # При запуске из другой папки
    from app.core.database import Base


# ============================================
# ENUMS (Перечисления) - фиксированные списки значений
# ============================================

class UserRole(str, enum.Enum):
    """Роли пользователей"""
    PASSENGER = "PASSENGER"  # Пассажир
    STAFF = "STAFF"  # Сотрудник авиакомпании


class SeatStatus(str, enum.Enum):
    """Статусы мест в самолёте"""
    AVAILABLE = "AVAILABLE"  # Свободно
    HELD = "HELD"  # Временно удержано (выбрано, но не оплачено)
    BOOKED = "BOOKED"  # Забронировано


class FlightStatus(str, enum.Enum):
    """Статусы рейса"""
    SCHEDULED = "SCHEDULED"  # Запланирован
    DELAYED = "DELAYED"  # Задержан
    BOARDING = "BOARDING"  # Посадка
    DEPARTED = "DEPARTED"  # Вылетел
    ARRIVED = "ARRIVED"  # Прибыл
    CANCELLED = "CANCELLED"  # Отменён
    COMPLETED = "COMPLETED"  # Завершён


class PaymentMethod(str, enum.Enum):
    """Способы оплаты"""
    CARD = "CARD"
    APPLE_PAY = "APPLE_PAY"
    GOOGLE_PAY = "GOOGLE_PAY"


class PaymentStatus(str, enum.Enum):
    """Статусы оплаты"""
    PENDING = "PENDING"  # Ожидает оплаты
    PAID = "PAID"  # Оплачено
    FAILED = "FAILED"  # Ошибка оплаты


# ============================================
# МОДЕЛИ (ТАБЛИЦЫ)
# ============================================

class User(Base):
    """
    Таблица пользователей
    
    Хранит:
    - email и пароль для входа
    - роль (PASSENGER или STAFF)
    """
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)  # Зашифрованный пароль
    role = Column(SQLEnum(UserRole), nullable=False, default=UserRole.PASSENGER)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Связь: один пользователь может иметь один профиль пассажира
    passenger_profile = relationship("PassengerProfile", back_populates="user", uselist=False)
    
    # Связь: один пользователь может иметь много бронирований
    bookings = relationship("Booking", back_populates="user")


class PassengerProfile(Base):
    """
    Таблица профилей пассажиров
    
    Хранит личные данные пассажира:
    - имя, фамилия, дата рождения, паспорт
    - эти данные нужны для бронирования билетов
    """
    __tablename__ = "passenger_profiles"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    date_of_birth = Column(DateTime, nullable=False)
    passport_number = Column(String, nullable=False)
    nationality = Column(String, nullable=True)
    phone = Column(String)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Связь: профиль принадлежит одному пользователю
    user = relationship("User", back_populates="passenger_profile")


class Airport(Base):
    """
    Таблица аэропортов
    
    Хранит информацию об аэропортах:
    - код (например, "SVO" для Шереметьево)
    - название и город
    """
    __tablename__ = "airports"
    
    id = Column(Integer, primary_key=True, index=True)
    code = Column(String, unique=True, nullable=False, index=True)  # Например, "SVO"
    name = Column(String, nullable=False)
    city = Column(String, nullable=False)
    country = Column(String, nullable=False)
    
    # Связь: один аэропорт может быть началом многих рейсов
    departure_flights = relationship("Flight", foreign_keys="Flight.departure_airport_id", back_populates="departure_airport")
    
    # Связь: один аэропорт может быть концом многих рейсов
    arrival_flights = relationship("Flight", foreign_keys="Flight.arrival_airport_id", back_populates="arrival_airport")


class Airplane(Base):
    """
    Таблица самолётов
    
    Хранит информацию о самолётах:
    - модель, количество мест
    - шаблон мест (например, "A1,B1,C1,D1" - это 4 места в ряду)
    """
    __tablename__ = "airplanes"
    
    id = Column(Integer, primary_key=True, index=True)
    model = Column(String, nullable=False)  # Например, "Boeing 737"
    total_seats = Column(Integer, nullable=False)  # Общее количество мест
    is_active = Column(Boolean, default=True)  # Активен ли самолёт (для удаления)
    
    # Связь: один самолёт может использоваться в разных рейсах
    flights = relationship("Flight", back_populates="airplane")
    
    # Связь: один самолёт имеет много мест
    seats = relationship("Seat", back_populates="airplane")


class Seat(Base):
    """
    Таблица мест в самолёте
    
    Хранит информацию о каждом месте:
    - номер места (например, "1A", "12B")
    - статус (свободно, удержано, забронировано)
    - время истечения удержания (если статус HELD)
    """
    __tablename__ = "seats"
    
    id = Column(Integer, primary_key=True, index=True)
    airplane_id = Column(Integer, ForeignKey("airplanes.id"), nullable=False)
    seat_number = Column(String, nullable=False)  # Например, "1A", "12B"
    status = Column(SQLEnum(SeatStatus), default=SeatStatus.AVAILABLE)
    
    # Для удержания места: когда истекает удержание
    held_until = Column(DateTime, nullable=True)
    
    # Связь: место принадлежит одному самолёту
    airplane = relationship("Airplane", back_populates="seats")


class Flight(Base):
    """
    Таблица рейсов
    
    Хранит информацию о каждом рейсе:
    - откуда и куда летим
    - когда вылет и прилёт
    - какой самолёт
    - статус рейса
    - цена билета
    """
    __tablename__ = "flights"
    
    id = Column(Integer, primary_key=True, index=True)
    flight_number = Column(String, nullable=False, index=True)  # Например, "SU123"
    
    departure_airport_id = Column(Integer, ForeignKey("airports.id"), nullable=False)
    arrival_airport_id = Column(Integer, ForeignKey("airports.id"), nullable=False)
    
    departure_time = Column(DateTime, nullable=False)
    arrival_time = Column(DateTime, nullable=False)
    
    airplane_id = Column(Integer, ForeignKey("airplanes.id"), nullable=False)
    status = Column(SQLEnum(FlightStatus), default=FlightStatus.SCHEDULED)
    
    base_price = Column(Float, nullable=False)  # Базовая цена билета
    
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Связи
    departure_airport = relationship("Airport", foreign_keys=[departure_airport_id], back_populates="departure_flights")
    arrival_airport = relationship("Airport", foreign_keys=[arrival_airport_id], back_populates="arrival_flights")
    airplane = relationship("Airplane", back_populates="flights")
    
    # Связь: один рейс может иметь много бронирований
    bookings = relationship("Booking", back_populates="flight")


class Booking(Base):
    """
    Таблица бронирований
    
    Хранит информацию о бронировании:
    - кто бронирует (пользователь)
    - какой рейс
    - статус бронирования
    - когда создано
    """
    __tablename__ = "bookings"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    flight_id = Column(Integer, ForeignKey("flights.id"), nullable=False)
    
    status = Column(String, default="PENDING")  # PENDING, PENDING_PAYMENT, PAID, CANCELLED
    
    created_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=True)  # For payment timeout
    
    # Связи
    user = relationship("User", back_populates="bookings")
    flight = relationship("Flight", back_populates="bookings")
    
    # Связь: одно бронирование может иметь много платежей
    payments = relationship("Payment", back_populates="booking")
    
    # Связь: одно бронирование имеет данные пассажиров (билеты)
    passengers = relationship("Passenger", back_populates="booking", cascade="all, delete-orphan")




class Passenger(Base):
    """
    Таблица данных о пассажирах для каждого места в бронировании.
    Фактически представляет собой "Билет".
    
    Одна запись соответствует одному пассажиру на конкретном месте.
    """
    __tablename__ = "passengers"
    
    id = Column(Integer, primary_key=True, index=True)
    seat_id = Column(Integer, ForeignKey("seats.id"), nullable=False)
    booking_id = Column(Integer, ForeignKey("bookings.id"), nullable=False)
    
    # Поля nullable, чтобы можно было сначала забронировать место, а потом ввести данные
    full_name = Column(String, nullable=True)
    birth_date = Column(DateTime, nullable=True)
    document_number = Column(String, nullable=True)
    
    # Уникальный номер билета (генерируется при создании)
    ticket_number = Column(String, unique=True, nullable=True)
    
    # Связи
    booking = relationship("Booking", back_populates="passengers")
    seat = relationship("Seat", backref="passengers")
    
    # Связь: один пассажир (билет) может иметь один check-in
    check_in = relationship("CheckIn", back_populates="passenger", uselist=False)


class Payment(Base):
    """
    Таблица платежей
    
    Хранит информацию об оплате:
    - какое бронирование оплачивается
    - способ оплаты (карта, Apple Pay, Google Pay)
    - статус (ожидает, оплачено, ошибка)
    - сумма
    """
    __tablename__ = "payments"
    
    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"), nullable=False)
    
    amount = Column(Float, nullable=False)
    method = Column(SQLEnum(PaymentMethod), nullable=False)
    status = Column(SQLEnum(PaymentStatus), default=PaymentStatus.PENDING)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Связь: платёж принадлежит одному бронированию
    booking = relationship("Booking", back_populates="payments")


class CheckIn(Base):
    """
    Таблица регистраций на рейс (check-in)
    
    Хранит информацию о регистрации:
    - какой пассажир (билет)
    - когда зарегистрировался
    - номер посадочного талона
    """
    __tablename__ = "check_ins"
    
    id = Column(Integer, primary_key=True, index=True)
    passenger_id = Column(Integer, ForeignKey("passengers.id"), unique=True, nullable=False)
    
    boarding_pass_number = Column(String, unique=True, nullable=False)  # Номер посадочного талона
    checked_in_at = Column(DateTime, default=datetime.utcnow)
    
    # Связь: регистрация принадлежит одному пассажиру
    passenger = relationship("Passenger", back_populates="check_in")


class Announcement(Base):
    """
    Таблица объявлений
    
    Хранит объявления от сотрудников авиакомпании:
    - заголовок и текст
    - кто создал (staff пользователь)
    - когда создано
    """
    __tablename__ = "announcements"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    content = Column(String, nullable=False)
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Связь: объявление создано одним пользователем (staff)
    created_by = relationship("User")


class Notification(Base):
    """
    Таблица уведомлений для пассажиров
    
    Хранит персональные уведомления:
    - кому отправлено (пользователь)
    - к какому рейсу относится (опционально)
    - заголовок и текст
    - прочитано ли
    """
    __tablename__ = "notifications"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    flight_id = Column(Integer, ForeignKey("flights.id"), nullable=True)  # Может быть общим уведомлением
    title = Column(String, nullable=False)
    content = Column(String, nullable=False)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Связи
    user = relationship("User")
    flight = relationship("Flight")


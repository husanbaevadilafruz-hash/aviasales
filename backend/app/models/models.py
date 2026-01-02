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
from datetime import datetime, timedelta
import enum
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


class SeatCategory(str, enum.Enum):
    """Категории мест"""
    STANDARD = "STANDARD"  # Стандартное место
    EXTRA_LEGROOM = "EXTRA_LEGROOM"  # Место с дополнительным пространством для ног


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
    # Телефон, гражданство и email требуются бизнес-логикой, но оставляем nullable=True для совместимости
    # со старыми SQLite базами и существующими записями.
    phone = Column(String, nullable=True)
    nationality = Column(String, nullable=True)
    email = Column(String, nullable=True)
    
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
    is_active = Column(Boolean, default=True)  # Активен ли самолёт (для soft delete)
    
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
    category = Column(SQLEnum(SeatCategory), default=SeatCategory.STANDARD)  # Категория места
    
    # Для удержания места: когда истекает удержание
    held_until = Column(DateTime, nullable=True)
    
    # Связь: место принадлежит одному самолёту
    airplane = relationship("Airplane", back_populates="seats")
    
    # Связь: место может быть в разных билетах (но только один активный)
    tickets = relationship("Ticket", back_populates="seat")


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

    # Gate (выход на посадку). Пустая строка допустима.
    # nullable=True для совместимости со старыми SQLite базами (если колонка добавится позже).
    gate = Column(String, nullable=True, default="")
    
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
    - статус бронирования (CREATED, CONFIRMED, CANCELLED)
    - когда создано
    """
    __tablename__ = "bookings"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    flight_id = Column(Integer, ForeignKey("flights.id"), nullable=False)
    
    status = Column(String, default="CREATED")  # CREATED, CONFIRMED, CANCELLED
    created_at = Column(DateTime, default=datetime.utcnow)

    # Unique PNR code for each booking
    pnr = Column(String, unique=True, index=True, nullable=True)
    
    # Связи
    user = relationship("User", back_populates="bookings")
    flight = relationship("Flight", back_populates="bookings")
    
    # Связь: одно бронирование может иметь много билетов
    tickets = relationship("Ticket", back_populates="booking")
    
    # Связь: одно бронирование может иметь много платежей
    payments = relationship("Payment", back_populates="booking")
    
    def is_expired(self) -> bool:
        """
        Проверяет, истекло ли время бронирования.
        Бронирование истекает, если статус CREATED и прошло более 10 минут с created_at.
        """
        if self.status != "CREATED":
            return False
        
        if not self.created_at:
            return False
        
        now = datetime.utcnow()
        time_diff = now - self.created_at
        return time_diff > timedelta(minutes=10)


class Ticket(Base):
    """
    Таблица билетов
    
    Хранит информацию о каждом билете:
    - какое место
    - для какого пассажира (имя, фамилия из профиля)
    - номер билета
    """
    __tablename__ = "tickets"
    
    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"), nullable=False)
    seat_id = Column(Integer, ForeignKey("seats.id"), nullable=False)
    
    passenger_first_name = Column(String, nullable=False)
    passenger_last_name = Column(String, nullable=False)
    ticket_number = Column(String, unique=True, nullable=False)  # Уникальный номер билета
    
    # Связи
    booking = relationship("Booking", back_populates="tickets")
    seat = relationship("Seat", back_populates="tickets")
    
    # Связь: один билет может иметь один check-in
    check_in = relationship("CheckIn", back_populates="ticket", uselist=False)


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
    - какой билет
    - когда зарегистрировался
    - номер посадочного талона
    """
    __tablename__ = "check_ins"
    
    id = Column(Integer, primary_key=True, index=True)
    ticket_id = Column(Integer, ForeignKey("tickets.id"), unique=True, nullable=False)
    
    boarding_pass_number = Column(String, unique=True, nullable=False)  # Номер посадочного талона
    checked_in_at = Column(DateTime, default=datetime.utcnow)
    
    # Связь: регистрация принадлежит одному билету
    ticket = relationship("Ticket", back_populates="check_in")


class Announcement(Base):
    """
    Таблица объявлений
    
    Хранит объявления от сотрудников авиакомпании:
    - заголовок и текст
    - кто создал (staff пользователь)
    - к какому рейсу относится (обязательно)
    - когда создано
    """
    __tablename__ = "announcements"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    content = Column(String, nullable=False)
    flight_id = Column(Integer, ForeignKey("flights.id"), nullable=False)  # Обязательно привязано к рейсу
    created_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Связь: объявление создано одним пользователем (staff) и относится к одному рейсу
    created_by = relationship("User")
    flight = relationship("Flight")


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


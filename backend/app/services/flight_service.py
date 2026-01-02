"""
FlightService - сервис управления рейсами

Отвечает за:
- Автоматическое обновление статусов рейсов по времени
- Бизнес-логику изменения статусов
- Интеграцию с NotificationService
"""

from datetime import datetime, timedelta
from typing import List, Tuple, Optional
from sqlalchemy.orm import Session

from app.models import Flight, FlightStatus
from app.services.notification_service import NotificationService


class FlightService:
    """Сервис для работы с рейсами"""
    
    @classmethod
    def get_next_automatic_status(
        cls,
        flight: Flight,
        current_time: Optional[datetime] = None
    ) -> Optional[FlightStatus]:
        """
        Определить следующий автоматический статус рейса на основе времени
        
        Правила:
        - SCHEDULED + (departure_time - 30 мин) → BOARDING
        - BOARDING + departure_time → DEPARTED
        - DEPARTED + arrival_time → ARRIVED
        - ARRIVED + (arrival_time + 15 мин) → COMPLETED
        - CANCELLED - не меняется автоматически
        - DELAYED - применяется та же логика относительно обновлённых времён
        
        Returns:
            Новый статус или None, если изменение не требуется
        """
        # В проекте времена рейсов (departure_time/arrival_time) приходят без timezone
        # и хранятся как "наивные" datetime. Чтобы сравнения работали как ожидает пользователь,
        # используем локальное время сервера (datetime.now()), а не utcnow().
        if current_time is None:
            current_time = datetime.now()
        
        current_status = flight.status
        departure_time = flight.departure_time
        arrival_time = flight.arrival_time
        
        # CANCELLED - не меняем автоматически
        if current_status == FlightStatus.CANCELLED:
            return None
        
        # COMPLETED - уже финальный статус
        if current_status == FlightStatus.COMPLETED:
            return None
        
        # SCHEDULED или DELAYED → BOARDING (за 30 минут до вылета)
        if current_status in [FlightStatus.SCHEDULED, FlightStatus.DELAYED]:
            boarding_time = departure_time - timedelta(minutes=30)
            if current_time >= boarding_time:
                return FlightStatus.BOARDING
        
        # BOARDING → DEPARTED (в момент вылета)
        if current_status == FlightStatus.BOARDING:
            if current_time >= departure_time:
                return FlightStatus.DEPARTED
        
        # DEPARTED → ARRIVED (в момент прибытия)
        if current_status == FlightStatus.DEPARTED:
            if current_time >= arrival_time:
                return FlightStatus.ARRIVED
        
        # ARRIVED → COMPLETED (через 15 минут после прибытия)
        if current_status == FlightStatus.ARRIVED:
            completed_time = arrival_time + timedelta(minutes=15)
            if current_time >= completed_time:
                return FlightStatus.COMPLETED
        
        return None
    
    @classmethod
    def update_flight_status(
        cls,
        db: Session,
        flight: Flight,
        new_status: FlightStatus,
        send_notifications: bool = True
    ) -> Flight:
        """
        Обновить статус рейса и отправить уведомления
        
        Args:
            db: Сессия базы данных
            flight: Рейс для обновления
            new_status: Новый статус
            send_notifications: Отправлять ли уведомления пассажирам
        
        Returns:
            Обновлённый рейс
        """
        old_status = flight.status
        
        if old_status == new_status:
            return flight
        
        # Обновляем статус
        flight.status = new_status
        
        # В Windows консоли (cp1251) символ "→" может вызывать UnicodeEncodeError.
        # Используем ASCII, чтобы фоновые задачи не падали.
        print(f"[FlightService] Рейс {flight.flight_number}: {old_status.value} -> {new_status.value}")
        
        # Отправляем уведомления пассажирам
        if send_notifications:
            NotificationService.notify_flight_passengers(
                db=db,
                flight=flight,
                new_status=new_status
            )
        
        return flight
    
    @classmethod
    def process_automatic_status_updates(cls, db: Session) -> List[Tuple[Flight, FlightStatus, FlightStatus]]:
        """
        Обработать автоматические обновления статусов для всех активных рейсов
        
        Returns:
            Список кортежей (рейс, старый_статус, новый_статус) для обновлённых рейсов
        """
        current_time = datetime.now()
        updated_flights = []
        
        # Получаем все рейсы, которые могут требовать обновления статуса
        active_statuses = [
            FlightStatus.SCHEDULED,
            FlightStatus.DELAYED,
            FlightStatus.BOARDING,
            FlightStatus.DEPARTED,
            FlightStatus.ARRIVED,
        ]
        
        flights = db.query(Flight).filter(
            Flight.status.in_(active_statuses)
        ).all()
        
        for flight in flights:
            # Если время рейса давно прошло, за один тик фоновой задачи
            # можно "догнать" статус до актуального, а не ждать 3-4 минуты.
            while True:
                old_status = flight.status
                new_status = cls.get_next_automatic_status(flight, current_time)

                if not new_status or new_status == old_status:
                    break

                cls.update_flight_status(
                    db=db,
                    flight=flight,
                    new_status=new_status,
                    send_notifications=True
                )
                updated_flights.append((flight, old_status, new_status))
        
        if updated_flights:
            db.commit()
            print(f"[FlightService] Автоматически обновлено {len(updated_flights)} рейсов")
        
        return updated_flights
    
    @classmethod
    def get_flights_requiring_update(cls, db: Session) -> List[Flight]:
        """Получить рейсы, требующие обновления статуса"""
        current_time = datetime.utcnow()
        flights_to_update = []
        
        active_statuses = [
            FlightStatus.SCHEDULED,
            FlightStatus.DELAYED,
            FlightStatus.BOARDING,
            FlightStatus.DEPARTED,
            FlightStatus.ARRIVED,
        ]
        
        flights = db.query(Flight).filter(
            Flight.status.in_(active_statuses)
        ).all()
        
        for flight in flights:
            new_status = cls.get_next_automatic_status(flight, current_time)
            if new_status:
                flights_to_update.append(flight)
        
        return flights_to_update


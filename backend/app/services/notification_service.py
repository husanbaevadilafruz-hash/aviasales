"""
NotificationService - сервис уведомлений пассажиров

Отвечает за:
- Создание уведомлений в базе данных
- Отправку уведомлений пассажирам при изменении статуса рейса
"""

from datetime import datetime
from typing import List, Optional
from sqlalchemy.orm import Session

from app.models import (
    Notification,
    Flight,
    Booking,
    User,
    FlightStatus,
)


class NotificationService:
    """Сервис для работы с уведомлениями"""
    
    # Тексты уведомлений для разных статусов
    STATUS_MESSAGES = {
        FlightStatus.BOARDING: "Началась посадка на рейс {flight_number}. Пожалуйста, пройдите к выходу на посадку.",
        FlightStatus.DEPARTED: "Рейс {flight_number} вылетел. Хорошего полёта!",
        FlightStatus.ARRIVED: "Рейс {flight_number} прибыл в пункт назначения.",
        FlightStatus.COMPLETED: "Рейс {flight_number} завершён. Спасибо, что летали с нами!",
        FlightStatus.CANCELLED: "Внимание! Рейс {flight_number} отменён. Свяжитесь с поддержкой для возврата средств.",
        FlightStatus.DELAYED: "Рейс {flight_number} задерживается. Следите за обновлениями.",
    }
    
    @classmethod
    def get_status_message(cls, status: FlightStatus, flight_number: str) -> str:
        """Получить текст уведомления для статуса"""
        template = cls.STATUS_MESSAGES.get(status, "Статус рейса {flight_number} изменён на {status}")
        return template.format(flight_number=flight_number, status=status.value)
    
    @classmethod
    def create_notification(
        cls,
        db: Session,
        user_id: int,
        title: str,
        message: str,
        flight_id: int = None
    ) -> Notification:
        """Создать уведомление для пользователя"""
        notification = Notification(
            user_id=user_id,
            flight_id=flight_id,
            title=title,
            content=message,  # В модели поле называется content
            is_read=False,
            created_at=datetime.utcnow()
        )
        db.add(notification)
        return notification
    
    @classmethod
    def notify_flight_passengers(
        cls,
        db: Session,
        flight: Flight,
        new_status: FlightStatus,
        custom_message: Optional[str] = None
    ) -> List[Notification]:
        """
        Отправить уведомления всем пассажирам рейса
        
        Args:
            db: Сессия базы данных
            flight: Рейс
            new_status: Новый статус рейса
            custom_message: Кастомное сообщение (опционально)
        
        Returns:
            Список созданных уведомлений
        """
        notifications = []
        
        # Получаем все активные бронирования этого рейса
        active_statuses = ['CONFIRMED', 'PAID', 'CREATED', 'PENDING_PAYMENT']
        bookings = db.query(Booking).filter(
            Booking.flight_id == flight.id,
            Booking.status.in_(active_statuses)
        ).all()
        
        # Формируем сообщение
        title = f"Рейс {flight.flight_number}"
        message = custom_message or cls.get_status_message(new_status, flight.flight_number)
        
        # Собираем уникальных пользователей
        user_ids = set()
        for booking in bookings:
            if booking.user_id:
                user_ids.add(booking.user_id)
        
        # Создаём уведомления
        for user_id in user_ids:
            notification = cls.create_notification(
                db=db,
                user_id=user_id,
                title=title,
                message=message,
                flight_id=flight.id
            )
            notifications.append(notification)
        
        print(f"[NotificationService] Отправлено {len(notifications)} уведомлений для рейса {flight.flight_number} (статус: {new_status.value})")
        
        return notifications
    
    @classmethod
    def get_user_notifications(
        cls,
        db: Session,
        user_id: int,
        unread_only: bool = False,
        limit: int = 50
    ) -> List[Notification]:
        """Получить уведомления пользователя"""
        query = db.query(Notification).filter(Notification.user_id == user_id)
        
        if unread_only:
            query = query.filter(Notification.is_read == False)
        
        return query.order_by(Notification.created_at.desc()).limit(limit).all()
    
    @classmethod
    def mark_as_read(cls, db: Session, notification_id: int, user_id: int) -> bool:
        """Отметить уведомление как прочитанное"""
        notification = db.query(Notification).filter(
            Notification.id == notification_id,
            Notification.user_id == user_id
        ).first()
        
        if notification:
            notification.is_read = True
            return True
        return False
    
    @classmethod
    def mark_all_as_read(cls, db: Session, user_id: int) -> int:
        """Отметить все уведомления пользователя как прочитанные"""
        count = db.query(Notification).filter(
            Notification.user_id == user_id,
            Notification.is_read == False
        ).update({"is_read": True})
        return count


"""
Background Tasks - фоновые задачи приложения

Реализует периодическое выполнение задач:
- Автоматическое обновление статусов рейсов
- Очистка просроченных бронирований
"""

import asyncio
from datetime import datetime, timedelta
from typing import Optional
from contextlib import contextmanager

from app.core.database import SessionLocal
from app.services.flight_service import FlightService


class BackgroundTaskManager:
    """Менеджер фоновых задач"""
    
    _instance: Optional['BackgroundTaskManager'] = None
    _task: Optional[asyncio.Task] = None
    _running: bool = False
    
    # Интервал проверки статусов (в секундах)
    STATUS_UPDATE_INTERVAL = 60  # Каждую минуту
    
    @classmethod
    def get_instance(cls) -> 'BackgroundTaskManager':
        """Получить единственный экземпляр менеджера (Singleton)"""
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance
    
    @contextmanager
    def get_db(self):
        """Контекстный менеджер для получения сессии БД"""
        db = SessionLocal()
        try:
            yield db
        finally:
            db.close()
    
    async def update_flight_statuses(self):
        """Обновить статусы всех рейсов"""
        try:
            with self.get_db() as db:
                updated = FlightService.process_automatic_status_updates(db)
                # Пишем короткий heartbeat, чтобы было видно, что автоматика работает
                print(f"[BackgroundTask] {datetime.utcnow().strftime('%H:%M:%S')} - Status check: updated {len(updated)} transitions")
        except Exception as e:
            print(f"[BackgroundTask] Error updating statuses: {e}")
    
    async def cleanup_expired_bookings(self):
        """Очистить просроченные бронирования"""
        from app.models import Booking, Seat, SeatStatus
        from datetime import timedelta
        
        try:
            with self.get_db() as db:
                # Находим просроченные бронирования (CREATED более 10 минут назад)
                expiry_threshold = datetime.utcnow() - timedelta(minutes=10)
                
                expired_bookings = db.query(Booking).filter(
                    Booking.status == "CREATED",
                    Booking.created_at < expiry_threshold
                ).all()
                
                for booking in expired_bookings:
                    print(f"[BackgroundTask] Cancelling expired booking ID={booking.id}")
                    booking.status = "CANCELLED"
                    
                    # Освобождаем места
                    for ticket in booking.tickets:
                        if ticket.seat:
                            ticket.seat.status = SeatStatus.AVAILABLE
                            ticket.seat.held_until = None
                
                if expired_bookings:
                    db.commit()
                    print(f"[BackgroundTask] Cancelled {len(expired_bookings)} expired bookings")
                    
        except Exception as e:
            print(f"[BackgroundTask] Error cleaning bookings: {e}")

    async def send_checkin_reminders(self):
        """Отправить напоминания о check-in (за 24 часа до вылета и позже, но не позднее чем за 1 час)"""
        from app.models import Flight, FlightStatus, Booking, Notification

        try:
            with self.get_db() as db:
                now = datetime.now()
                # Подбираем рейсы в окне 24ч..1ч до вылета
                flights = db.query(Flight).filter(
                    Flight.status.in_([FlightStatus.SCHEDULED, FlightStatus.DELAYED]),
                ).all()

                sent_count = 0
                for flight in flights:
                    time_until = flight.departure_time - now
                    if time_until > timedelta(hours=24) or time_until < timedelta(hours=1):
                        continue

                    # Только оплаченные бронирования
                    bookings = db.query(Booking).filter(
                        Booking.flight_id == flight.id,
                        Booking.status.in_(["CONFIRMED", "PAID"])
                    ).all()

                    for booking in bookings:
                        user_id = booking.user_id
                        # Дедуп: одно уведомление на (user_id, flight_id)
                        exists = db.query(Notification).filter(
                            Notification.user_id == user_id,
                            Notification.flight_id == flight.id,
                            Notification.title == "не забудьте сделать чек ин"
                        ).first()
                        if exists:
                            continue

                        db.add(Notification(
                            user_id=user_id,
                            flight_id=flight.id,
                            title="не забудьте сделать чек ин",
                            content=f"Рейс {flight.flight_number}. Вылет: {flight.departure_time}. Gate: {getattr(flight, 'gate', '') or ''}"
                        ))
                        sent_count += 1

                if sent_count:
                    db.commit()
                # Не печатаем русские строки в консоль (Windows кодировка), только счетчик
                print(f"[BackgroundTask] Check-in reminders sent: {sent_count}")
        except Exception as e:
            print(f"[BackgroundTask] Error sending check-in reminders: {e}")
    
    async def _run_periodic_tasks(self):
        """Основной цикл выполнения периодических задач"""
        print("[BackgroundTask] Starting periodic tasks loop...")
        
        while self._running:
            try:
                # Обновляем статусы рейсов
                await self.update_flight_statuses()
                
                # Очищаем просроченные бронирования
                await self.cleanup_expired_bookings()

                # Напоминания о check-in
                await self.send_checkin_reminders()
                
            except Exception as e:
                print(f"[BackgroundTask] Error in task loop: {e}")
            
            # Ждём до следующего выполнения
            await asyncio.sleep(self.STATUS_UPDATE_INTERVAL)
        
        print("[BackgroundTask] Periodic tasks stopped")
    
    def start(self):
        """Запустить фоновые задачи"""
        if self._running:
            print("[BackgroundTask] Tasks already running")
            return
        
        self._running = True
        try:
            # В FastAPI startup уже есть запущенный event loop
            loop = asyncio.get_running_loop()
            self._task = loop.create_task(self._run_periodic_tasks())
            print("[BackgroundTask] Background tasks STARTED")
        except RuntimeError:
            # Если event loop ещё не запущен (на всякий случай)
            self._task = asyncio.create_task(self._run_periodic_tasks())
            print("[BackgroundTask] Background tasks STARTED (fallback)")
    
    def stop(self):
        """Остановить фоновые задачи"""
        self._running = False
        if self._task:
            self._task.cancel()
            self._task = None
        print("[BackgroundTask] Background tasks STOPPED")


# Глобальный экземпляр менеджера
background_task_manager = BackgroundTaskManager.get_instance()


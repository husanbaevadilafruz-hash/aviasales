"""
utils.py - Вспомогательные функции

Этот файл содержит переиспользуемые функции для работы с данными.
"""

from app.schemas.schemas import AirportResponse, FlightWithAirportsResponse
from app.models.models import Flight


def create_flight_response(flight: Flight) -> FlightWithAirportsResponse:
    """
    Создаёт ответ с полной информацией о рейсе и аэропортах.
    
    Эта функция используется в нескольких эндпоинтах для единообразного
    формирования ответа с информацией о рейсе.
    """
    return FlightWithAirportsResponse(
        id=flight.id,
        flight_number=flight.flight_number,
        departure_airport=AirportResponse(
            id=flight.departure_airport.id,
            code=flight.departure_airport.code,
            name=flight.departure_airport.name,
            city=flight.departure_airport.city,
            country=flight.departure_airport.country
        ),
        arrival_airport=AirportResponse(
            id=flight.arrival_airport.id,
            code=flight.arrival_airport.code,
            name=flight.arrival_airport.name,
            city=flight.arrival_airport.city,
            country=flight.arrival_airport.country
        ),
        departure_time=flight.departure_time,
        arrival_time=flight.arrival_time,
        airplane_id=flight.airplane_id,
        status=flight.status,
        base_price=flight.base_price,
        gate=(flight.gate or "")
    )


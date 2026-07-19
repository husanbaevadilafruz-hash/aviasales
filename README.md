https://youtu.be/JL38lTASuqg

✈️ Aviasales — Airline Booking & Operations System

A full-stack airline booking platform built as a 96-hour technical exam project, featuring a FastAPI backend and a Flutter mobile application. The system supports both passenger-facing booking flows and staff-facing flight operations management, similar to a real-world airline system (e.g. Turkish Airlines).

🎥 Demo video: Watch on YouTube


📌 Overview

The system supports two user roles:


Passengers — search flights, book seats, pay (mock), check in, and receive live announcements
Staff — manage flights, aircraft, seat maps, bookings, and operational updates



🛠️ Tech Stack

Backend


Python 3.10+, FastAPI
JWT authentication with role-based access control
SQLite / MS SQL Server
REST API with Swagger/OpenAPI docs (/docs)


Mobile


Flutter (Android)
Consumes REST APIs only
Handles loading, error, and empty states



✨ Features

Passenger


Registration and login with JWT-based authentication
Passenger profile (full name, email, phone, passport number, nationality, date of birth) — required before booking
Flight search by origin, destination, and departure date, showing flight number, departure/arrival time, duration, price, available seats, and status
Flight details screen with route, aircraft, schedule, status, gate, and terminal
Interactive seat map showing available/unavailable seats and seat categories (standard / extra legroom)
Multi-passenger booking flow: select flight → add passengers → select or auto-assign seats → create booking
Seat hold for 10 minutes during checkout, with automatic release and race-condition-safe booking to prevent double booking
Booking statuses: CREATED, CONFIRMED, CANCELLED — each with a unique PNR code and per-passenger tickets
Mock payment flow (Card / Apple Pay / Google Pay) with idempotent payment endpoint and PENDING / PAID / FAILED statuses
"My Trips" — upcoming and past bookings with passenger, seat, and flight status details
Online check-in, available from 24 hours to 1 hour before departure, per ticket
Digital boarding pass with passenger name, flight number, seat, gate, boarding time, and QR code payload
Flight announcements: delays, cancellations, gate changes, boarding calls, and general information


Staff / Admin


Airplane model creation and seat map template configuration (rows, seat labels, seat categories) with map preview
Flight management: creation, airplane assignment, schedule/gate/terminal updates, and status transitions (SCHEDULED, BOARDING, DELAYED, CANCELLED, DEPARTED, LANDED)
Announcement publishing linked to specific flights
Booking management: search by PNR, cancellation before departure, and seat reassignment — all respecting seat availability rules



🏗️ Architecture


Business logic separated from API routes
Input validation on all endpoints with a consistent error response format
Seed script for demo airports and flights (seed.py)
Concurrency-safe seat locking to prevent race conditions on booking



📄 Data Model

User, PassengerProfile, Airport, Airplane, Flight, Booking, Ticket, Payment, CheckIn, Announcement


🚀 Getting Started

Backend (FastAPI)

bashcd backend
python -m venv venv

Activate the virtual environment:

bash# Windows
.\venv\Scripts\Activate.ps1

# macOS/Linux
source venv/bin/activate


If you hit an execution policy error on Windows:

powershellSet-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser



Install dependencies and seed the database:

bashpip install -r requirements.txt
python seed.py

Run the server:

bashuvicorn main:app --reload

API docs available at http://localhost:8000/docs

Mobile App (Flutter)

bashcd mobile
flutter pub get
flutter run


Update the backend base URL in the app config to match your local/deployed API.




📎 Notes

This project was built individually as a 96-hour technical assessment, covering the full scope from backend API design and data modeling to mobile UI implementation.

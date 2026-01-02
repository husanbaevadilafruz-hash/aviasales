"""
config.py - Application configuration

This module contains configuration settings for the application.
"""

import os
from typing import Optional

# Database
DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./aviasales.db")

# JWT Settings
SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-change-in-production-12345")
ALGORITHM: str = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES: int = 30 * 24 * 60  # 30 days

# CORS Settings
CORS_ORIGINS: list = ["*"]  # In production, specify exact origins
CORS_ALLOW_CREDENTIALS: bool = True
CORS_ALLOW_METHODS: list = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"]
CORS_ALLOW_HEADERS: list = ["*"]

# Application
APP_TITLE: str = "Airline Booking API"
APP_DESCRIPTION: str = "API для системы бронирования авиабилетов"
APP_VERSION: str = "1.0.0"








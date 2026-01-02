"""
database.py - Database connection and session management

This module handles:
1. SQLite database connection
2. Table creation
3. Database session management
"""

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Database URL - SQLite file
SQLALCHEMY_DATABASE_URL = "sqlite:///./aviasales.db"

# Create database engine
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False}  # Required for SQLite in FastAPI
)

# Session factory for creating database sessions
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for all database models
Base = declarative_base()


def get_db():
    """
    Database session dependency for FastAPI.
    
    Creates a new session, yields it for use, then closes it.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()








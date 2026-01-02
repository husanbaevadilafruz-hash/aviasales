"""
database.py - Подключение к базе данных

Этот файл отвечает за:
1. Подключение к базе данных SQLite
2. Создание всех таблиц (если их ещё нет)
3. Сессию для работы с базой данных

SQLite - это простая база данных, которая хранится в одном файле.
Не нужно устанавливать отдельный сервер базы данных.
"""

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Создаём движок базы данных
# SQLite создаст файл aviasales.db в папке backend, если его ещё нет
SQLALCHEMY_DATABASE_URL = "sqlite:///./aviasales.db"

# create_engine - это "мост" между нашим кодом и базой данных
engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False}  # Нужно для SQLite в FastAPI
)

# SessionLocal - это "фабрика" для создания сессий
# Сессия - это как "разговор" с базой данных
# Каждый запрос к API будет использовать свою сессию
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base - это базовый класс для всех наших моделей (таблиц)
# Все модели будут наследоваться от этого класса
Base = declarative_base()


# Функция для получения сессии базы данных
# Используется в каждом эндпоинте для работы с базой
def get_db():
    """
    Эта функция создаёт новую сессию базы данных,
    отдаёт её для использования, а потом закрывает.
    
    Это как открыть книгу, прочитать страницу, закрыть книгу.
    """
    db = SessionLocal()
    try:
        yield db  # Отдаём сессию
    finally:
        db.close()  # Закрываем сессию в любом случае


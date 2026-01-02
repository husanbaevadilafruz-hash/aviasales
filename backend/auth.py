"""
auth.py - Аутентификация и авторизация

Этот файл отвечает за:
1. Хеширование паролей (безопасное хранение)
2. Создание JWT токенов (пропуск для доступа к API)
3. Проверка токенов (валидация пропуска)
4. Проверка прав доступа (пассажир или сотрудник)

JWT токен - это как пропуск в офис:
- Вы получаете пропуск после входа
- Показываете пропуск при каждом запросе
- Пропуск содержит информацию о вас (email, роль)
"""

from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from database import get_db
from models import User, UserRole

# Секретный ключ для подписи JWT токенов
# В реальном проекте это должно быть в переменных окружения!
SECRET_KEY = "your-secret-key-change-in-production-12345"
ALGORITHM = "HS256"  # Алгоритм шифрования
ACCESS_TOKEN_EXPIRE_MINUTES = 30 * 24 * 60  # 30 дней (для удобства разработки)

# OAuth2PasswordBearer - это схема безопасности для FastAPI
# Она автоматически извлекает токен из заголовка Authorization
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

# CryptContext - для хеширования паролей
# bcrypt - это алгоритм, который превращает пароль в "хеш" (необратимое шифрование)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Проверяет, совпадает ли введённый пароль с хешем в базе.
    
    Это как проверка отпечатка пальца:
    - Мы не храним сам пароль
    - Храним только "отпечаток" (хеш)
    - При входе проверяем, совпадает ли отпечаток
    """
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """
    Превращает пароль в хеш для безопасного хранения.
    
    Это как создание отпечатка пальца из пальца.
    Обратно превратить нельзя (безопасно).
    
    Bcrypt ограничивает длину пароля до 72 байт.
    """
    # Обрезаем пароль до 72 байт, если он длиннее
    password_bytes = password.encode('utf-8')
    if len(password_bytes) > 72:
        password_bytes = password_bytes[:72]
        password = password_bytes.decode('utf-8', errors='ignore')
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """
    Создаёт JWT токен.
    
    JWT токен - это зашифрованная информация о пользователе.
    Внутри токена хранится email и роль пользователя.
    
    Это как пропуск с вашим именем и должностью.
    """
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})  # Время истечения токена
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
) -> User:
    """
    Получает текущего пользователя из JWT токена.
    
    Эта функция вызывается автоматически в каждом эндпоинте,
    где нужна аутентификация.
    
    Это как проверка пропуска на входе в офис.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        # Расшифровываем токен
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")  # "sub" - это стандартное поле для email в JWT
        
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    # Находим пользователя в базе данных
    user = db.query(User).filter(User.email == email).first()
    if user is None:
        raise credentials_exception
    
    return user


def get_current_passenger(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Проверяет, что текущий пользователь - пассажир.
    
    Используется в эндпоинтах, доступных только пассажирам.
    """
    if current_user.role != UserRole.PASSENGER:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions. Passenger role required."
        )
    return current_user


def get_current_staff(
    current_user: User = Depends(get_current_user)
) -> User:
    """
    Проверяет, что текущий пользователь - сотрудник (STAFF).
    
    Эта функция используется в эндпоинтах, доступных ТОЛЬКО сотрудникам.
    
    Как это работает:
    1. Сначала проверяется JWT токен (get_current_user)
    2. Затем проверяется, что роль пользователя == STAFF
    3. Если роль не STAFF - возвращается ошибка 403 (Forbidden)
    
    Это защищает STAFF эндпоинты от доступа пассажиров.
    """
    if current_user.role != UserRole.STAFF:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions. Staff role required."
        )
    return current_user


# Aviasales

ссылка на видео: "https://youtu.be/JL38lTASuqg"

Система бронирования авиабилетов с backend на FastAPI и мобильным приложением на Flutter.

## Установка и запуск

### Backend (FastAPI)

1. Перейдите в папку backend:
```powershell
cd backend
```

2. Создайте виртуальное окружение:
```powershell
python -m venv venv
```

3. Активируйте виртуальное окружение:
```powershell
.\venv\Scripts\Activate.ps1
```

Если появилась ошибка про политику выполнения:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

4. Установите зависимости:
```powershell
pip install -r requirements.txt
```

5. Создайте тестовые данные:
```powershell
python seed.py
```

6. Запустите сервер:
```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Сервер будет доступен на http://127.0.0.1:8000

### Mobile (Flutter)

1. Перейдите в папку mobile:
```powershell
cd mobile
```

2. Установите зависимости:
```powershell
flutter pub get
```

3. Запустите приложение:
```powershell
flutter run
```

## Тестовые учетные данные

**Пассажир:**
- Email: `passenger@gmail.com`
- Пароль: `12345678`

**Сотрудник:**
- Email: `staff1@airline.com`
- Пароль: `staff123`

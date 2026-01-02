# Редирект на правильный main.py
# Этот файл существует для совместимости с командой "uvicorn main:app"
# Правильный файл находится в backend/app/main.py

from app.main import app

# Теперь можно запускать как:
# uvicorn main:app --reload
# или
# uvicorn app.main:app --reload

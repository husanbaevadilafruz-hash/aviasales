# Backend Structure

## New Organized Structure

```
backend/
├── app/                          # Main application package
│   ├── __init__.py              # Package initialization
│   ├── main.py                  # FastAPI app and all endpoints
│   │
│   ├── core/                    # Core functionality
│   │   ├── __init__.py
│   │   ├── database.py         # Database connection & session
│   │   ├── auth.py             # Authentication & authorization
│   │   └── config.py           # Configuration settings
│   │
│   ├── models/                  # Database models
│   │   ├── __init__.py
│   │   └── models.py            # All SQLAlchemy models
│   │
│   ├── schemas/                 # Pydantic schemas
│   │   ├── __init__.py
│   │   └── schemas.py           # Request/Response schemas
│   │
│   ├── utils/                   # Utility functions
│   │   ├── __init__.py
│   │   └── utils.py             # Helper functions
│   │
│   ├── services/                # Business logic (future)
│   │   └── __init__.py
│   │
│   └── api/                     # API routes (future organization)
│       └── routes/
│           └── __init__.py
│
├── run.py                       # Entry point to run server
├── seed.py                      # Database seeding script
├── requirements.txt             # Dependencies
├── README.md                    # Documentation
└── aviasales.db                 # SQLite database file
```

## How to Run

### Option 1: Using run.py
```bash
cd backend
python run.py
```

### Option 2: Using uvicorn directly
```bash
cd backend
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

## Import Structure

All imports now use the `app.` prefix:

```python
# Old way (still works for backward compatibility)
from database import get_db
from models import User
from schemas import UserRegister

# New way (recommended)
from app.core.database import get_db
from app.models import User
from app.schemas import UserRegister
```

## Benefits

1. **Clear Separation**: Each component has its own folder
2. **Scalability**: Easy to add new modules (services, routes)
3. **Maintainability**: Easy to find and modify code
4. **Professional Structure**: Follows Python best practices
5. **Future-proof**: Ready for adding more features

## Migration Notes

- Old files (`main.py`, `models.py`, etc.) are kept for reference
- New structure is in `app/` folder
- All imports updated to use new structure
- Backward compatible - old imports still work









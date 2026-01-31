# Sentinel Backend API

Серверная часть приложения Sentinel - интеллектуального тайм-менеджера.

## Технологический стек

- **FastAPI** - современный async веб-фреймворк
- **SQLAlchemy 2.0** - ORM с async поддержкой
- **PostgreSQL 14+** - реляционная база данных
- **Alembic** - миграции базы данных
- **Pydantic v2** - валидация данных
- **JWT** - аутентификация

## Структура проекта

```
sentinel-backend/
├── app/
│   ├── api/                    # API endpoints
│   │   ├── v1/
│   │   │   ├── auth.py        # Аутентификация
│   │   │   └── events.py      # События
│   │   └── dependencies.py    # FastAPI dependencies
│   ├── core/                   # Бизнес-логика
│   │   ├── schemas/           # Pydantic схемы
│   │   ├── config.py          # Настройки
│   │   └── security.py        # JWT и хеширование
│   └── infrastructure/         # Инфраструктура
│       └── database/
│           ├── models/        # SQLAlchemy модели
│           ├── repositories/  # Репозитории
│           └── base.py        # Подключение к БД
├── alembic/                    # Миграции БД
├── requirements.txt
├── docker-compose.yml
├── Dockerfile
└── .env.example
```

## Быстрый старт с Docker

1. Скопируйте `.env.example` в `.env`:
```bash
cp .env.example .env
```

2. Запустите приложение:
```bash
docker-compose up --build
```

3. API будет доступен по адресу: http://localhost:8000
4. Документация Swagger: http://localhost:8000/docs
5. Документация ReDoc: http://localhost:8000/redoc

## Локальная разработка (без Docker)

### Требования

- Python 3.11+
- PostgreSQL 14+

### Установка

1. Создайте виртуальное окружение:
```bash
python3.11 -m venv venv
source venv/bin/activate  # На Windows: venv\Scripts\activate
```

2. Установите зависимости:
```bash
pip install -r requirements.txt
```

3. Настройте переменные окружения в `.env`:
```env
DATABASE_URL=postgresql+asyncpg://user:password@localhost:5432/sentinel_db
DATABASE_SYNC_URL=postgresql://user:password@localhost:5432/sentinel_db
SECRET_KEY=your-secret-key-here
```

4. Создайте базу данных:
```bash
createdb sentinel_db
```

5. Примените миграции:
```bash
alembic upgrade head
```

6. Запустите сервер:
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## API Endpoints

### Аутентификация

- `POST /api/v1/auth/register` - Регистрация пользователя
- `POST /api/v1/auth/login` - Вход и получение JWT токена

### События

- `POST /api/v1/events` - Создать событие
- `GET /api/v1/events` - Получить список событий
- `GET /api/v1/events/{id}` - Получить событие по ID
- `PATCH /api/v1/events/{id}` - Обновить событие
- `DELETE /api/v1/events/{id}` - Удалить событие

## Миграции базы данных

Создать новую миграцию:
```bash
alembic revision --autogenerate -m "description"
```

Применить миграции:
```bash
alembic upgrade head
```

Откатить миграцию:
```bash
alembic downgrade -1
```

## Разработка

### Создание новой миграции

После изменения моделей в `app/infrastructure/database/models/`:

```bash
alembic revision --autogenerate -m "add new field"
alembic upgrade head
```

### Тестирование API

Используйте Swagger UI: http://localhost:8000/docs

Или curl:
```bash
# Регистрация
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'

# Вход
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'

# Создание события (с токеном)
curl -X POST http://localhost:8000/api/v1/events \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "title":"Встреча",
    "start_at":"2024-01-20T10:00:00Z",
    "end_at":"2024-01-20T11:00:00Z",
    "type":"event"
  }'
```

## Лицензия

Курсовой проект НИУ ВШЭ
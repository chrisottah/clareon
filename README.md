# Clareon — AI Meeting Intelligence

## Phase 1: Project Foundation

### Prerequisites
- Docker + Docker Compose
- Flutter SDK 3.x
- Python 3.11+

---

## Backend Setup

### 1. Copy environment file
```bash
cp .env.example .env
# Edit .env with your values
```

### 2. Start all services with Docker
```bash
docker-compose up --build
```

This starts:
- **PostgreSQL** on port 5432
- **Redis** on port 6379
- **FastAPI** on port 8000

### 3. Verify everything is running
```bash
# Health check
curl http://localhost:8000/api/v1/health

# API docs
open http://localhost:8000/docs
```

Expected response:
```json
{
  "status": "ok",
  "api": "ok",
  "database": "ok",
  "redis": "ok"
}
```

---

## Flutter App Setup

### 1. Install dependencies
```bash
cd mobile
flutter pub get
```

### 2. Run on emulator/device
```bash
# Android emulator (uses 10.0.2.2 to reach host)
flutter run

# Real device — update AppConfig.baseUrl first
flutter run --dart-define=BASE_URL=http://YOUR_LOCAL_IP:8000/api/v1
```

---

## Project Structure

```
clareon/
├── .env.example              # Environment template
├── docker-compose.yml        # All services
│
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── alembic.ini
│   └── app/
│       ├── main.py           # FastAPI entry point
│       ├── core/
│       │   └── config.py     # Settings
│       ├── db/
│       │   └── session.py    # DB engine + session
│       ├── api/v1/
│       │   ├── router.py     # Route registration
│       │   └── endpoints/
│       │       └── health.py # Health check
│       ├── models/           # SQLAlchemy models (Phase 2+)
│       ├── schemas/          # Pydantic schemas (Phase 2+)
│       └── services/         # Business logic (Phase 2+)
│
└── mobile/
    ├── pubspec.yaml
    └── lib/
        ├── main.dart
        ├── core/
        │   ├── config/       # AppConfig
        │   ├── router/       # GoRouter
        │   └── theme/        # AppTheme (dark/light)
        └── features/
            ├── auth/         # Phase 2
            ├── meetings/     # Phase 4
            ├── recording/    # Phase 3
            ├── processing/   # Phase 5+
            └── export/       # Phase 10
```

---

## Phase Checklist

- [x] Phase 1 — Foundation
- [ ] Phase 2 — Authentication
- [ ] Phase 3 — Recording
- [ ] Phase 4 — Meeting Management
- [ ] Phase 5 — Background Processing
- [ ] Phase 6 — Transcription
- [ ] Phase 7 — Speaker Intelligence
- [ ] Phase 8 — AI Meeting Intelligence
- [ ] Phase 9 — Results UI
- [ ] Phase 10 — Export & Sharing
- [ ] Phase 11 — Notifications & Polish

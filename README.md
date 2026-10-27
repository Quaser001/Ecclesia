# CalFit

Production-oriented repository structure for CalFit.

## Structure
* `apps/mobile/` - Flutter + Dart mobile application (Android target)
* `apps/api/` - Python 3.12 + FastAPI backend managed by `uv`
* `docs/` - Project documentation
* `agents.md` - Core development & engineering rules

## Getting Started

### API Backend
1. Go to `apps/api`
2. Run virtual environment: `uv sync`
3. Run tests: `uv run pytest`
4. Start dev server: `uv run uvicorn src.main:app --reload`

### Mobile App
1. Go to `apps/mobile`
2. Run dependencies sync: `flutter pub get`
3. Run tests: `flutter test`

# SDE: cross-cutting

- **Confirmed by the founder** on 2026-10-28. What is built: see `calfit-mvp.md`.
- **Production hardening (2026-10-29):** see `production-hardening.md`. Tests: backend 504 (pytest), app 63 (flutter test), `flutter analyze` clean.
- **Run tools from `apps/api/.venv`** (matches `uv.lock`), not the stale root `.venv`.

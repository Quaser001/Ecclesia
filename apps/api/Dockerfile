# CalFit API — Cloud Run image.
#
# Keep this minimal and reproducible. uv locks dependencies in uv.lock; we
# copy the lockfile into the build so Cloud Run gets exactly what the dev
# box ran. Multi-stage keeps the runtime layer small.

############################
# 1. Build layer
############################
FROM python:3.12-slim AS build

ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON_DOWNLOADS=never \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# uv binary — pin the version that wrote uv.lock (its header says revision 3).
# An older uv can't read a newer lock format and `--frozen` fails the build.
# Bump this together with the uv you lock with.
COPY --from=ghcr.io/astral-sh/uv:0.11.18 /uv /usr/local/bin/uv

WORKDIR /app

# Install production deps first; the layer cache survives source edits.
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

# Now the source. The app runs from /app/src (CMD imports src.main), so the
# project is never installed as a package and no build backend is fetched.
# From data/ only the food product database ships; data/calfit.db is the
# local dev store of real profiles and scans.
COPY src ./src
COPY data/food.db ./data/food.db

############################
# 2. Runtime layer
############################
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app
# Non-root user — Cloud Run allows it and it is one less footgun.
RUN useradd --create-home --uid 1001 calfit && chown -R calfit:calfit /app
USER calfit

COPY --from=build --chown=calfit:calfit /app /app

# Cloud Run injects $PORT. Default to 8080 for local docker runs.
ENV PORT=8080
EXPOSE 8080

# Single async worker. It serves up to Cloud Run's --concurrency requests at
# once (20, docs/DEPLOY_CLOUD_RUN.md), each holding at most one 10 MB photo,
# so 1 GiB of memory leaves room. Cloud Run scales out past that.
CMD ["sh", "-c", "uvicorn src.main:app --host 0.0.0.0 --port ${PORT} --workers 1 --proxy-headers --no-access-log"]

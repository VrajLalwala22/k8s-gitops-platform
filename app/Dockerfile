# syntax=docker/dockerfile:1

# ---- build stage: install dependencies into an isolated virtualenv ----
FROM python:3.12-slim AS build
WORKDIR /build
RUN python -m venv /venv
COPY requirements.txt .
RUN /venv/bin/pip install --no-cache-dir -r requirements.txt \
 && /venv/bin/pip uninstall -y pip

# ---- runtime stage: slim image, non-root user, no build tooling ----
FROM python:3.12-slim
ENV PATH="/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app/src
# The service never installs packages at runtime, so ship without pip
# (smaller attack surface, and no pip CVEs in the image scan).
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin app \
 && python -m pip uninstall -y pip
COPY --from=build /venv /venv
COPY src /app/src
WORKDIR /app
USER 10001
EXPOSE 8000
CMD ["uvicorn", "tasks_api.main:app", "--host", "0.0.0.0", "--port", "8000"]

FROM python:3.14-slim-trixie AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /src

COPY pyproject.toml poetry.lock ./

RUN python -m venv /tools \
    && /tools/bin/pip install poetry==2.5.1 poetry-plugin-export==1.10.1 \
    && /tools/bin/poetry export --without-hashes --only main -f requirements.txt > requirements.txt \
    && python -m venv /opt/venv \
    && /opt/venv/bin/pip install -r requirements.txt



FROM python:3.14-slim-trixie

ARG APP_VERSION="development version"

LABEL org.opencontainers.image.title="example-web-app" \
      org.opencontainers.image.description="Hello world Streamlit application" \
      org.opencontainers.image.source="https://github.com/kakarukeys/example-web-app" \
      org.opencontainers.image.version="${APP_VERSION}"

ENV HOME="/tmp" \
    PATH="/opt/venv/bin:$PATH" \
    VIRTUAL_ENV="/opt/venv" \
    APP_VERSION="${APP_VERSION}" \
    STREAMLIT_BROWSER_GATHER_USAGE_STATS="false" \
    PYTHONUNBUFFERED="1"

RUN useradd --no-create-home --user-group --uid 1000 --shell /usr/sbin/nologin app

COPY --from=builder /opt/venv /opt/venv
COPY app/ /app/

WORKDIR /app

USER app

EXPOSE 8501

CMD ["streamlit", "run", "app.py", "--server.port", "8501", "--server.address", "0.0.0.0"]

# ── Stage 1: Build dependencies ─────────────────────────────────────────────
FROM python:3.13-slim-trixie AS builder

WORKDIR /build

# Skip cryptography rust compilation (required for armv7 builds)
ENV CRYPTOGRAPHY_DONT_BUILD_RUST=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        gcc \
        binutils \
        libffi-dev \
        libssl-dev \
        libxml2-dev \
        libxslt1-dev \
        libxslt-dev \
        libjpeg62-turbo-dev \
        libopenblas-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy source and install into venv
COPY . /build/
COPY extra_requirements.txt /build/

RUN python -m venv /opt/venv \
    && . /opt/venv/bin/activate \
    && pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -e /build \
    && pip install --no-cache-dir -r /build/extra_requirements.txt

# ── Stage 2: Runtime image ───────────────────────────────────────────────────
FROM python:3.13-slim-trixie

ARG TENTACLES_URL_TAG=""
ARG VERSION=""
ENV TENTACLES_URL_TAG=$TENTACLES_URL_TAG
ENV VERSION=$VERSION

LABEL maintainer="Drakkar-Software" \
      version="${VERSION}" \
      description="OctoBot - Cryptocurrency trading bot"

WORKDIR /octobot

COPY --from=builder /opt/venv /opt/venv
COPY octobot/config /octobot/octobot/config
COPY start.py /octobot/
COPY docker/* /octobot/

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        libxslt-dev \
        libxcb-xinput0 \
        libjpeg62-turbo-dev \
        zlib1g-dev \
        libblas-dev \
        liblapack-dev \
        libopenblas-dev \
        libopenjp2-7 \
        libtiff-dev \
    && rm -rf /var/lib/apt/lists/* \
    && chmod +x docker-entrypoint.sh \
    && chmod +x tunnel.sh

ENV PATH="/opt/venv/bin:$PATH"

# Persistent storage paths (configure Railway Volumes for these paths in Railway dashboard):
# /octobot/backtesting
# /octobot/logs
# /octobot/tentacles
# /octobot/user

# Node API (OctoBot node mode)
EXPOSE 8000
# Standalone web UI (5001) + up to 10 spawned process-bot web interfaces (5001-5010)
EXPOSE 5001-5010

HEALTHCHECK --interval=15s --timeout=10s --retries=5 \
    CMD curl -sS http://127.0.0.1:8000 || exit 1

ENTRYPOINT ["./docker-entrypoint.sh"]

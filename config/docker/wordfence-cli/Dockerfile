FROM python:3.11-slim-bookworm AS base

RUN apt-get update \
    && apt-get install --yes --no-install-recommends libpcre3 \
    && rm -rf /var/lib/apt/lists/*

FROM base AS build
WORKDIR /app

COPY wordfence ./wordfence
COPY pyproject.toml ./pyproject.toml

RUN pip install --no-cache-dir 'build~=0.10' \
    && python -m build --wheel \
    && python -m venv /venv \
    && /venv/bin/pip install --no-cache-dir dist/wordfence-*.whl

FROM base AS final
WORKDIR /venv

COPY --from=build /venv /venv

ENV VIRTUAL_ENV=/venv
ENV PATH="/venv/bin:${PATH}"

ENTRYPOINT ["wordfence"]

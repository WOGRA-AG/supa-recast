# From: https://github.com/michael0liver/python-poetry-docker-example/blob/master/docker/Dockerfile
FROM gitlab-registry.wogra.com/developer/images/python:3.10.7-slim as python-base
#FROM python:3.9.10-slim AS python-base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1 \
    PYSETUP_PATH="/opt/pysetup" \
    VENV_PATH="/opt/pysetup/.venv" \
    PROJECT_DIR="/app" \
    POETRY_VERSION=1.2.0 \
    OPENAPI_GENERATOR_CLI_VERSION=5.4.0

ENV PATH="$POETRY_HOME/bin:$VENV_PATH/bin:$JAVA_HOME/bin:$PATH"
ENV PYTHONPATH="$PROJECT_DIR:$PROJECT_DIR/src:$PROJECT_DIR/src/build$PYTHONPATH"

FROM python-base as builder-base
ARG IMAGE_TAG
ENV IMG_TAG=$IMAGE_TAG
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        build-essential curl \
    && apt-get autoclean

RUN curl -sSL https://install.python-poetry.org | python3 -

WORKDIR $PYSETUP_PATH
COPY README.md pyproject.toml poetry.lock ./
COPY supa_recast ./supa_recast
RUN ls supa_recast
RUN --mount=type=cache,target=/root/.cache \
    poetry install --only main --no-interaction --no-ansi

# 'development' stage installs all dev deps and can be used to develop code.
# For example using docker-compose to mount local volume under /app
FROM python-base as development

COPY --from=builder-base $POETRY_HOME $POETRY_HOME
COPY --from=builder-base $PYSETUP_PATH $PYSETUP_PATH

COPY ./docker-entrypoint.sh .
RUN chmod +x /docker-entrypoint.sh

WORKDIR $PYSETUP_PATH
RUN --mount=type=cache,target=/root/.cache \
    poetry install --with dev --no-interaction --no-ansi

WORKDIR $PROJECT_DIR
COPY . .

FROM development AS lint
RUN black --config ./pyproject.toml --check supa_recast tests
RUN isort --settings-path ./pyproject.toml --check-only supa_recast tests
CMD ["tail", "-f", "/dev/null"]


# 'test' stage runs our unit tests with pytest and coverage.
FROM development AS test
RUN coverage run --rcfile ./pyproject.toml -m pytest ./tests
RUN coverage report -m --fail-under 95

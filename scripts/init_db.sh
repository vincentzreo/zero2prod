#! /usr/bin/env bash

set -x
set -eo pipefail

if ! [ -x "$(command -v sqlx)" ]; then
    >&2 echo "Error: sqlx is not installed."
    >&2 echo "Please install sqlx by running: cargo install sqlx-cli --no-default-features --features rustls,postgres"
    exit 1
fi

# check if a custom user has been set, otherwise default to postgres
DB_PORT="${POSTGRES_PORT:=5431}"
SUPERUSER="${SUPERUSER:=postgres}"
SUPERUSER_PWD="${SUPERUSER_PWD:=password}"
APP_USER="${APP_USER:=app}"
APP_USER_PWD="${APP_USER_PWD:=secret}"
APP_DB_NAME="${APP_DB_NAME:=newsletter}"

# ALLow to skip Docker if a dockerized postgres database is already running

if [[ -z "${SKIP_DOCKER}" ]]
then
    # launch postgres using Docker
    CONTAINER_NAME="postgres"

    docker run \
        --env POSTGRES_USER=${SUPERUSER} \
        --env POSTGRES_PASSWORD=${SUPERUSER_PWD} \
        --env POSTGRES_DB=${SUPERUSER} \
        --health-cmd="pg_isready -U ${SUPERUSER} || exit 1" \
        --health-interval=1s \
        --health-timeout=5s \
        --health-retries=5 \
        --publish "${DB_PORT}":5432 \
        --detach \
        --name ${CONTAINER_NAME} \
        postgres:14 -N 1000

    # wait for the postgres container to be ready
    until [ \
        "$(docker inspect -f '{{.State.Health.Status}}' ${CONTAINER_NAME})" == "healthy" \
    ]; do
        >&2 echo "Waiting for postgres to be ready..."
        sleep 1
    done

    >&2 echo "Postgres is up and running on port ${DB_PORT}!"

    # Create the application user
    CREATE_QUERY="CREATE USER ${APP_USER} WITH PASSWORD '${APP_USER_PWD}';"
    docker exec -it ${CONTAINER_NAME} psql -U "${SUPERUSER}" -c "${CREATE_QUERY}"

    # Grant create db privileges to the app user
    GRANT_QUERY="ALTER USER ${APP_USER} CREATEDB;"
    docker exec -it ${CONTAINER_NAME} psql -U "${SUPERUSER}" -c "${GRANT_QUERY}"
fi

DATABASE_URL="postgresql://${APP_USER}:${APP_USER_PWD}@localhost:${DB_PORT}/${APP_DB_NAME}"
export DATABASE_URL
sqlx database create
sqlx migrate run

>&2 echo "Postgres has been migrated and is ready to use!"
#! /usr/bin/env bash

set -x
set -eo pipefail

RUNNING_CONTAINER=$(docker ps --filter "name=redis" --format "{{.ID}}")
if [[ -n "${RUNNING_CONTAINER}" ]]; then
    echo >&2 "Redis is already running. kill it with"
    echo >&2 "docker kill ${RUNNING_CONTAINER}"
    exit 1
fi

docker run \
    --detach \
    --name "redis_$(date '+%s')" \
    --publish 6379:6379 \
    redis:7

>&2 echo "Redis is up and running on port 6379!"
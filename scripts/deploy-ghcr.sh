#!/usr/bin/env bash

set -euo pipefail

: "${DEPLOY_PATH:?}"
: "${COMPOSE_SERVICE:?}"
: "${APP_IMAGE_REF:?}"
: "${APP_VERSION:?}"
: "${GHCR_USERNAME:?}"

test -f "$DEPLOY_PATH/.env"
test -f "$DEPLOY_PATH/docker-compose.yml"

docker_config="$(mktemp -d "$DEPLOY_PATH/.docker-config.XXXXXX")"
cleanup() {
  rm -f -- "$docker_config/config.json"
  rmdir -- "$docker_config" 2>/dev/null || true
}
trap cleanup EXIT

IFS= read -r ghcr_token
printf '%s' "$ghcr_token" | \
  DOCKER_CONFIG="$docker_config" \
  docker login ghcr.io --username "$GHCR_USERNAME" --password-stdin
unset ghcr_token

compose() {
  APP_IMAGE_REF="$APP_IMAGE_REF" \
  APP_VERSION="$APP_VERSION" \
  APP_ENV_FILE="$DEPLOY_PATH/.env" \
  DOCKER_CONFIG="$docker_config" \
    docker compose \
      --project-directory "$DEPLOY_PATH" \
      --env-file "$DEPLOY_PATH/.env" \
      -f "$DEPLOY_PATH/docker-compose.yml" \
      "$@"
}

compose pull "$COMPOSE_SERVICE"
compose up -d --no-build --remove-orphans --wait --wait-timeout 120
compose ps
docker image prune --force --filter 'until=168h'

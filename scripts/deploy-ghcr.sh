#!/usr/bin/env bash

set -euo pipefail

: "${DEPLOY_PATH:?}"
: "${COMPOSE_SERVICE:?}"
: "${APP_IMAGE_REF:?}"
: "${GHCR_USERNAME:?}"

env_file="$DEPLOY_PATH/.env"
compose_file="$DEPLOY_PATH/docker-compose.yml"

[[ -f "$env_file" ]] || {
  printf 'Missing deployment environment file: %s\n' "$env_file" >&2
  exit 1
}
[[ -f "$compose_file" ]] || {
  printf 'Missing Compose file: %s\n' "$compose_file" >&2
  exit 1
}

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
  DOCKER_CONFIG="$docker_config" \
    docker compose \
      --project-directory "$DEPLOY_PATH" \
      --env-file "$env_file" \
      -f "$compose_file" \
      "$@"
}

compose config --quiet
compose pull "$COMPOSE_SERVICE"
compose up -d --no-build --wait --wait-timeout 120 "$COMPOSE_SERVICE"
compose ps "$COMPOSE_SERVICE"

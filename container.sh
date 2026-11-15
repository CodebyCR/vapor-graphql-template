#!/usr/bin/env bash
#
# Builds and runs the GraphQL Todo server with Apple's `container` CLI.
#
#   ./container.sh [start]   build the image if needed and start the container
#   ./container.sh rebuild   rebuild the image without cache, then start
#   ./container.sh stop      stop and remove the container
#   ./container.sh logs      follow the container log
#   ./container.sh status    show whether the container is running
#
# Environment variables:
#   PORT   host port to publish (default 8080)
#   DEV    set to 1 to run in development mode, which serves GraphiQL at /
#          (the default production mode only serves POST/GET /graphql)

set -euo pipefail

cd "$(dirname "$0")"

IMAGE="vapor-graphql-template"
NAME="vapor-graphql-template"
PORT="${PORT:-8080}"
APP_ENV="production"
[[ "${DEV:-0}" == "1" ]] && APP_ENV="development"

if ! command -v container >/dev/null 2>&1; then
    echo "error: Apple's 'container' CLI is not installed. Install it with: brew install container" >&2
    exit 1
fi

ensure_system() {
    if ! container system status >/dev/null 2>&1; then
        echo "Starting the container system service..."
        container system start
    fi
}

build() {
    echo "Building image '$IMAGE' (the first build downloads Swift and compiles all dependencies)..."
    container build --tag "$IMAGE" "$@" .
}

remove_container() {
    # Ignore errors: the container may simply not exist.
    container stop "$NAME" >/dev/null 2>&1 || true
    container delete "$NAME" >/dev/null 2>&1 || true
}

start() {
    ensure_system
    if [[ "${1:-}" == "--no-cache" ]] || ! container image inspect "$IMAGE" >/dev/null 2>&1; then
        build ${1:+"$1"}
    fi

    remove_container
    echo "Starting container '$NAME' in $APP_ENV mode..."
    container run --detach --name "$NAME" --publish "127.0.0.1:${PORT}:8080" \
        "$IMAGE" serve --env "$APP_ENV" --hostname 0.0.0.0 --port 8080

    echo "Waiting for the server..."
    for _ in $(seq 1 30); do
        if curl -fs -o /dev/null -X POST "http://127.0.0.1:${PORT}/graphql" \
            -H 'Content-Type: application/json' -d '{"query":"{ __typename }"}'; then
            echo "GraphQL endpoint: http://127.0.0.1:${PORT}/graphql"
            [[ "$APP_ENV" == "development" ]] && echo "GraphiQL:         http://127.0.0.1:${PORT}/"
            echo "Logs: ./container.sh logs    Stop: ./container.sh stop"
            return 0
        fi
        sleep 1
    done

    echo "error: the server did not answer within 30 seconds. Last log lines:" >&2
    container logs "$NAME" 2>&1 | tail -20 >&2 || true
    exit 1
}

case "${1:-start}" in
    start)   start ;;
    rebuild) start --no-cache ;;
    stop)    remove_container; echo "Stopped." ;;
    logs)    container logs --follow "$NAME" ;;
    status)  container list --all | grep -E "^ID|$NAME" || echo "Container '$NAME' does not exist." ;;
    *)       sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

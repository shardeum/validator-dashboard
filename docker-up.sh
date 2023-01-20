#!/usr/bin/env bash

if ! command -v docker-compose >/dev/null 2>&1; then
    if ! command -v docker >/dev/null 2>&1 ; then
        echo >&2 "docker or docker-compose command not found. Aborting."
        exit 1
    fi
    if ! docker --help | grep -q "compose"; then
        echo >&2 "docker compose subcommand not found. Aborting."
        exit 1
    fi
    echo "docker compose subcommand found, creating function"
    docker-compose() {
        if ! docker compose "$@"; then
            sudo docker compose "$@"
        fi
    }
else
    echo "docker-compose command found, creating function"
    docker-compose() {
        if ! docker-compose "$@"; then
            sudo docker-compose "$@"
        fi
    }
fi

docker-compose -f docker-compose.yml up -d


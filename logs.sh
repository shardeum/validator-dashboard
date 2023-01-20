#!/usr/bin/env bash

if ! command -v docker >/dev/null 2>&1 ; then
    echo >&2 "docker command not found. Aborting."
    exit 1
fi

if ! docker "$@" >/dev/null 2>&1 ; then
    echo "docker command requires sudo, creating function"
    docker() {
        sudo docker "$@"
    }
else
    echo "docker command found and works without sudo"
fi

docker logs -f shardeum-dashboard
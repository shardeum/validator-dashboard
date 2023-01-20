#!/usr/bin/env bash

docker-safe() {
  if ! command -v docker &>/dev/null; then
    echo "docker is not installed on this machine"
    exit 1
  fi

  if ! docker $@; then
    sudo docker $@
  fi
}

docker-safe logs -f shardeum-dashboard
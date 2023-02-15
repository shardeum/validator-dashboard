#!/usr/bin/env bash

docker-compose-safe() {
  if command -v docker-compose &>/dev/null; then
    cmd="docker-compose"
  elif docker --help | grep -q "compose"; then
    cmd="docker compose"
  else
    echo "docker-compose or docker compose is not installed on this machine"
    exit 1
  fi

  if ! $cmd $@; then
    echo "Trying again with sudo..."
    sudo $cmd $@
  fi
}

docker-compose-safe ps | grep -q "Up"
if [ $? -eq 0 ]; then
  echo "Docker Compose project is up"
  docker-compose-safe -f docker-compose.yml down
else
  echo "Docker Compose project is not up"
fi

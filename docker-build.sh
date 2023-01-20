#!/usr/bin/env bash

command -v docker >/dev/null 2>&1 || { echo >&2 "'docker' is required but not installed."; exit 1; }

docker build --no-cache -t test-dashboard -f Dockerfile .
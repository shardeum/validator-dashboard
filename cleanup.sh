#!/usr/bin/env bash

command -v docker >/dev/null 2>&1 || { echo >&2 "'docker' is required but not installed."; exit 1; }

#rm ./output.log

echo "down exiting stack"
./docker-down.sh

echo "delete existing image"
docker rmi $(docker images | grep test-dashboard | awk {' print $3 '})

echo "done."
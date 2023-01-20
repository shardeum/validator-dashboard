#!/usr/bin/env bash

if ! command -v docker >/dev/null 2>&1 ; then
    echo >&2 "docker command not found. Aborting."
    exit 1
fi

if ! docker ps >/dev/null 2>&1 ; then
    echo "docker command requires sudo, creating function"
    function docker(){
        command sudo docker "$@"
    }
else
    echo "docker command works without sudo"
fi

#rm ./output.log

echo "down exiting stack"
./docker-down.sh

echo "delete existing image"
docker rmi $(docker images | grep test-dashboard | awk {' print $3 '})

echo "done."
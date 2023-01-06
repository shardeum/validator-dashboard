#!/usr/bin/env bash

#rm ./output.log

echo "down exiting stack"
./docker-down.sh

echo "delete existing image"
docker rmi $(docker images | grep test-dashboard | awk {' print $3 '})

echo "done."
#!/bin/bash

docker buildx build \
   --build-arg VALIDATOR_BRANCH=dev \
   --build-arg CLI_BRANCH=dev \
   --build-arg GUI_BRANCH=dev \
   --platform linux/amd64,linux/arm64 \
   --push \
   -t github.com/shardeum/validator-dashboard \
   .

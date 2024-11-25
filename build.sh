#!/bin/bash
docker build . --build-arg VALIDATOR_BRANCH=dev --build-arg CLI_BRANCH=dev --build-arg GUI_BRANCH=dev -t validator-dashboard 

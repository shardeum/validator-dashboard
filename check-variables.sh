#!/usr/bin/env bash

# Define the required environment variables in a centralized location
REQUIRED_ENV_VARS_COMMON=(DASHPASS DASHPORT EXT_IP INT_IP SHMEXT SHMINT)

# Additional environment variables for the installer script
REQUIRED_ENV_VARS_INSTALLER=(minNodes baselineNodes nodesPerConsensusGroup)

# Function to check if a single environment variable is set
check_env_var() {
    if [ -z "${!1}" ]; then
        echo "Error: $1 is not set. Please set this variable."
        return 1
    fi
    return 0
}

# Function to check multiple environment variables
check_required_env_vars() {
    for var in "$@"; do
        check_env_var "$var" || exit 1
    done
}


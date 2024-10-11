#!/usr/bin/env bash

# Define the required environment variables in a centralized location
REQUIRED_ENV_VARS_COMMON=(DASHPASS DASHPORT EXT_IP INT_IP SHMEXT SHMINT)

# Additional environment variables for the installer script
REQUIRED_ENV_VARS_INSTALLER=(minNodes baselineNodes nodesPerConsensusGroup)

# Function to check if environment variables are set
check_env_var() {
    var_name=$1
    if [ -z "${!var_name}" ]; then
        echo "Error: $var_name is not set. Please set this variable."
        return 1
    fi
    return 0
}

# Function to validate integers (must be a positive integer)
validate_positive_integer() {
    value=$1
    var_name=$2
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "Error: $var_name ($value) is not a valid integer."
        return 1
    fi
    if [ "$value" -le 0 ]; then
        echo "Error: $var_name ($value) must be greater than 0."
        return 1
    fi
    return 0
}

# Function to validate port numbers (must be between 1025 and 65535)
validate_port() {
    port=$1
    var_name=$2
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "Error: $var_name ($port) is not a valid number."
        return 1
    fi
    if [ "$port" -lt 1025 ] || [ "$port" -gt 65535 ]; then
        echo "Error: $var_name ($port) must be between 1025 and 65535."
        return 1
    fi
    return 0
}

# Function to validate IP addresses
validate_ip() {
    ip=$1
    var_name=$2
    if ! [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "Error: $var_name ($ip) is not a valid IP address."
        return 1
    fi
    # Check if each octet is between 0 and 255
    for octet in $(echo "$ip" | tr "." "\n"); do
        if [ "$octet" -lt 0 ] || [ "$octet" -gt 255 ]; then
            echo "Error: $var_name ($ip) has an invalid octet ($octet). Each octet must be between 0 and 255."
            return 1
        fi
    done
    return 0
}

# Function to validate the dashboard password (DASHPASS)
validate_password() {
    password=$1
    if [[ ${#password} -lt 8 ]]; then
        echo "Error: Password must be at least 8 characters long."
        return 1
    fi
    if ! [[ "$password" =~ [a-z] ]]; then
        echo "Error: Password must contain at least one lowercase letter."
        return 1
    fi
    if ! [[ "$password" =~ [A-Z] ]]; then
        echo "Error: Password must contain at least one uppercase letter."
        return 1
    fi
    if ! [[ "$password" =~ [0-9] ]]; then
        echo "Error: Password must contain at least one number."
        return 1
    fi
    if ! [[ "$password" =~ [\!\@\#\$\%\^\&\*\(\)\_\+\$] ]]; then
        echo "Error: Password must contain at least one special character (!@#$%^&*()_+$)."
        return 1
    fi
    return 0
}

# Function to check required environment variables and validate values
check_required_env_vars() {
    for var in "$@"; do
        check_env_var "$var" || exit 1
    done

    # Validate password
    validate_password "$DASHPASS" || exit 1

    # Validate positive integers (minNodes, baselineNodes, nodesPerConsensusGroup)
    validate_positive_integer "$minNodes" "minNodes" || exit 1
    validate_positive_integer "$baselineNodes" "baselineNodes" || exit 1
    validate_positive_integer "$nodesPerConsensusGroup" "nodesPerConsensusGroup" || exit 1

    # Validate port numbers (DASHPORT, SHMEXT, SHMINT)
    validate_port "$DASHPORT" "DASHPORT" || exit 1
    validate_port "$SHMEXT" "SHMEXT" || exit 1
    validate_port "$SHMINT" "SHMINT" || exit 1

    # Validate IP addresses (EXT_IP, INT_IP)
    validate_ip "$EXT_IP" "EXT_IP" || exit 1
    validate_ip "$INT_IP" "INT_IP" || exit 1
}


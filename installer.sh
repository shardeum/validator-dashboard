#!/usr/bin/env bash
set -e

# Get the environment/OS
environment=$(uname)

# If the script is run as root, set the HOME variable to the user's home directory
if [ "$EUID" -eq 0 ]; then
    ACTUAL_USER=$(logname 2>/dev/null || echo $SUDO_USER)
    HOME="/home/$ACTUAL_USER"
fi

# Function to exit with an error message
exit_with_error() {
    echo "Error: $1"
    exit 1
}

# Check the operating system and get the processor information
case "$environment" in
    Linux)
        processor=$(uname -m)
        ;;
    Darwin)
        processor=$(uname -m)
        ;;
    *MINGW*)
        exit_with_error "$environment (Windows) environment not yet supported. Please use WSL (WSL2 recommended) or a Linux VM. Exiting installer."
        ;;
    *)
        processor="Unknown"
        ;;
esac

# Check for ARM processor or Unknown and exit if true, meaning the installer is not supported by the processor
if [[ "$processor" == *"arm"* || "$processor" == "Unknown" ]]; then
    exit_with_error "$processor not yet supported. Exiting installer."
fi

# Print the detected environment and processor
echo "$environment environment with $processor found."

# Function to check and install dependencies
check_and_install_dependencies() {
    local missing_deps=()
    command -v git >/dev/null 2>&1 || missing_deps+=("git")
    command -v docker >/dev/null 2>&1 || missing_deps+=("docker")
    if ! command -v docker-compose &>/dev/null && ! docker --help | grep -q "compose"; then
        missing_deps+=("docker-compose")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "Installing missing dependencies: ${missing_deps[*]}"
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y "${missing_deps[@]}"
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y "${missing_deps[@]}"
        else
            echo "Unable to install dependencies. Please install them manually."
            exit 1
        fi
    fi

    # Install docker if needed
    if [[ " ${missing_deps[*]} " =~ " docker " ]]; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    fi

    # Install docker-compose if needed
    if [[ " ${missing_deps[*]} " =~ " docker-compose " ]]; then
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

# Run dependency checks and installations in the background
check_and_install_dependencies &

# Function to get IP
get_ip() {
    local ip
    if command -v ip >/dev/null; then
        ip=$(ip addr show $(ip route | awk '/default/ {print $5}') | awk '/inet/ {print $2}' | cut -d/ -f1 | head -n1)
    elif command -v netstat >/dev/null; then
        interface=$(netstat -rn | awk '/default/{print $4}' | head -n1)
        ip=$(ifconfig "$interface" | awk '/inet /{print $2}')
    else
        echo "Error: neither 'ip' nor 'ifconfig' command found. Submit a bug for your OS."
        return 1
    fi
    echo $ip
}

# Function to get external IP
get_external_ip() {
    external_ip=''
    external_ip=$(curl -s https://api.ipify.org)
    if [[ -z "$external_ip" ]]; then
        external_ip=$(curl -s http://checkip.dyndns.org | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
    fi
    if [[ -z "$external_ip" ]]; then
        external_ip=$(curl -s http://ipecho.net/plain)
    fi
    if [[ -z "$external_ip" ]]; then
        external_ip=$(curl -s https://icanhazip.com/)
    fi
    if [[ -z "$external_ip" ]]; then
        external_ip=$(curl --header  "Host: icanhazip.com" -s 104.18.114.97)
    fi
    if [[ -z "$external_ip" ]]; then
        external_ip=$(get_ip)
        if [ $? -eq 0 ]; then
            echo "The IP address is: $IP"
        else
            external_ip="localhost"
        fi
    fi
    echo $external_ip
}

# Function to hash password
hash_password() {
    local input="$1"
    local hashed_password

    if command -v openssl > /dev/null; then
        hashed_password=$(echo -n "$input" | openssl dgst -sha256 -r | awk '{print $1}')
    elif command -v shasum > /dev/null; then
        hashed_password=$(echo -n "$input" | shasum -a 256 | awk '{print $1}')
    elif command -v sha256sum > /dev/null; then
        hashed_password=$(echo -n "$input" | sha256sum | awk '{print $1}')
    else
        return 1
    fi

    echo "$hashed_password"
}

# Check for hashing command
if ! (command -v openssl > /dev/null || command -v shasum > /dev/null || command -v sha256sum > /dev/null); then
    echo "No supported hashing commands found."
    read -p "Would you like to install openssl? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v apt-get > /dev/null; then
            sudo apt-get update && sudo apt-get install -y openssl
        elif command -v yum > /dev/null; then
            sudo yum install -y openssl
        elif command -v dnf > /dev/null; then
            sudo dnf install -y openssl
        else
            echo "Your package manager is not supported. Please install openssl manually."
            exit 1
        fi
    else
        echo "Please install openssl, shasum, or sha256sum and try again."
        exit 1
    fi
fi

# User input section
read -p "During this early stage of Betanet the Shardeum team will be collecting some performance and debugging info from your node to help improve future versions of the software.
This is only temporary and will be discontinued as we get closer to mainnet.
Thanks for running a node and helping to make Shardeum better.

By running this installer, you agree to allow the Shardeum team to collect this data. (Y/n)?: " WARNING_AGREE

WARNING_AGREE=${WARNING_AGREE:-y}
WARNING_AGREE=$(echo "$WARNING_AGREE" | tr '[:upper:]' '[:lower:]')

if [ "$WARNING_AGREE" != "y" ]; then
    echo "Diagnostic data collection agreement not accepted. Exiting installer."
    exit
fi

read -p "What base directory should the node use (default ~/.shardeum): " NODEHOME
NODEHOME=${NODEHOME:-~/.shardeum}

# Ensure NODEHOME starts with / or ~/
if [[ ! $NODEHOME =~ ^(/|~/) ]]; then
    NODEHOME="~/$NODEHOME"
fi

# Validate NODEHOME
while [[ ! $NODEHOME =~ ^[[:alnum:]_.~/-]+$ || $NODEHOME =~ .*[\ ].* ]]; do
    read -p "Error: The directory name contains invalid characters or spaces.
Allowed characters are alphanumeric characters, tilde, forward slash, underscore, period, and hyphen.
Please enter a valid base directory (default ~/.shardeum): " NODEHOME
    NODEHOME=${NODEHOME:-~/.shardeum}
    if [[ ! $NODEHOME =~ ^(/|~/) ]]; then
        NODEHOME="~/$NODEHOME"
    fi
done

echo "The base directory is set to: $NODEHOME"

# Replace leading tilde (~) with the actual home directory path
NODEHOME="${NODEHOME/#\~/$HOME}"

# Set default values
DASHPORT_DEFAULT=8080
EXTERNALIP_DEFAULT=auto
INTERNALIP_DEFAULT=auto
SHMEXT_DEFAULT=9001
SHMINT_DEFAULT=10001
PREVIOUS_PASSWORD=none

# Check for existing installation
CONTAINER_ID=$(docker ps -qf "ancestor=local-dashboard")
if [ -n "$CONTAINER_ID" ]; then
    echo "Existing installation found. Reading settings from container."
    ENV_VARS=$(docker inspect --format="{{range .Config.Env}}{{println .}}{{end}}" "$CONTAINER_ID")
    
    DASHPORT_DEFAULT=$(echo "$ENV_VARS" | grep -oP 'DASHPORT=\K[^ ]+') || DASHPORT_DEFAULT=8080
    EXTERNALIP_DEFAULT=$(echo "$ENV_VARS" | grep -oP 'EXT_IP=\K[^ ]+') || EXTERNALIP_DEFAULT=auto
    INTERNALIP_DEFAULT=$(echo "$ENV_VARS" | grep -oP 'INT_IP=\K[^ ]+') || INTERNALIP_DEFAULT=auto
    SHMEXT_DEFAULT=$(echo "$ENV_VARS" | grep -oP 'SHMEXT=\K[^ ]+') || SHMEXT_DEFAULT=9001
    SHMINT_DEFAULT=$(echo "$ENV_VARS" | grep -oP 'SHMINT=\K[^ ]+') || SHMINT_DEFAULT=10001
    PREVIOUS_PASSWORD=$(echo "$ENV_VARS" | grep -oP 'DASHPASS=\K[^ ]+') || PREVIOUS_PASSWORD=none
elif [ -f "$NODEHOME/.env" ]; then
    echo "Existing .env file found. Reading settings from file."
    ENV_VARS=$(cat "$NODEHOME/.env")
    
    DASHPORT_DEFAULT=$(echo "$ENV_VARS" | grep -oP 'DASHPORT=\K[^ ]+') || DASHPORT_DEFAULT=8080
    EXTERNALIP_DEFAULT=$(echo "$ENV_VARS" | grep -oP 'EXT_IP=\K[^ ]+') || EXTERNALIP_DEFAULT=auto
    INTERNALIP_DEFAULT=$(echo "$ENV_VARS" | grep -oP 'INT_IP=\K[^ ]+') || INTERNALIP_DEFAULT=auto
    SHMEXT_DEFAULT=$(echo "$ENV_VARS" | grep -oP 'SHMEXT=\K[^ ]+') || SHMEXT_DEFAULT=9001
    SHMINT_DEFAULT=$(echo "$ENV_VARS" | grep -oP 'SHMINT=\K[^ ]+') || SHMINT_DEFAULT=10001
    PREVIOUS_PASSWORD=$(echo "$ENV_VARS" | grep -oP 'DASHPASS=\K[^ ]+') || PREVIOUS_PASSWORD=none
fi

read -p "Do you want to run the web based Dashboard? (Y/n): " RUNDASHBOARD
RUNDASHBOARD=${RUNDASHBOARD:-y}
RUNDASHBOARD=$(echo "$RUNDASHBOARD" | tr '[:upper:]' '[:lower:]')

if [ "$PREVIOUS_PASSWORD" != "none" ]; then
    read -p "Do you want to change the password for the Dashboard? (y/N): " CHANGEPASSWORD
    CHANGEPASSWORD=${CHANGEPASSWORD:-n}
    CHANGEPASSWORD=$(echo "$CHANGEPASSWORD" | tr '[:upper:]' '[:lower:]')
else
    CHANGEPASSWORD="y"
fi

if [ "$CHANGEPASSWORD" = "y" ]; then
    while true; do
        read -s -p "Set the password to access the Dashboard: " DASHPASS
        echo
        if [[ ${#DASHPASS} -ge 8 && "$DASHPASS" =~ [a-z] && "$DASHPASS" =~ [A-Z] && "$DASHPASS" =~ [0-9] && "$DASHPASS" =~ [!@#$%^&*()_+] ]]; then
            DASHPASS=$(hash_password "$DASHPASS")
            break
        else
            echo "Password does not meet the requirements. It should have at least 8 characters, one lowercase letter, one uppercase letter, one number, and one special character (!@#$%^&*()_+)."
        fi
    done
else
    DASHPASS=$PREVIOUS_PASSWORD
fi

if [ -z "$DASHPASS" ]; then
    echo "Failed to hash the password. Please ensure you have openssl, shasum, or sha256sum installed."
    exit 1
fi

read -p "Enter the port (1025-65536) to access the web based Dashboard (default $DASHPORT_DEFAULT): " DASHPORT
DASHPORT=${DASHPORT:-$DASHPORT_DEFAULT}
while ! [[ "$DASHPORT" =~ ^[0-9]+$ ]] || ((DASHPORT < 1025 || DASHPORT > 65536)); do
    read -p "Invalid port. Enter a port between 1025-65536: " DASHPORT
done

read -p "If you wish to set an explicit external IP, enter an IPv4 address (default=$EXTERNALIP_DEFAULT): " EXTERNALIP
EXTERNALIP=${EXTERNALIP:-$EXTERNALIP_DEFAULT}
while [ "$EXTERNALIP" != "auto" ] && ! [[ $EXTERNALIP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; do
    read -p "Invalid IPv4 address. Please try again: " EXTERNALIP
done

read -p "If you wish to set an explicit internal IP, enter an IPv4 address (default=$INTERNALIP_DEFAULT): " INTERNALIP
INTERNALIP=${INTERNALIP:-$INTERNALIP_DEFAULT}
while [ "$INTERNALIP" != "auto" ] && ! [[ $INTERNALIP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; do
    read -p "Invalid IPv4 address. Please try again: " INTERNALIP
done

read -p "Enter the first port (1025-65536) for p2p communication (default $SHMEXT_DEFAULT): " SHMEXT
SHMEXT=${SHMEXT:-$SHMEXT_DEFAULT}
while ! [[ "$SHMEXT" =~ ^[0-9]+$ ]] || ((SHMEXT < 1025 || SHMEXT > 65536)); do
    read -p "Invalid port. Enter a port between 1025-65536: " SHMEXT
done

read -p "Enter the second port (1025-65536) for p2p communication (default $SHMINT_DEFAULT): " SHMINT
SHMINT=${SHMINT:-$SHMINT_DEFAULT}
while ! [[ "$SHMINT" =~ ^[0-9]+$ ]] || ((SHMINT < 1025 || SHMINT > 65536)); do
    read -p "Invalid port. Enter a port between 1025-65536: " SHMINT
done

APPMONITOR="198.58.113.59"
RPC_SERVER_URL="https://atomium.shardeum.org"

# Function to set up environment
setup_environment() {
    if [ -d "$NODEHOME" ]; then
        if [ "$NODEHOME" != "$(pwd)" ]; then
            echo "Removing existing directory $NODEHOME..."
            rm -rf "$NODEHOME"
        else
            echo "Cannot delete current working directory. Please move to another directory and try again."
            exit 1
        fi
    fi

    git clone --depth 1 -b dev https://github.com/shardeum/validator-dashboard.git ${NODEHOME} || { echo "Error: Permission denied. Exiting script."; exit 1; }
    cd ${NODEHOME}
    chmod a+x ./*.sh

    # Create .env file
    cat >./.env <<EOL
EXT_IP=${EXTERNALIP}
INT_IP=${INTERNALIP}
EXISTING_ARCHIVERS=[{"ip":"198.58.110.213","port":4000,"publicKey":"d34b80a5a6f9638b7c75d6eb6e59d35d9a3e103f1877827eebbe973b8281f794"},{"ip":"3.73.66.238","port":4000,"publicKey":"7af699dd711074eb96a8d1103e32b589e511613ebb0c6a789a9e8791b2b05f34"},{"ip":"35.233.225.113","port":4000,"publicKey":"59c3794461c7f58a0a7f24d70dfd512d4364cd179d2670ac58e9ae533d50c7eb"}]
APP_MONITOR=${APPMONITOR}
DASHPASS=${DASHPASS}
DASHPORT=${DASHPORT}
SERVERIP=${SERVERIP}
LOCALLANIP=${LOCALLANIP}
SHMEXT=${SHMEXT}
SHMINT=${SHMINT}
RPC_SERVER_URL=${RPC_SERVER_URL}
NEXT_PUBLIC_RPC_URL=${RPC_SERVER_URL}
NEXT_EXPLORER_URL=https://explorer-atomium.shardeum.org/
minNodes=640
baselineNodes=640
maxNodes=640
nodesPerConsensusGroup=128
EOL

    # Modify docker-compose.yml
    sed "s/- '8080:8080'/- '$DASHPORT:$DASHPORT'/" docker-compose.tmpl > docker-compose.yml
    sed -i "s/- '9001-9010:9001-9010'/- '$SHMEXT:$SHMEXT'/" docker-compose.yml
    sed -i "s/- '10001-10010:10001-10010'/- '$SHMINT:$SHMINT'/" docker-compose.yml
}

# Run setup in the background
setup_environment &

# Wait for all background tasks to complete
wait

# Clear old images
./cleanup.sh

# Build base image
docker build --no-cache -t local-dashboard -f Dockerfile --build-arg RUNDASHBOARD=${RUNDASHBOARD} .

# Start compose project
./docker-up.sh

echo "Starting image. This could take a while..."
(docker logs -f shardeum-dashboard &) | grep -q 'done'

# Check if secrets.json exists and copy it inside container
CURRENT_DIRECTORY=$(pwd)
cd ${CURRENT_DIRECTORY}
if [ -f secrets.json ]; then
    echo "Reusing old node"
    CONTAINER_ID=$(docker ps -qf "ancestor=local-dashboard")
    echo "New container id is : $CONTAINER_ID"
    docker cp ./secrets.json "${CONTAINER_ID}:/home/node/app/cli/build/secrets.json"
    rm -f secrets.json
fi

if [ "$RUNDASHBOARD" = "y" ]; then
    cat << EOF
To use the Web Dashboard:
  1. Note the IP address that you used to connect to the node. This could be an external IP, LAN IP or localhost.
  2. Open a web browser and navigate to the web dashboard at https://<Node IP address>:$DASHPORT
  3. Go to the Settings tab and connect a wallet.
  4. Go to the Maintenance tab and click the Start Node button.

If this validator is on the cloud and you need to reach the dashboard over the internet,
please set a strong password and use the external IP instead of localhost.
EOF
fi

cat << EOF

To use the Command Line Interface:
  1. Navigate to the Shardeum home directory ($NODEHOME).
  2. Enter the validator container with ./shell.sh.
  3. Run "operator-cli --help" for commands

EOF
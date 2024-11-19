#!/usr/bin/env bash
set -e

# Get the environment/OS
environment=$(uname)

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

# Check if any hashing command is available
if ! (command -v openssl > /dev/null || command -v shasum > /dev/null || command -v sha256sum > /dev/null); then
  echo "No supported hashing commands found."
  
  # Detect package manager and install openssl
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
fi

# Default agreement
WARNING_AGREE="y"

# Set default directory
input="~/.shardeum"

# Replace leading tilde (~) with the actual home directory path
NODEHOME="${input/#\~/$HOME}" # support ~ in path

# Check all things that will be needed for this script to succeed like access to docker and docker-compose
command -v git >/dev/null 2>&1 || { echo >&2 "'git' is required but not installed."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo >&2 "'docker' is required but not installed. See https://github.com/shardeum/validator-dashboard?tab=readme-ov-file#how-to-install-and-run-a-shardeum-validator-node for details."; exit 1; }
if command -v docker-compose &>/dev/null; then
  echo "docker-compose is installed on this machine"
elif docker --help | grep -q "compose"; then
  echo "docker compose subcommand is installed on this machine"
else
  echo "docker-compose or docker compose is not installed on this machine"
  exit 1
fi

export DOCKER_DEFAULT_PLATFORM=linux/amd64

docker-safe() {
  if ! command -v docker &>/dev/null; then
    echo "docker is not installed on this machine"
    exit 1
  fi

  if ! docker $@; then
    echo "Trying again with sudo..." >&2
    sudo docker $@
  fi
}

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

get_ip() {
  local ip
  if command -v ip >/dev/null; then
    ip=$(ip addr show $(ip route | awk '/default/ {print $5}') | awk '/inet/ {print $2}' | cut -d/ -f1 | head -n1)
  elif command -v netstat >/dev/null; then
    # Get the default route interface
    interface=$(netstat -rn | awk '/default/{print $4}' | head -n1)
    # Get the IP address for the default interface
    ip=$(ifconfig "$interface" | awk '/inet /{print $2}')
  else
    echo "Error: neither 'ip' nor 'ifconfig' command found. Submit a bug for your OS."
    return 1
  fi
  echo $ip
}

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

hash_password() {
  local input="$1"
  local hashed_password

  # Try using openssl
  if command -v openssl > /dev/null; then
    hashed_password=$(echo -n "$input" | openssl dgst -sha256 -r | awk '{print $1}')
    echo "$hashed_password"
    return 0
  fi

  # Try using shasum
  if command -v shasum > /dev/null; then
    hashed_password=$(echo -n "$input" | shasum -a 256 | awk '{print $1}')
    echo "$hashed_password"
    return 0
  fi

  # Try using sha256sum
  if command -v sha256sum > /dev/null; then
    hashed_password=$(echo -n "$input" | sha256sum | awk '{print $1}')
    echo "$hashed_password"
    return 0
  fi

  return 1
}

if [[ $(docker-safe info 2>&1) == *"Cannot connect to the Docker daemon"* ]]; then
    echo "Docker daemon is not running"
    exit 1
else
    echo "Docker daemon is running"
fi

CURRENT_DIRECTORY=$(pwd)

# DEFAULT VALUES FOR USER INPUTS
DASHPORT_DEFAULT=8080
EXTERNALIP_DEFAULT=auto
INTERNALIP_DEFAULT=auto
SHMEXT_DEFAULT=9001
SHMINT_DEFAULT=10001
DEFAULT_PASSWORD="default_password"
DASHPASS=$(hash_password "$DEFAULT_PASSWORD")

# Automatically agree to run the dashboard
RUNDASHBOARD="y"

# Use default ports and IPs
DASHPORT=$DASHPORT_DEFAULT
EXTERNALIP=$EXTERNALIP_DEFAULT
INTERNALIP=$INTERNALIP_DEFAULT
SHMEXT=$SHMEXT_DEFAULT
SHMINT=$SHMINT_DEFAULT

# The rest of the script continues as in your original version...

#APPSEEDLIST="archiver-sphinx.shardeum.org"
#APPMONITOR="monitor-sphinx.shardeum.org"
APPMONITOR="198.58.113.59"
RPC_SERVER_URL="https://atomium.shardeum.org"

cat <<EOF

###########################
# 1. Pull Compose Project #
###########################

EOF

if [ -d "$NODEHOME" ]; then
  if [ "$NODEHOME" != "$(pwd)" ]; then
    echo "Removing existing directory $NODEHOME..."
    rm -rf "$NODEHOME"
  else
    echo "Cannot delete current working directory. Please move to another directory and try again."
  fi
fi

git clone https://github.com/shardeum/validator-dashboard.git ${NODEHOME} || { echo "Error: Permission denied. Exiting script."; exit 1; }
cd ${NODEHOME}
chmod a+x ./*.sh

cat <<EOF

###############################
# 2. Create and Set .env File #
###############################

EOF

SERVERIP=$(get_external_ip)
LOCALLANIP=$(get_ip)
cd ${NODEHOME} &&
touch ./.env
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
nodesPerConsensusGroup=128

EOL

cat <<EOF

##########################
# 3. Clearing Old Images #
##########################

EOF

./cleanup.sh

cat <<EOF

##########################
# 4. Building base image #
##########################

EOF

cd ${NODEHOME} &&
docker-safe build --no-cache -t local-dashboard -f Dockerfile --build-arg RUNDASHBOARD=${RUNDASHBOARD} .

cat <<EOF

############################
# 5. Start Compose Project #
############################

EOF

cd ${NODEHOME}
if [[ "$(uname)" == "Darwin" ]]; then
  sed "s/- '8080:8080'/- '$DASHPORT:$DASHPORT'/" docker-compose.tmpl > docker-compose.yml
  sed -i '' "s/- '9001-9010:9001-9010'/- '$SHMEXT:$SHMEXT'/" docker-compose.yml
  sed -i '' "s/- '10001-10010:10001-10010'/- '$SHMINT:$SHMINT'/" docker-compose.yml
else
  sed "s/- '8080:8080'/- '$DASHPORT:$DASHPORT'/" docker-compose.tmpl > docker-compose.yml
  sed -i "s/- '9001-9010:9001-9010'/- '$SHMEXT:$SHMEXT'/" docker-compose.yml
  sed -i "s/- '10001-10010:10001-10010'/- '$SHMINT:$SHMINT'/" docker-compose.yml
fi
./docker-up.sh

echo "Starting image. This could take a while..."
(docker-safe logs -f shardeum-dashboard &) | grep -q 'done'

# Check if secrets.json exists and copy it inside container
cd ${CURRENT_DIRECTORY}
if [ -f secrets.json ]; then
  echo "Reusing old node"
  CONTAINER_ID=$(docker-safe ps -qf "ancestor=local-dashboard")
  echo "New container id is : $CONTAINER_ID"
  docker-safe cp ./secrets.json "${CONTAINER_ID}:/home/node/app/cli/build/secrets.json"
  rm -f secrets.json
fi

#Do not indent
if [ $RUNDASHBOARD = "y" ]
then
cat <<EOF
  To use the Web Dashboard:
    1. Note the IP address that you used to connect to the node. This could be an external IP, LAN IP or localhost.
    2. Open a web browser and navigate to the web dashboard at https://<Node IP address>:$DASHPORT
    3. Go to the Settings tab and connect a wallet.
    4. Go to the Maintenance tab and click the Start Node button.

  If this validator is on the cloud and you need to reach the dashboard over the internet,
  please set a strong password and use the external IP instead of localhost.
EOF
fi

cat <<EOF

To use the Command Line Interface:
	1. Navigate to the Shardeum home directory ($NODEHOME).
	2. Enter the validator container with ./shell.sh.
	3. Run "operator-cli --help" for commands

EOF

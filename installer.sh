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
  read -p "Would you like to install openssl? (y/n) " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then
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
  else
    echo "Please install openssl, shasum, or sha256sum and try again."
    exit 1
  fi
fi


read -p "During this early stage of Betanet the Shardeum team will be collecting some performance and debugging info from your node to help improve future versions of the software.
This is only temporary and will be discontinued as we get closer to mainnet.
Thanks for running a node and helping to make Shardeum better.

By running this installer, you agree to allow the Shardeum team to collect this data. (Y/n)?: " WARNING_AGREE

# Echo user's response, or indicate if no response was provided
if [ -z "$WARNING_AGREE" ]; then
    echo "No response provided."
    echo "Defaulting to y"
    WARNING_AGREE=y
else
    echo "You entered: $WARNING_AGREE"
fi

WARNING_AGREE=$(echo "$WARNING_AGREE" | tr '[:upper:]' '[:lower:]')

if [ $WARNING_AGREE != "y" ];
then
  echo "Diagnostic data collection agreement not accepted. Exiting installer."
  exit
fi

read -p "What base directory should the node use (default ~/.shardeum): " input

# Set default value if input is empty
input=${input:-~/.shardeum}

# Check if input starts with "/" or "~/", if not, add "~/"
if [[ ! $input =~ ^(/|~\/) ]]; then
  input="~/$input"
fi

# Reprompt if not alphanumeric characters, tilde, forward slash, underscore, period, hyphen, or contains spaces
while [[ ! $input =~ ^[[:alnum:]_.~/-]+$ || $input =~ .*[\ ].* ]]; do
  read -p "Error: The directory name contains invalid characters or spaces.
Allowed characters are alphanumeric characters, tilde, forward slash, underscore, period, and hyphen.
Please enter a valid base directory (default ~/.shardeum): " input

  # Check if input starts with "/" or "~/", if not, add "~/"
  if [[ ! $input =~ ^(/|~\/) ]]; then
    input="~/$input"
  fi
done

# Remove spaces from the input
input=${input// /}

# Echo the final directory used
echo "The base directory is set to: $input"

# Expand the tilde in the input if any
NODEHOME=`realpath "${input}"`

echo "Real path for directory is: $NODEHOME"

# Check all things that will be needed for this script to succeed like access to docker and docker-compose
# If any check fails, attempt to install the missing dependency
command -v git >/dev/null 2>&1 || {
    echo >&2 "'git' is not installed. Attempting to install git..."
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y git
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y git
    else
        echo >&2 "Unable to install git. Please install it manually."
        exit 1
    fi
}

command -v docker >/dev/null 2>&1 || {
    echo >&2 "'docker' is not installed. Attempting to install docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
}

if ! command -v docker-compose &>/dev/null && ! docker --help | grep -q "compose"; then
    echo "docker-compose or docker compose is not installed. Attempting to install docker-compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Verify installations
command -v git >/dev/null 2>&1 || { echo >&2 "Failed to install git. Please install it manually."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo >&2 "Failed to install docker. Please install it manually."; exit 1; }
if command -v docker-compose &>/dev/null; then
    echo "docker-compose is installed on this machine"
elif docker --help | grep -q "compose"; then
    echo "docker compose subcommand is installed on this machine"
else
    echo "Failed to install docker-compose. Please install it manually."
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
PREVIOUS_PASSWORD=none


GITLAB_IMAGE_NAME="registry.gitlab.com/shardeum/server:latest"
GITHUB_IMAGE_NAME="ghcr.io/shardeum/server:latest"

# Check if container exists with GitLab image
GITLAB_CONTAINER_ID=$(docker-safe ps -qf "ancestor=$GITLAB_IMAGE_NAME")

# Check if container exists with GitHub image
GITHUB_CONTAINER_ID=$(docker-safe ps -qf "ancestor=$GITHUB_IMAGE_NAME")

# Determine action based on found container
if [ ! -z "$GITLAB_CONTAINER_ID" ]; then
  echo "Existing GitLab container found. ID: $GITLAB_CONTAINER_ID"
  # Perform actions for GitLab container, e.g., copy settings, upgrade
  CONTAINER_ID=$GITLAB_CONTAINER_ID
elif [ ! -z "$GITHUB_CONTAINER_ID" ]; then
  echo "Existing GitHub container found. ID: $GITHUB_CONTAINER_ID"
  # Perform actions for GitHub container, e.g., copy settings, upgrade
  CONTAINER_ID=$GITHUB_CONTAINER_ID
else
  echo "No existing containers found. Proceeding with fresh installation."
fi

if [ ! -z "${CONTAINER_ID}" ]; then
  echo "CONTAINER_ID: ${CONTAINER_ID}"
  echo "Existing container found. Reading settings from container."

  # Assign output of read_container_settings to variable
  if ! ENV_VARS=$(docker inspect --format="{{range .Config.Env}}{{println .}}{{end}}" "$CONTAINER_ID"); then
    ENV_VARS=$(sudo docker inspect --format="{{range .Config.Env}}{{println .}}{{end}}" "$CONTAINER_ID")
  fi

  if ! docker-safe cp "${CONTAINER_ID}:/home/node/app/cli/build/secrets.json" ./; then
    echo "Container does not have secrets.json"
  else
    echo "Reusing secrets.json from container"
  fi

  # CHECK IF VALIDATOR IS ALREADY RUNNING
  set +e
  status=$(docker-safe exec "${CONTAINER_ID}" operator-cli status 2>/dev/null)
  check=$?
  set -e

  if [ $check -eq 0 ]; then
    # The command ran successfully
    status=$(awk '/state:/ {print $2}' <<< $status)
    if [ "$status" = "active" ] || [ "$status" = "syncing" ]; then
      read -p "Your node is $status and upgrading will cause the node to leave the network unexpectedly and lose the stake amount.
      Do you really want to upgrade now (y/N)?" REALLYUPGRADE
      REALLYUPGRADE=$(echo "$REALLYUPGRADE" | tr '[:upper:]' '[:lower:]')
      REALLYUPGRADE=${REALLYUPGRADE:-n}

      if [ "$REALLYUPGRADE" == "n" ]; then
        exit 1
      fi
    else
      echo "Validator process is not online"
    fi
  else
    read -p "The installer was unable to determine if the existing node is active.
    An active node unexpectedly leaving the network will lose it's stake amount.
    Do you really want to upgrade now (y/N)?" REALLYUPGRADE
    REALLYUPGRADE=$(echo "$REALLYUPGRADE" | tr '[:upper:]' '[:lower:]')
    REALLYUPGRADE=${REALLYUPGRADE:-n}

    if [ "$REALLYUPGRADE" == "n" ]; then
      exit 1
    fi
  fi

  docker-safe stop "${CONTAINER_ID}"
  docker-safe rm "${CONTAINER_ID}"

  # UPDATE DEFAULT VALUES WITH SAVED VALUES
  DASHPORT_DEFAULT=$(echo $ENV_VARS | grep -oP 'DASHPORT=\K[^ ]+') || DASHPORT_DEFAULT=8080
  EXTERNALIP_DEFAULT=$(echo $ENV_VARS | grep -oP 'EXT_IP=\K[^ ]+') || EXTERNALIP_DEFAULT=auto
  INTERNALIP_DEFAULT=$(echo $ENV_VARS | grep -oP 'INT_IP=\K[^ ]+') || INTERNALIP_DEFAULT=auto
  SHMEXT_DEFAULT=$(echo $ENV_VARS | grep -oP 'SHMEXT=\K[^ ]+') || SHMEXT_DEFAULT=9001
  SHMINT_DEFAULT=$(echo $ENV_VARS | grep -oP 'SHMINT=\K[^ ]+') || SHMINT_DEFAULT=10001
  PREVIOUS_PASSWORD=$(echo $ENV_VARS | grep -oP 'DASHPASS=\K[^ ]+') || PREVIOUS_PASSWORD=none
elif [ -f NODEHOME/.env ]; then
  echo "Existing NODEHOME/.env file found. Reading settings from file."

  # Read the NODEHOME/.env file into a variable. Use default installer directory if it exists.
  ENV_VARS=$(cat NODEHOME/.env)

  # UPDATE DEFAULT VALUES WITH SAVED VALUES
  DASHPORT_DEFAULT=$(echo $ENV_VARS | grep -oP 'DASHPORT=\K[^ ]+') || DASHPORT_DEFAULT=8080
  EXTERNALIP_DEFAULT=$(echo $ENV_VARS | grep -oP 'EXT_IP=\K[^ ]+') || EXTERNALIP_DEFAULT=auto
  INTERNALIP_DEFAULT=$(echo $ENV_VARS | grep -oP 'INT_IP=\K[^ ]+') || INTERNALIP_DEFAULT=auto
  SHMEXT_DEFAULT=$(echo $ENV_VARS | grep -oP 'SHMEXT=\K[^ ]+') || SHMEXT_DEFAULT=9001
  SHMINT_DEFAULT=$(echo $ENV_VARS | grep -oP 'SHMINT=\K[^ ]+') || SHMINT_DEFAULT=10001
  PREVIOUS_PASSWORD=$(echo $ENV_VARS | grep -oP 'DASHPASS=\K[^ ]+') || PREVIOUS_PASSWORD=none
fi

cat << EOF

#########################
# 0. GET INFO FROM USER #
#########################

EOF

read -p "Do you want to run the web based Dashboard? (Y/n): " RUNDASHBOARD
RUNDASHBOARD=$(echo "$RUNDASHBOARD" | tr '[:upper:]' '[:lower:]')
RUNDASHBOARD=${RUNDASHBOARD:-y}

if [ "$PREVIOUS_PASSWORD" != "none" ]; then
  read -p "Do you want to change the password for the Dashboard? (y/N): " CHANGEPASSWORD
  CHANGEPASSWORD=$(echo "$CHANGEPASSWORD" | tr '[:upper:]' '[:lower:]')
  CHANGEPASSWORD=${CHANGEPASSWORD:-n}
else
  CHANGEPASSWORD="y"
fi


read_password() {
  local CHARCOUNT=0
  local PASSWORD=""
  while IFS= read -p "$PROMPT" -r -s -n 1 CHAR
  do
    # Enter - accept password
    if [[ $CHAR == $'\0' ]] ; then
      break
    fi
    # Backspace
    if [[ $CHAR == $'\177' ]] ; then
      if [ $CHARCOUNT -gt 0 ] ; then
        CHARCOUNT=$((CHARCOUNT-1))
        PROMPT=$'\b \b'
        PASSWORD="${PASSWORD%?}"
      else
        PROMPT=''
      fi
    else
      CHARCOUNT=$((CHARCOUNT+1))
      PROMPT='*'
      PASSWORD+="$CHAR"
    fi
  done
  echo $PASSWORD
}

if [ "$CHANGEPASSWORD" = "y" ]; then
  valid_pass=false
  while [ "$valid_pass" = false ] ;
  do
    echo -n -e "Password requirements: min 8 characters, at least 1 lower case letter, at least 1 upper case letter, at least 1 number, at least 1 special character !@#$%^&*()_+$ \nSet the password to access the Dashboard:"
    DASHPASS=$(read_password)

    # Check password length
    if (( ${#DASHPASS} < 8 )); then
        echo -e "\nInvalid password! Too short.\n"

    # Check for at least one lowercase letter
    elif ! [[ "$DASHPASS" =~ [a-z] ]]; then
        echo -e "\nInvalid password! Must contain at least one lowercase letter.\n"

    # Check for at least one uppercase letter
    elif ! [[ "$DASHPASS" =~ [A-Z] ]]; then
        echo -e "\nInvalid password! Must contain at least one uppercase letter.\n"

    # Check for at least one number
    elif ! [[ "$DASHPASS" =~ [0-9] ]]; then
        echo -e "\nInvalid password! Must contain at least one number.\n"

    # Check for at least one special character
    elif ! [[ "$DASHPASS" =~ [!@#$%^\&*()_+$] ]]; then
        echo -e "\nInvalid password! Must contain at least one special character !@#$%^&*()_+$.\n"

    # Password is valid
    else
        valid_pass=true
        echo "\nPassword set successfully."
    fi
  done

  # Hash the password using the fallback mechanism
  DASHPASS=$(hash_password "$DASHPASS")
else
  DASHPASS=$PREVIOUS_PASSWORD
  if ! [[ $DASHPASS =~ ^[0-9a-f]{64}$ ]]; then
    DASHPASS=$(hash_password "$DASHPASS")
  fi
fi

if [ -z "$DASHPASS" ]; then
  echo -e "\nFailed to hash the password. Please ensure you have openssl"
  exit 1
fi

echo # New line after inputs.
# echo "Password saved as:" $DASHPASS #DEBUG: TEST PASSWORD WAS RECORDED AFTER ENTERED.

while :; do
  read -p "Enter the port (1025-65536) to access the web based Dashboard (default $DASHPORT_DEFAULT): " DASHPORT
  DASHPORT=${DASHPORT:-$DASHPORT_DEFAULT}
  [[ $DASHPORT =~ ^[0-9]+$ ]] || { echo "Enter a valid port"; continue; }
  if ((DASHPORT >= 1025 && DASHPORT <= 65536)); then
    DASHPORT=${DASHPORT:-$DASHPORT_DEFAULT}
    break
  else
    echo "Port out of range, try again"
  fi
done

while :; do
  read -p "If you wish to set an explicit external IP, enter an IPv4 address (default=$EXTERNALIP_DEFAULT): " EXTERNALIP
  EXTERNALIP=${EXTERNALIP:-$EXTERNALIP_DEFAULT}

  if [ "$EXTERNALIP" == "auto" ]; then
    break
  fi

  # Use regex to check if the input is a valid IPv4 address
  if [[ $EXTERNALIP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    # Check that each number in the IP address is between 0-255
    valid_ip=true
    IFS='.' read -ra ip_nums <<< "$EXTERNALIP"
    for num in "${ip_nums[@]}"
    do
        if (( num < 0 || num > 255 )); then
            valid_ip=false
        fi
    done

    if [ $valid_ip == true ]; then
      break
    else
      echo "Invalid IPv4 address. Please try again."
    fi
  else
    echo "Invalid IPv4 address. Please try again."
  fi
done

while :; do
  read -p "If you wish to set an explicit internal IP, enter an IPv4 address (default=$INTERNALIP_DEFAULT): " INTERNALIP
  INTERNALIP=${INTERNALIP:-$INTERNALIP_DEFAULT}

  if [ "$INTERNALIP" == "auto" ]; then
    break
  fi

  # Use regex to check if the input is a valid IPv4 address
  if [[ $INTERNALIP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    # Check that each number in the IP address is between 0-255
    valid_ip=true
    IFS='.' read -ra ip_nums <<< "$INTERNALIP"
    for num in "${ip_nums[@]}"
    do
        if (( num < 0 || num > 255 )); then
            valid_ip=false
        fi
    done

    if [ $valid_ip == true ]; then
      break
    else
      echo "Invalid IPv4 address. Please try again."
    fi
  else
    echo "Invalid IPv4 address. Please try again."
  fi
done

while :; do
  echo "To run a validator on the Sphinx network, you will need to open two ports in your firewall."
  read -p "This allows p2p communication between nodes. Enter the first port (1025-65536) for p2p communication (default $SHMEXT_DEFAULT): " SHMEXT
  SHMEXT=${SHMEXT:-$SHMEXT_DEFAULT}
  [[ $SHMEXT =~ ^[0-9]+$ ]] || { echo "Enter a valid port"; continue; }
  if ((SHMEXT >= 1025 && SHMEXT <= 65536)); then
    SHMEXT=${SHMEXT:-9001}
  else
    echo "Port out of range, try again"
  fi
  read -p "Enter the second port (1025-65536) for p2p communication (default $SHMINT_DEFAULT): " SHMINT
  SHMINT=${SHMINT:-$SHMINT_DEFAULT}
  [[ $SHMINT =~ ^[0-9]+$ ]] || { echo "Enter a valid port"; continue; }
  if ((SHMINT >= 1025 && SHMINT <= 65536)); then
    SHMINT=${SHMINT:-10001}
    break
  else
    echo "Port out of range, try again"
  fi
done

#APPSEEDLIST="archiver-sphinx.shardeum.org"
#APPMONITOR="monitor-sphinx.shardeum.org"
APPMONITOR="96.126.116.124"
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

git clone -b dev https://github.com/shardeum/validator-dashboard.git ${NODEHOME} || { echo "Error: Permission denied. Exiting script."; exit 1; }
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
EXISTING_ARCHIVERS=[{"ip":"34.159.56.206","port":4000,"publicKey":"64a3833499130406550729ab20f6bec351d04ec9be3e5f0144d54f01d4d18c45"},{"ip":"3.76.189.189","port":4000,"publicKey":"44d4be08423dd9d90195d650fc58f41cc2fdeb833180686cdbcb3196fe113497"},{"ip":"69.164.202.28","port":4000,"publicKey":"2cfbc5a9a96591e149225395ba33fed1a8135123f7702abdb7deca3d010a21ee"}]
APP_MONITOR=${APPMONITOR}
DASHPASS=${DASHPASS}
DASHPORT=${DASHPORT}
SERVERIP=${SERVERIP}
LOCALLANIP=${LOCALLANIP}
SHMEXT=${SHMEXT}
SHMINT=${SHMINT}
RPC_SERVER_URL=${RPC_SERVER_URL}
NEXT_PUBLIC_RPC_URL=${RPC_SERVER_URL}
NEXT_EXPLORER_URL=https://explorer-atomium.shardeum.org
minNodes=640
baselineNodes=640
maxNodes=1200
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

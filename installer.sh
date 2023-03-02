#!/usr/bin/env bash
set -e


read -p "During this early stage of Betanet the Shardeum team will be collecting some performance and debugging info from your node to help improve future versions of the software.
This is only temporary and will be discontinued as we get closer to mainnet.
Thanks for running a node and helping to make Shardeum better.

By running this installer, you agree to allow the Shardeum team to collect this data. (y/n)?: " WARNING_AGREE
WARNING_AGREE=${WARNING_AGREE:-y}

if [ $WARNING_AGREE != "y" ];
then
  echo "Diagnostic data collection agreement not accepted. Exiting installer."
  exit
fi


# Check all things that will be needed for this script to succeed like access to docker and docker-compose
# If any check fails exit with a message on what the user needs to do to fix the problem
command -v git >/dev/null 2>&1 || { echo >&2 "'git' is required but not installed."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo >&2 "'docker' is required but not installed. See https://gitlab.com/shardeum/validator/dashboard/-/tree/dashboard-gui-nextjs#how-to for details."; exit 1; }
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
    echo "Trying again with sudo..."
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

if [[ $(docker-safe info 2>&1) == *"Cannot connect to the Docker daemon"* ]]; then
    echo "Docker daemon is not running"
    exit 1
else
    echo "Docker daemon is running"
fi

cat << EOF

#########################
# 0. GET INFO FROM USER #
#########################

EOF

read -p "Do you want to run the web based Dashboard? (y/n): " RUNDASHBOARD
RUNDASHBOARD=${RUNDASHBOARD:-y}

unset CHARCOUNT
echo -n "Set the password to access the Dashboard: "
CHARCOUNT=0
while IFS= read -p "$PROMPT" -r -s -n 1 CHAR
do
  # Enter - accept password
  if [[ $CHAR == $'\0' ]] ; then
    if [ $CHARCOUNT -gt 0 ] ; then # Make sure password character length is greater than 0.
      break
    else
      echo
      echo -n "Invalid password input. Enter a password with character length greater than 0:"
      continue
    fi
  fi
  # Backspace
  if [[ $CHAR == $'\177' ]] ; then
    if [ $CHARCOUNT -gt 0 ] ; then
      CHARCOUNT=$((CHARCOUNT-1))
      PROMPT=$'\b \b'
      DASHPASS="${DASHPASS%?}"
    else
      PROMPT=''
    fi
  else
    CHARCOUNT=$((CHARCOUNT+1))
    PROMPT='*'
    DASHPASS+="$CHAR"
  fi
done

echo # New line after inputs.
# echo "Password saved as:" $DASHPASS #DEBUG: TEST PASSWORD WAS RECORDED AFTER ENTERED.

while :; do
  read -p "Enter the port (1025-65536) to access the web based Dashboard (default 8080): " DASHPORT
  DASHPORT=${DASHPORT:-8080}
  [[ $DASHPORT =~ ^[0-9]+$ ]] || { echo "Enter a valid port"; continue; }
  if ((DASHPORT >= 1025 && DASHPORT <= 65536)); then
    DASHPORT=${DASHPORT:-8080}
    break
  else
    echo "Port out of range, try again"
  fi
done

while :; do
  echo "To run a validator on the Sphinx network, you will need to open two ports in your firewall."
  read -p "This allows p2p communication between nodes. Enter the first port (1025-65536) for p2p communication (default 9001): " SHMEXT
  SHMEXT=${SHMEXT:-9001}
  [[ $SHMEXT =~ ^[0-9]+$ ]] || { echo "Enter a valid port"; continue; }
  if ((SHMEXT >= 1025 && SHMEXT <= 65536)); then
    SHMEXT=${SHMEXT:-9001}
  else
    echo "Port out of range, try again"
  fi
  read -p "Enter the second port (1025-65536) for p2p communication (default 10001): " SHMINT
  SHMINT=${SHMINT:-10001}
  [[ $SHMINT =~ ^[0-9]+$ ]] || { echo "Enter a valid port"; continue; }
  if ((SHMINT >= 1025 && SHMINT <= 65536)); then
    SHMINT=${SHMINT:-10001}
    break
  else
    echo "Port out of range, try again"
  fi
done

read -p "What base directory should the node use (defaults to ~/.shardeum): " NODEHOME
NODEHOME=${NODEHOME:-~/.shardeum}

APPSEEDLIST="archiver-sphinx.shardeum.org"
APPMONITOR="monitor-sphinx.shardeum.org"

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

git clone https://gitlab.com/shardeum/validator/dashboard.git ${NODEHOME} &&
  cd ${NODEHOME} &&
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
APP_IP=auto
APP_SEEDLIST=${APPSEEDLIST}
APP_MONITOR=${APPMONITOR}
DASHPASS=${DASHPASS}
DASHPORT=${DASHPORT}
SERVERIP=${SERVERIP}
LOCALLANIP=${LOCALLANIP}
SHMEXT=${SHMEXT}
SHMINT=${SHMINT}
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



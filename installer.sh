#!/bin/bash

cat <<EOF

#########################
# 0. GET INFO FROM USER #
#########################

EOF

read -p "Do you want to run the web based Dashboard? (y/n): " RUNDASHBOARD

read -p "Set the password to access the Dashboard: " -s DASHPASS
echo

read -p "Dashboard can be accessed at localhost:8080. Use another port? (1025-65536): " DASHPORT
DASHPORT=${DASHPORT:-8080}

read -p "What base directory should the node use (defaults to ~/.shardeum): " NODEHOME
NODEHOME=${NODEHOME:-~/.shardeum}

echo

cat <<EOF

###########################
# 1. Pull Compose Project #
###########################

EOF

git clone -b dashboard-gui-nextjs https://gitlab.com/shardeum/validator/dashboard.git ${NODEHOME} &&
  cd ${NODEHOME} &&
  chmod a+x ./*.sh

cat <<EOF

#########################
# 2. Building base image #
#########################

EOF

docker build --no-cache -t test-dashboard -f Dockerfile .

cat <<EOF

###############################
# 3. Create and Set .env File #
###############################

EOF

# touch ./.env &&
# cat >./.env <<EOL
# BASE_DIR=${NODEHOME}
# EOL

cat <<EOF

############################
# 4. Start Compose Project #
############################

EOF

./docker-up.sh

echo "Starting image."
(docker logs -f shardeum-dashboard &) | grep -q 'done'

echo "Please run ./shell.sh for next steps."

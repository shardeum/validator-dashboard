#!/usr/bin/env bash

cat << EOF

#########################
# 1. GET INFO FROM USER #
#########################

EOF

read -p "Do you want to run the web based Dashboard? (y/n): " RUNDASHBOARD

read -p "Set the password to access the Dashboard: " -s DASHPASS
echo

read -p "Dashboard can be accessed at localhost:59999. Use another port? (1025-65536): " DASHPORT
DASHPORT=${DASHPORT:-59999}

read -p "What base directory should the node use (defaults to ~/.shardeum): " NODEHOME
NODEHOME=${NODEHOME:-~/.shardeum}

echo

cat << EOF

###########################
# 2. Pull Compose Project #
###########################

EOF

git clone https://gitlab.com/shardeum/shardeum-docker.git ${NODEHOME} &&
cd ${NODEHOME} &&
cd validator &&
chmod a+x ./*.sh &&

cat << EOF

###############################
# 3. Create and Set .env File #
###############################

EOF

touch ./.env &&
# cat >./.env <<EOL
# BASE_DIR=${NODEHOME}
# EOL

cat << EOF

############################
# 4. Start Compose Project #
############################

EOF

./docker-up.sh
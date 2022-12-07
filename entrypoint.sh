#!/usr/bin/env bash

echo "Install PM2 globally"

npm i -g pm2

# Pull latest versions of the CLI and GUI
# git fetch
# git checkout main
# git pull --rebase origin main

git clone https://gitlab.com/shardus/validator/cli.git

echo "Install the CLI globally and put it in the path"
cd cli
npm i && npm link
cd ..

git clone https://gitlab.com/shardus/validator/gui.git

echo "Install the GUI"
cd gui
cd backend
npm i
cd ../..

# Clone the shardeum validator
#git config --global credential.helper '!f() { sleep 1; echo "username=${GIT_USER}"; echo "password=${GIT_PASS}"; }; f'
#git clone https://gitlab.com/shardeum/server.git validator
#cd validator && git checkout ${VALIDATOR_VERSION} && npm i
#git config --global credential.helper cache
#cd ..

# Start GUI if configured to in env file
if [ "$START_GUI" == "1" ]
then
# Call the CLI command to start the GUI
operator-cli gui start
fi

echo "Please run ./shell.sh for next steps."

# Keep container running
tail -f /dev/null

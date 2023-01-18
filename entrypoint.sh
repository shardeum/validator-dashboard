#!/usr/bin/env bash
sudo chown -R node:node /home/node
sudo chown -R node:node /usr/src/app
sudo ln -s /usr/src/app /home/node/app/validator
sleep 10;

echo "Install PM2"

npm i -g pm2

# Pull latest versions of the CLI and GUI
# git fetch
# git checkout main
# git pull --rebase origin main

git clone -b dev https://gitlab.com/shardeum/validator/cli.git
# git clone https://gitlab.com/shardus/validator/cli.git

echo "Install the CLI"
cd cli
npm i && npm link
cd ..

git clone -b feature/dashboard-cli-integration https://gitlab.com/shardeum/validator/gui.git
#git clone https://gitlab.com/shardus/validator/gui.git 

echo "Install the GUI"
cd gui
cd backend
npm i
cd ..
cd frontend
cd dashboard-gui
npm i
npm run build
cd ../..


# Start GUI if configured to in env file
echo $RUNDASHBOARD
if [ "$RUNDASHBOARD" == "y" ]
then
echo "Starting operator gui"
# Call the CLI command to start the GUI
operator-cli gui start
fi


# Clone the shardeum validator
#git config --global credential.helper '!f() { sleep 1; echo "username=${GIT_USER}"; echo "password=${GIT_PASS}"; }; f'
#git clone https://gitlab.com/shardeum/server.git validator
#cd validator && git checkout ${VALIDATOR_VERSION} && npm i
#git config --global credential.helper cache
#cd ..

echo "done";

# Keep container running
tail -f /dev/null

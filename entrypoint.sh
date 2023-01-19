#!/usr/bin/env bash
sudo chown -R node:node /home/node
sudo chown -R node:node /usr/src/app
sudo ln -s /usr/src/app /home/node/app/validator
sleep 10;

echo "Install PM2"

npm i -g pm2

# Pull latest versions of the CLI and GUI

git clone https://gitlab.com/shardeum/validator/cli.git

echo "Install the CLI"
cd cli
npm i && npm link
cd ..

git clone https://gitlab.com/shardeum/validator/gui.git

echo "Install the GUI"
cd gui
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

echo "done";

# Keep container running
tail -f /dev/null

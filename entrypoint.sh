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
#openssl req -x509 -nodes -days 99999 -newkey rsa:2048 -keyout ./selfsigned.key -out selfsigned.crt -subj "/C=US/ST=Texas/L=Dallas/O=Shardeum/OU=Shardeum/CN=shardeum.org"
echo "[req]
default_bits  = 4096
distinguished_name = req_distinguished_name
req_extensions = req_ext
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
countryName = XX
stateOrProvinceName = N/A
localityName = N/A
organizationName = Shardeum Sphinx 1.x Operator Node
commonName = $SERVERIP

[req_ext]
subjectAltName = @alt_names

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
IP.1 = $SERVERIP
IP.2 = 127.0.0.1

" > san.cnf
openssl req -x509 -nodes -days 730 -newkey rsa:2048 -keyout ./selfsigned.key -out selfsigned.crt -config san.cnf
#rm san.cnf
cd ../..


# Start GUI if configured to in env file
echo $RUNDASHBOARD
if [ "$RUNDASHBOARD" == "y" ]
then
echo "Starting operator gui"
# Call the CLI command to set the GUI password
operator-cli gui set password $DASHPASS
# Call the CLI command to set the GUI port
operator-cli gui set port $DASHPORT
# Call the CLI command to start the GUI
operator-cli gui start
fi

echo "done";

# Keep container running
tail -f /dev/null

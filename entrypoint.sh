#!/usr/bin/env bash
set -e

# Function to create file if it doesn't exist
create_file_if_not_exists() {
    [ -f "$1" ] || echo "$2" > "$1" &
}

# Function to clone and install CLI
install_cli() {
    git clone --depth 1 -b dev https://github.com/shardeum/validator-cli.git
    cd validator-cli
    npm ci --silent && npm link
    cd ..
}

# Function to clone and install GUI
install_gui() {
    git clone --depth 1 -b dev https://github.com/shardeum/validator-gui.git
    cd validator-gui
    npm ci --silent
    npm run build
    
    create_file_if_not_exists "CA.cnf" "[ req ]
prompt = no
distinguished_name = req_distinguished_name

[ req_distinguished_name ]
C = XX
ST = Localzone
L = localhost
O = Certificate Authority Local Validator Node
OU = Develop
CN = mynode-sphinx.sharedum.local
emailAddress = community@.sharedum.local"

    create_file_if_not_exists "selfsigned.cnf" "[ req ]
default_bits  = 4096
distinguished_name = req_distinguished_name
req_extensions = req_ext
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
countryName = XX
stateOrProvinceName = Localzone
localityName = Localhost
organizationName = Shardeum Sphinx 1.x Validator Cert.
commonName = localhost

[req_ext]
subjectAltName = @alt_names

[v3_req]
subjectAltName = @alt_names

[alt_names]
IP.1 = $SERVERIP
IP.2 = $LOCALLANIP
DNS.1 = localhost"

    wait

    # Generate CA key and cert in parallel
    [ -f "CA_key.pem" ] || openssl req -nodes -new -x509 -keyout CA_key.pem -out CA_cert.pem -days 1825 -config CA.cnf &
    [ -f "selfsigned.csr" ] || openssl req -sha256 -nodes -newkey rsa:4096 -keyout selfsigned.key -out selfsigned.csr -config selfsigned.cnf &
    wait

    # Generate selfsigned cert
    [ -f "selfsigned_node.crt" ] || openssl x509 -req -days 398 -in selfsigned.csr -CA CA_cert.pem -CAkey CA_key.pem -CAcreateserial -out selfsigned_node.crt -extensions req_ext -extfile selfsigned.cnf

    # Combine certs
    [ -f "selfsigned.crt" ] || cat selfsigned_node.crt CA_cert.pem > selfsigned.crt

    cd ..
}

# Main script starts here

# Run installations in parallel
install_cli &
install_gui &
wait

# Start GUI if configured to in env file
if [ "$RUNDASHBOARD" == "y" ]
then
    echo "Starting operator gui"
    # Call the CLI commands to set up and start the GUI
    operator-cli gui set password -h $DASHPASS
    operator-cli gui set port $DASHPORT
    operator-cli gui start
fi

echo "done"

# Keep container running
tail -f /dev/null
# How to Install and Run a Shardeum Validator Node

This guide will walk you through the process of installing and running a Shardeum Validator Node on your system. Please follow the steps below carefully.

## Prerequisites

Before you begin, ensure you have the following prerequisites installed on your system:

1. Install Package Managers

**For Linux:**

```bash
sudo apt-get install curl
```

**For MacOS:**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Add Homebrew to your `PATH`:

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
eval "$(/opt/homebrew/bin/brew shellenv)"
```

2. Update Package Managers:

For Linux:

```bash
sudo apt update
```

For MacOS:

```bash
brew update
```

3. Install docker

For Linux:

Install docker with docker.io

```bash
sudo apt install docker.io
```

For MacOS:

```bash
brew install docker
```

> Verify Docker installation by running `docker --version` (should return version 20.10.12 or higher).

4. Install docker-compose

**For Linux:**

```bash
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
```

Setup permissions for docker-compose using

```bash
sudo chmod +x /usr/local/bin/docker-compose
```

**For MacOS:**

```bash
brew install docker-compose
```

> Verify docker-compose installation by running `docker-compose --version` (should return version 1.29.2 or higher).

## Download and Run Installation Script

Choose one of the following methods to download and run the installation script:

Using `curl`

```bash
curl -O https://raw.githubusercontent.com/shardeum/validator-dashboard/main/installer.sh && chmod +x installer.sh && ./installer.sh
```

Using `wget`

```bash
wget -O installer.sh https://raw.githubusercontent.com/shardeum/validator-dashboard/main/installer.sh && chmod +x installer.sh && ./installer.sh
```

Follow the instructions provided by the installer script. Ensure you input the correct Archiver and Monitor IP addresses for the network you wish your validator to join.

> If you are behind a router and you are using ports 9001 and 10001 for p2p communication, make sure ports 9001 and 10001, are forwarded (be careful doing this since it will modify your firewall). More info on router port forwarding: <https://www.noip.com/support/knowledgebase/general-port-forwarding-guide/>

## Starting the Validator

After the installation process completes, you can start the validator using either the web-based dashboard or the command line:

Using Web Dashboard:

- Open a web browser and navigate to the web dashboard at `localhost:8080` or ServerIP:8080
- Enter the password you set during the installation process.
- Click the `Start Node` button in the top right white box.
- Once the validator has started, connect your wallet.

Using Command Line:

- Open a terminal and navigate to the Shardeum home directory (`$HOME/.shardeum`).
- Enter the validator container with `./shell`.
- In the container, run `operator-cli start` to start the validator node.

### Add the network to wallet

Open the page <https://docs.shardeum.org/docs/network/endpoints> and use the setting for the Atomium network.

### Get some coins from the faucet

[Join the Shardeum Discord](https://discord.gg/shardeum) and claim tokens from the faucet Channel by running the `/faucet <account>` command.

### Start your validator node

- Open a web browser and navigate to the web dashboard at `localhost:8080` or ServerIP:8080 (or the port you picked)
- Click the `Start Node` button.

### Stake SHM

Connect the wallet and stake 10 SHM.

Now check your node status, if your node status is on `Standby` and you have 10 SHM or more staked, your validator node is setup correctly. The network will automatically add your validator to be active in the network. The time to be added as an active validator will vary based on network load and validators in the network.

## Stack management

### Start the stack

```bash
./docker-up.sh
```

This will be more effective when the info gathered in the install script is stored in persisent volume that is mounted by the container.

### Stop the stack

```bash
./docker-down.sh
```

### Clean up

```bash
./clean.sh
```

This will clean up the last (lastest) build. Just meant to save a few key strokes.

Instructions for the user wanting to run a Shardeum validator node can be found here: <https://docs.shardeum.org/docs/node/run/validator>

## Versioning

To set up the dashboard installer script for different versions of the Shardeum network follow the steps below:

- Point the installer to the correct CLI and GUI versions in [the entrypoint.sh](https://github.com/shardeum/validator-dashboard/blob/d366e0fbf53ca7e8efb7f7d4aa1db4de7574657e/entrypoint.sh#L25) file.
- Set the right docker image version in the [Dockerfile](https://github.com/shardeum/validator-dashboard/blob/d366e0fbf53ca7e8efb7f7d4aa1db4de7574657e/Dockerfile#L1). You can find all tagged image versions [here](https://github.com/shardeum/shardeum/pkgs/container/server/versions?filters%5Bversion_type%5D=tagged).
- The installer script creates a `.env` file that [defines the network details](https://github.com/shardeum/validator-dashboard/blob/d366e0fbf53ca7e8efb7f7d4aa1db4de7574657e/installer.sh#L540-L589), modify the script to specify the details of the new network.
  The script should now correctly set up the Dashboard for your new network.

## Contributing

Contributions are very welcome! Everyone interacting in our codebases, issue trackers, and any other form of communication, including chat rooms and mailing lists, is expected to follow our [code of conduct](./CODE_OF_CONDUCT.md) so we can all enjoy the effort we put into this project.

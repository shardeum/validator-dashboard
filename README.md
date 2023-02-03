# HOW TO Install and Run a Shardeum Validator node

1. Prerequisites: Ensure `docker` and `docker-compose` are installed on your machine and included in the path of your shell:

	__docker__: https://docs.docker.com/engine/install/  
	__docker-compose__: https://docs.docker.com/compose/install/

2. Make sure you have either 'curl' or 'wget' installed.

    _Install 'curl' through your distro's package manager or get it from here: https://curl.se/download.html_

    _Or you can install 'wget' through your distro's package manager or get it from here: https://www.gnu.org/software/wget/_

3. Use one of the following commands to download and run the install script:

	_If you have `curl`_
	```
	curl -O https://gitlab.com/shardeum/validator/dashboard/-/raw/main/installer.sh && chmod +x installer.sh && ./installer.sh
	```

	_If you have `wget`_
	```
	wget https://gitlab.com/shardeum/validator/dashboard/-/raw/main/installer.sh && chmod +x installer.sh && ./installer.sh
	```

4. Follow the steps of the installer script to finish setup. Be sure to enter the correct Archiver and Monitor IP's of the network you want your validator to join. The IPs will be posted here: https://docs.shardeum.org/node/run/validator

5. If you are behind a router, ensure ports `9001` and `10001` are forwarded.  
	https://www.noip.com/support/knowledgebase/general-port-forwarding-guide/

6. Once the installer finishes, start the validator through either the web-based dashboard or command line:

	__Web Dashboard__

	1. Open a web browser and navigate to the web dashboard at `localhost:8080` or ServerIP:8080
	2. Go to the `Maintenance` tab and click the `Start Node` button.
	3. Go to the `Settings` tab and connect a wallet.

	__Command Line__

	1. Open a terminal and navigate to the Shardeum home directory (`$HOME/.shardeum`).
	2. Enter the validator container with `./shell`.
	3. In the container, run `operator-cli start` to start the validator node.

7. Add the network to wallet
	1. Open the page https://docs.shardeum.org/network/endpoints
	2. Use the setting for the Sphinx network.

8. Get some coins from the faucet
	* https://faucet-sphinx.shardeum.org/
    * Go the the above faucet URL and enter the address from your wallet to get some coins.

7. Start your validator node
	1. Open a web browser and navigate to the web dashboard at `localhost:8080` or ServerIP:8080 (or the port you picked)
	2. Go to the `Maintenance` tab and click the `Start Node` button.

8. Stake coins
    1. Go to the 'Maintenance' tab and connect the wallet and stake 10 coins.

9. Check that your node status is 'Standby'.

## Stack management
### Start the stack:
```
./docker-up.sh
```
#### This will be more effective when the info gathered in the install script is stored in persisent volume that is mounted by the container.

### Stop the stack:
```
./docker-down.sh
```

### Clean up
```
./clean.sh
```
#### this will clean up the last (lastest) build. Just meant to save a few key strokes.

# TODO

## User Experience
Instructions for the user wanting to run a Shardeum validator node will be:

### Initial Install
* Setup Docker on the machine that will be running the Shardeum validator (link to more info)
* From the command line run this command while logged in as the user that can run Docker commands
	curl URL | sh

Answer the questions to specify where the validator will save files and what ports it uses

If you chose to start the GUI you should have been given the URL to access it and set the password

### Start the GUI Manually

If you did not start the GUI or stopped it, you can start it again by following these steps

``` 
./shell.sh

operator-cli gui start
```

If the above command fails with an error that you have not set the GUI access password, run

```
operator-cli gui password
```

### Start or Stop the Validator Manually
```
./shell.sh

operator-cli status
operator-cli start
operator-cli stop
```

### Update the Validator software along with the Dashboard

Be sure that your validator is not participating in the network
```
./shell.sh

operator-cli status
operator-cli disable
```

This will set the Validator to not join the network after it has exited

Once it has exited, it will not try to rejoin since it has been disabled
```
./update.sh
```
This will stop the validator, remove the docker image, pull the current stable image and start the image; it will not need to ask questions about where to store the files and what ports to use since it will use the same settings as before

## Need to add instructions for Staking

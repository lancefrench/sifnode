#!/bin/bash
# must run from the root directory of the sifnode tree

set -e # exit on any failure

BASEDIR=$(pwd)/$(dirname $0)/../..
NETWORKDIR=$BASEDIR/deploy/networks
CONTAINER_NAME="integration_sifnode1_1"

#
# Remove prior generations Config
#
echo "apologies for this sudo, it is to delete non-persisent cryptographic keys that usually has enhanced permissions"
sudo rm -rf $NETWORKDIR && mkdir $NETWORKDIR
rm -rf ${BASEDIR}/smart-contracts/build ${BASEDIR}/smart-contracts/.openzeppelin
make -C ${BASEDIR} install

# ===== Everything from here on down is executed in the $BASEDIR/smart-contracts directory
cd $BASEDIR/smart-contracts

# Startup ganache-cli (https://github.com/trufflesuite/ganache)

yarn --cwd $BASEDIR/smart-contracts install

docker-compose --project-name genesis -f $BASEDIR/test/integration/docker-compose-ganache.yml up -d

# deploy peggy smart contracts
if [ ! -f .env ]; then
  # if you haven't created a .env file, use .env.example
  cp .env.example .env
fi

# https://www.trufflesuite.com/docs/truffle/overview
# and note that truffle migrate and truffle deploy are the same command
truffle compile
truffle deploy --network develop --reset
ETHEREUM_CONTRACT_ADDRESS=$(cat $BASEDIR/smart-contracts/build/contracts/BridgeRegistry.json | jq '.networks["5777"].address')
if [ -z "$ETHEREUM_CONTRACT_ADDRESS" ]; then
  echo ETHEREUM_CONTRACT_ADDRESS cannot be empty
  exit 1
fi

#
# scaffold and boot the dockerized localnet
#
BASEDIR=${BASEDIR} rake genesis:network:scaffold['localnet']
BASEDIR=${BASEDIR} rake genesis:network:boot["localnet,${ETHEREUM_CONTRACT_ADDRESS},ae6ae8e5ccbfb04590405997ee2d52d2b330726137b875053c36d94e974d162f,ws://192.168.2.6:7545/"]

# those rake commands generate yaml that provides useful usernames and passwords
# wait for it to appear

NETDEF=$NETWORKDIR/network-definition.yml
while [ ! -f $NETWORKDIR/network-definition.yml ]
do
  sleep 2
done

PASSWORD=$(cat $NETDEF | yq r - ".password")
ADDR=$(cat $NETDEF | yq r - ".address")
echo $PASSWORD
echo $ADDR

#
# Add keys for a second account to test functions against
#
docker exec ${CONTAINER_NAME} bash -c "/test/integration/add-second-account.sh"

#
# Wait for the Websocket subscriptions to be initialized (like 10 seconds)
#
docker logs -f ${CONTAINER_NAME} | grep -m 1 "Subscribed"

#
# Transfer Eth into Ceth in our validator account
#
yarn --cwd $BASEDIR/smart-contracts peggy:lock ${ADDR} 0x0000000000000000000000000000000000000000 17

#
# Transfer Eth into Ceth on our User account 
# This also makes the account visible to sifnodecli q auth account <addr>

USER1ADDR=$(cat $NETDEF | yq r - "[1].address")
echo $USER1ADDR
sleep 5
yarn --cwd $BASEDIR/smart-contracts peggy:lock ${USER1ADDR} 0x0000000000000000000000000000000000000000 19
sleep 5

#
# Transfer Rowan from validator account to user account
#
docker exec ${CONTAINER_NAME} bash -c "/test/integration/add-rowan-to-second-account.sh 23"
sleep 5

#
# Run the python tests
#
docker exec ${CONTAINER_NAME} bash -c "bash /test/integration/start-ganache-port-forwarding.sh"
docker exec ${CONTAINER_NAME} bash -c "cd /smart-contracts && yarn install"
docker exec ${CONTAINER_NAME} bash -c "SMART_CONTRACTS_DIR=/smart-contracts python3 /test/integration/peggy-basic-test-docker.py /network-definition.yml"

# killing script will not end network use stop-integration-env.sh for that
# and note that we just allow the github actions environment to be cleaned
# up by their scripts

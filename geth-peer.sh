#!/bin/sh

set -x

RETRIES=${RETRIES:-40}
VERBOSITY=${VERBOSITY:-6}

# get the genesis file from the deployer
curl \
    --fail \
    --show-error \
    --silent \
    --retry-connrefused \
    --retry $RETRIES \
    --retry-delay 5 \
    $ROLLUP_STATE_DUMP_PATH \
    -o genesis.json

# import the key that will be used to locally sign blocks
# this key does not have to be kept secret in order to be secure
# we use an insecure password ("pwd") to lock/unlock the password
echo "Importing private key"
echo $BLOCK_SIGNER_KEY >key.prv
echo "pwd" >password
geth account import --password ./password ./key.prv

# initialize the geth node with the genesis file
echo "Initializing Geth node"
geth --verbosity="$VERBOSITY" "$@" init genesis.json

# get the main node's enode
JSON='{"jsonrpc":"2.0","id":0,"method":"admin_nodeInfo","params":[]}'
NODE_INFO=$(curl --silent --fail --show-error -H "Content-Type: application/json" --retry-connrefused --retry $RETRIES --retry-delay 3 -d $JSON $L2_URL)

NODE_ENODE=$(echo $NODE_INFO | jq -r '.result.enode')
NODE_IP=$(echo $NODE_INFO | jq -r '.result.ip')

if [ "$NODE_IP" = "127.0.0.1" ]; then
    NODE_ENODE=${NODE_ENODE//127.0.0.1/$L2_HOST_IP}
fi

echo "[\"$NODE_ENODE\"]" >$DATADIR/static-nodes.json

# start the geth peer node
echo "Starting Geth peer node"
exec geth \
    --datadir "$DATADIR" \
    --verbosity="$VERBOSITY" \
    --password ./password \
    --allow-insecure-unlock \
    --unlock $BLOCK_SIGNER_ADDRESS \
    --mine \
    --miner.etherbase $BLOCK_SIGNER_ADDRESS \
    --syncmode full \
    --gcmode archive \
    "$@"

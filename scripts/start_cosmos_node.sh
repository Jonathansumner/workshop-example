#!/bin/sh

set -ex

# this script start a cosmos chain abstracting away its underlying binary or token denomination
# it creates an account `validator` and a user account `account1` with some funds
# as well as allocating some tokens to the given relayer account address

BINARY=${BINARY:-fetchd}

DENOM=${DENOM:-atestfet}
CHAIN_ID=${CHAIN_ID:-fetchchain}
MONIKER=${MONIKER:-node001}

# number of user accounts to create
NUM_AUTOGEN_ACCOUNTS=${NUM_AUTOGEN_ACCOUNTS:-0} 

VALIDATOR_MNEMONIC=${VALIDATOR_MNEMONIC:-} # autogenerated if blank
EXTRA_GENESIS_ACCOUNTS=${EXTRA_GENESIS_ACCOUNTS:-}

SET_CUSTOM_CONSENSUS_PARAMS=${SET_CUSTOM_CONSENSUS_PARAMS:-0}

if [ ! -f "$(find ~ -name genesis.json)" ]; then
  ${BINARY} init --chain-id "${CHAIN_ID}" "$MONIKER"

  # client config
  ${BINARY} config keyring-backend test
  ${BINARY} config output json
  ${BINARY} config chain-id "${CHAIN_ID}"
  
  # genesis override
  HOME_DIR=$(dirname "$(dirname "$(find ~ -name genesis.json)")")
  sed -i "s/\"stake\"/\"${DENOM}\"/" "${HOME_DIR}/config/genesis.json"
  # Enable rest API
  sed -i '/^\[api\]$/,/^\[/ s/^enable = false/enable = true/' "${HOME_DIR}/config/app.toml"
  # Allow all origins on RPC endpoint
  sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/' "${HOME_DIR}/config/config.toml"
  # update the block parameters to match mainnet
  if [ "${SET_CUSTOM_CONSENSUS_PARAMS}" -ne 0 ]; then
    cp "${HOME_DIR}/config//genesis.json" "${HOME_DIR}/config/genesis.json.bak"
    jq '.consensus_params.block.max_gas = "3000000" | .consensus_params.block.max_bytes = "300000" | .consensus_params.evidence.max_bytes = "300000"' "${HOME_DIR}/config/genesis.json.bak" > "${HOME_DIR}/config//genesis.json"
  fi
 
  # create validator account from mnemonic if provided or autogenerate otherwise
  if [ -n "${VALIDATOR_MNEMONIC}" ]; then
    echo "${VALIDATOR_MNEMONIC}" | ${BINARY} --keyring-backend "test" keys add validator --recover
  else
    ${BINARY} --keyring-backend "test" keys add validator
  fi
  VAL_ADDR=$(${BINARY} keys show validator -a)
  echo "Created validator: ${VAL_ADDR}"
  ${BINARY} add-genesis-account "${VAL_ADDR}" "1000000000000000000000000${DENOM}"

  # autogenerate given number of keys and genesis accounts
  for i in $(seq "${NUM_AUTOGEN_ACCOUNTS}"); do
    ADDR=$(${BINARY} --keyring-backend "test" keys add "account${i}" | grep address | awk '{print $2}')
    echo "Created account${i}: ${ADDR}"

    ${BINARY} add-genesis-account --keyring-backend "test" "${ADDR}" "1000000000000000000000000${DENOM}" 
  done

  # create genesis accounts from list of space of newline separated account string "<address>:<amount><denom>,<denom2> <address2>:<amount2><denom3>..."
  if [ -n "${EXTRA_GENESIS_ACCOUNTS}" ]; then
    echo "${EXTRA_GENESIS_ACCOUNTS}" | tr ' ' '\n' | while read -r account; do
      if [ -n "${account}" ]; then
        ${BINARY} add-genesis-account --keyring-backend "test" "$(echo "${account}" | awk -F: '{print $1}')" "$(echo "${account}" | awk -F: '{print $2}')"
      fi
    done
  fi

  ${BINARY} gentx --keyring-backend "test" validator "1000000000000000000${DENOM}" --chain-id="${CHAIN_ID}" --amount="1000000000000000000${DENOM}" 

  ${BINARY} collect-gentxs
else
  echo "genesis.json already exists, starting chain..."
fi

${BINARY} start --rpc.laddr tcp://0.0.0.0:26657 --grpc.enable --grpc.address 0.0.0.0:9090
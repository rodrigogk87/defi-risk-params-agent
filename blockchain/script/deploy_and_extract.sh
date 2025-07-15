#!/bin/bash

set -e

echo "⚡️ Running Forge deploy..."

forge script script/Deploy.s.sol --fork-url http://localhost:8545 --broadcast

echo "✅ Deploy finished."

# Paths
BROADCAST_JSON="./broadcast/Deploy.s.sol/31337/run-latest.json"
OUTPUT_JSON="./script/addresses.json"

# Check if jq is installed
if ! command -v jq &> /dev/null
then
    echo "❌ jq is not installed. Please install it (brew install jq)."
    exit 1
fi

echo "📄 Extracting contract addresses..."

jq '[
  .transactions[]
  | select(.contractAddress != null)
  | select(.contractName != null and .contractName != "")
]
| unique_by(.contractAddress)
| map({contract: .contractName, address: .contractAddress})' "$BROADCAST_JSON" > "$OUTPUT_JSON"

echo "✅ Addresses saved to $OUTPUT_JSON"
echo "📁 Moving addresses.json to shared volume path..."
mkdir -p /app/blockchain/script
cp ./script/addresses.json /app/blockchain/script/addresses.json

echo "📄 Copying compiled artifacts to /app/blockchain/out..."
mkdir -p /app/blockchain/out
cp -r ./out/* /app/blockchain/out/
echo "✅ Artifacts copied."

touch /app/script/deploy_done.flag

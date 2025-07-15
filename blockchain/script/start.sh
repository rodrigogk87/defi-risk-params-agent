#!/bin/bash
set -e

echo "🚀 Starting Anvil..."
anvil --port 8545 --host 0.0.0.0 &
ANVIL_PID=$!

echo "⏳ Waiting for Anvil to be ready..."
sleep 5

echo "⚡ Running deploy_and_extract.sh..."
bash script/deploy_and_extract.sh
sleep 5

echo "✅ Blockchain setup complete. Keeping container alive..."
wait $ANVIL_PID

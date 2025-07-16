#!/bin/sh
set -e

echo "👉 Starting Ollama server in background..."
ollama serve &

echo "⏳ Waiting a few seconds for Ollama to start..."
sleep 5

echo "⬇️ Pulling model gemma3:1b ..."
ollama pull gemma3:1b

echo "✅ Model downloaded. Waiting for Ollama process..."
# Esperar el proceso ollama serve sin usar -n
wait


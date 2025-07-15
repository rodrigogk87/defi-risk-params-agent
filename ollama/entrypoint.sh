#!/bin/bash

# Start ollama server in background
ollama serve &
# Esperar un poco a que levante
sleep 5

# Pull el modelo
ollama pull qwen2:7b

# Esperar al server para no terminar el script
wait

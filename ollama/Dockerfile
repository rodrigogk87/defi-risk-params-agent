FROM ollama/ollama

# Copiar el script de entrada
COPY entrypoint.sh /entrypoint.sh

# Dar permisos de ejecución
RUN chmod +x /entrypoint.sh

# Usar el entrypoint personalizado
ENTRYPOINT ["/entrypoint.sh"]
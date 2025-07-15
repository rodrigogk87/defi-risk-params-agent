FROM ghcr.io/foundry-rs/foundry:latest

WORKDIR /app

COPY . .

USER root
RUN apt-get update && apt-get install -y jq

EXPOSE 8545

# copiar el script healthcheck y darle permisos en el Dockerfile
COPY script/healthcheck.sh /app/script/healthcheck.sh
RUN chmod +x /app/script/healthcheck.sh

# Copiar script entrypoint
COPY script/start.sh /app/script/start.sh
RUN chmod +x /app/script/start.sh

CMD ["/app/script/start.sh"]

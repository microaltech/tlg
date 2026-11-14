# Server sosial Tuan Nusantara.
#   docker build -t tlg-server server/
#   docker run -d -p 8080:8080 -v tlg-data:/data -e ADMIN_TOKEN=... tlg-server
# Lebih lengkap (HTTPS otomatis + cadangan): docker compose -f server/docker-compose.yml up -d
FROM node:22-alpine
WORKDIR /app
COPY *.js admin.html ./
ENV PORT=8080 DB_PATH=/data/tlg.db BACKUP_DIR=/data/backups NODE_NO_WARNINGS=1
VOLUME /data
EXPOSE 8080
HEALTHCHECK --interval=60s CMD wget -qO- http://127.0.0.1:8080/status | grep -q '"ok":true' || exit 1
CMD ["node", "server.js"]

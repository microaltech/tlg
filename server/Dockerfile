# Server sosial Top Lord Like.
#   docker build -t tlg-server server/
#   docker run -d -p 8080:8080 -v tlg-data:/data tlg-server
FROM node:22-alpine
WORKDIR /app
COPY server.js ./
ENV PORT=8080 DB_PATH=/data/tlg.db NODE_NO_WARNINGS=1
VOLUME /data
EXPOSE 8080
HEALTHCHECK CMD wget -qO- http://127.0.0.1:8080/health || exit 1
CMD ["node", "server.js"]

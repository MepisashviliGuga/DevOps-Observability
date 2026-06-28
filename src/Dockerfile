FROM node:18-alpine

RUN apk add --no-cache wget

WORKDIR /app

COPY package.json ./
RUN npm install --production && npm cache clean --force

COPY index.js ./

RUN mkdir -p /app/logs && \
    addgroup -S appgroup && \
    adduser -S appuser -G appgroup && \
    chown -R appuser:appgroup /app

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q -O- http://localhost:3000/health || exit 1

CMD ["node", "index.js"]

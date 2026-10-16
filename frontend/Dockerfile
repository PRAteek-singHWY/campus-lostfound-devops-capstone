# syntax=docker/dockerfile:1
# Stage 1: build the static bundle with Node
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install --no-audit --no-fund
COPY . .
RUN npm run build

# Stage 2: serve it with nginx; Node never reaches the final image
FROM nginxinc/nginx-unprivileged:1.29-alpine
USER 0
# pull patched OS packages (Trivy gate: CVE-2026-31789 in openssl, CVE-2026-33630 in c-ares)
RUN apk upgrade --no-cache && apk add --no-cache curl
ENV BACKEND_HOST=backend BACKEND_PORT=8000
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
USER 101
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD ["curl", "-fs", "http://localhost:8080/healthz"]

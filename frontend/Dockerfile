# syntax=docker/dockerfile:1
# Stage 1: build the static bundle with Node
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install --no-audit --no-fund
COPY . .
RUN npm run build

# Stage 2: serve it with nginx; Node never reaches the final image
FROM nginx:1.27-alpine
RUN apk add --no-cache curl
ENV BACKEND_HOST=backend BACKEND_PORT=8000
COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD curl -fs http://localhost/healthz || exit 1

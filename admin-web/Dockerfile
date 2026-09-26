# ==============================================================================
# Multi-Stage Dockerfile for Admin Web Dashboard (Flutter Web + Nginx Alpine)
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Flutter Build
# ------------------------------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Copy dependency definition and download packages
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source code
COPY . .

# Build production bundle with CanvasKit renderer
ARG API_BASE_URL=http://localhost:8080
RUN flutter build web --release --web-renderer canvaskit --dart-define=API_BASE_URL=${API_BASE_URL}

# ------------------------------------------------------------------------------
# Stage 2: Nginx Runtime
# ------------------------------------------------------------------------------
FROM nginx:alpine

# Remove default nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy built web artifacts from builder stage
COPY --from=builder /app/build/web /usr/share/nginx/html

# Copy custom Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

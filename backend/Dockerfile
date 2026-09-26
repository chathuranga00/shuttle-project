# ==============================================================================
# Multi-Stage Dockerfile for University Shuttle Spring Boot Backend (Java 21)
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Maven Build Stage
# ------------------------------------------------------------------------------
FROM maven:3.9.9-eclipse-temurin-21-jammy AS builder

WORKDIR /build

# Cache Maven dependencies layer
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy application source code and compile production JAR
COPY src ./src
RUN mvn clean package -DskipTests -B

# ------------------------------------------------------------------------------
# Stage 2: Production JRE Runtime Stage
# ------------------------------------------------------------------------------
FROM eclipse-temurin:21-jre-jammy

# Install curl for Docker healthcheck and ca-certificates
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates tzdata && \
    rm -rf /var/lib/apt/lists/*

# Set default timezone to UTC
ENV TZ=UTC

# Create an unprivileged system user and group for security
RUN groupadd -r shuttle && useradd -r -g shuttle -m -d /home/shuttle shuttle

WORKDIR /app

# Create log directory and set permissions
RUN mkdir -p /app/logs && chown -R shuttle:shuttle /app

# Copy the fat executable jar from the builder stage
COPY --from=builder --chown=shuttle:shuttle /build/target/shuttle-backend-*.jar /app/app.jar

# Switch to unprivileged user
USER shuttle

# Expose HTTP port
EXPOSE 8080

# Configure container health check using Spring Boot Actuator
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1

# Tuned container JVM options:
# - MaxRAMPercentage=75 respects cgroup memory limits
# - G1GC for low latency
# - ExitOnOutOfMemoryError ensures orchestrator restarts a deadlocked heap
ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError -Djava.security.egd=file:/dev/./urandom"

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]

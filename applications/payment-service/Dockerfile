# Payment Service Dockerfile
# Save as: apps/payment-service/Dockerfile

FROM eclipse-temurin:17-jdk AS builder

WORKDIR /app
COPY pom.xml .
COPY src ./src

# Download dependencies
RUN apt-get update && apt-get install -y maven
RUN mvn dependency:go-offline -B

# Build the application
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jdk

WORKDIR /app

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Install curl for health checks
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/* 

# Copy the jar file
COPY --from=builder /app/target/payment-service-*.jar app.jar

# Change ownership to appuser
RUN chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/api/v1/payments/health || exit 1

# Expose port
EXPOSE 8080

# JVM optimization for containers
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
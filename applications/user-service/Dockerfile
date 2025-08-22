# Build stage
FROM maven:3.9-amazoncorretto-17 AS builder

WORKDIR /build
COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src ./src
RUN mvn clean package -DskipTests -B

# Production stage
FROM amazoncorretto:17

WORKDIR /app
COPY --from=builder /build/target/*.jar app.jar

EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
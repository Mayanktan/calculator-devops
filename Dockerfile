# ============================================================
# Stage 1 — BUILD: compile the JAR using Maven + JDK 21
# ============================================================
FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace

# Copy only pom.xml first so the dependency layer is cached
# until pom.xml changes.
COPY pom.xml .
RUN mvn -B -ntp dependency:go-offline

# Source changes only invalidate the layers from here down.
COPY src ./src
RUN mvn -B -ntp clean package -DskipTests

# ============================================================
# Stage 2 — RUNTIME: slim JRE, just enough to run the JAR
# ============================================================
FROM eclipse-temurin:21-jre-alpine

# Non-root user and group
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app

# Copy ONLY the built JAR out of the build stage
COPY --from=build --chown=app:app /workspace/target/calculator-devops-*.jar /app/app.jar

EXPOSE 8080
USER app

# Exec form: Java runs as PID 1, so 'docker stop' signals reach it.
# JVM flags come from JAVA_TOOL_OPTIONS (set in docker-compose.yml).
ENTRYPOINT ["java", "-jar", "/app/app.jar"]

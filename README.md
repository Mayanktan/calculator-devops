# Calculator DevOps

End-to-end CI/CD pipeline for a Spring Boot Calculator REST API.
CSE 816 Software Production Engineering — Mini-Project.

## Features

- Spring Boot 3.3 REST API: `/api/v1/{add,subtract,multiply,divide,power}`
- Validated inputs; HTTP 400 + JSON error for missing/invalid params and divide-by-zero
- JUnit 5 unit tests + Spring MockMvc integration tests
- `/actuator/health` probe
- Multi-stage Dockerfile (Maven/JDK build → slim JRE runtime), non-root user
- Docker Compose stack: app + Nginx reverse proxy on a shared network, health-check driven startup
- Jenkins declarative pipeline: Checkout → Build → Test → Docker Build → Push → Deploy
- GitHub webhook trigger + email notifications
- Docker Hub image publishing with per-build tags

## Project layout

```
calculator-devops/
├── src/main/java/com/example/calculator/
│   ├── CalculatorApplication.java
│   ├── controller/CalculatorController.java
│   ├── service/CalculatorService.java
│   ├── dto/{CalculationResponse,ApiError}.java
│   └── exception/{DivideByZeroException,GlobalExceptionHandler}.java
├── src/main/resources/application.properties
├── src/test/java/com/example/calculator/
│   ├── CalculatorServiceTest.java     # unit tests
│   └── CalculatorControllerIT.java    # MockMvc integration tests
├── pom.xml
├── Dockerfile
├── .dockerignore
├── docker-compose.yml
├── nginx/nginx.conf
├── Jenkinsfile
└── scripts/preflight.sh
```

## Prerequisites

JDK 21, Maven 3.9+, Docker with Compose v2.17+, Jenkins LTS.

`java -version` must show 21. On a Homebrew Mac: `export JAVA_HOME=/opt/homebrew/opt/openjdk@21`.

## Build and test

```bash
mvn clean package     # builds target/calculator-devops-1.0.0.jar
mvn test              # JUnit 5 tests; XML reports in target/surefire-reports/
```

## Run locally

```bash
mvn spring-boot:run   # http://localhost:8080
```

## Run with Docker

```bash
docker build -t mayanktan/calculator-devops:1.0.0 .
docker run --rm -d -p 8080:8080 --name calc mayanktan/calculator-devops:1.0.0
curl 'http://localhost:8080/api/v1/add?a=2&b=3'
docker stop calc
```

## Run the full stack (Compose)

```bash
docker compose up -d --build
docker compose ps                     # calculator should be (healthy)
curl 'http://localhost/api/v1/add?a=10&b=5'
docker compose down
```

Only Nginx publishes a port (80). The app's port 8080 is internal to the `calc-net` network.

## Endpoints

| Method | Path                       | Example                                  |
|--------|----------------------------|------------------------------------------|
| GET    | `/api/v1/add?a=&b=`        | `/api/v1/add?a=2&b=3` → 5                |
| GET    | `/api/v1/subtract?a=&b=`   | `/api/v1/subtract?a=5&b=2` → 3           |
| GET    | `/api/v1/multiply?a=&b=`   | `/api/v1/multiply?a=4&b=3` → 12          |
| GET    | `/api/v1/divide?a=&b=`     | `/api/v1/divide?a=10&b=2` → 5 (b=0 → 400)|
| GET    | `/api/v1/power?a=&b=`      | `/api/v1/power?a=2&b=10` → 1024          |
| GET    | `/actuator/health`         | `{"status":"UP",...}`                    |

Success response:

```json
{"operation":"add","a":2.0,"b":3.0,"result":5.0}
```

Error response (HTTP 400):

```json
{"timestamp":"2026-10-28T10:00:00Z","status":400,"error":"Bad Request",
 "message":"Cannot divide by zero","path":"/api/v1/divide"}
```

## Pipeline

On every push to `main` (GitHub webhook, or Poll SCM `H/2 * * * *`):

1. **Checkout** — pull the latest code
2. **Build** — `mvn clean package -DskipTests`
3. **Test** — `mvn test`; JUnit XML published, build fails on test failure
4. **Docker Build** — image tagged `:${BUILD_NUMBER}` and `:latest`
5. **Push** — Docker Hub, using the Jenkins credential `dockerhub-creds`
6. **Deploy** — `docker compose up -d --wait`; verify `/actuator/health` through Nginx

Build status is emailed on success and failure (Email Extension plugin, SMTP set up in Jenkins).

### Jenkins setup

- Plugins: Pipeline, Git, Docker Pipeline, Credentials Binding, JUnit, Email Extension, GitHub Integration, Timestamper.
- Credentials: `dockerhub-creds` (Username with password — Docker Hub username + access token).
- Job: Pipeline script from SCM → this repo, branch `*/main`, script path `Jenkinsfile`.
- Trigger: "GitHub hook trigger for GITScm polling" (webhook URL `https://<public-jenkins>/github-webhook/`).
- Edit `DOCKERHUB_USER` and `NOTIFY_EMAIL` at the top of the `Jenkinsfile`.
- Run Jenkins directly on the Docker host, not inside a container: Deploy mounts `nginx/nginx.conf`
  from the workspace and checks `http://localhost`.
- The agent needs JDK 21 as `JAVA_HOME`, plus `mvn`, `docker` and `curl` on `PATH`
  (set them under Manage Jenkins → System → Global properties → Environment variables if needed).

## Pre-demo check

```bash
./scripts/preflight.sh   # stops at the first failed check; args: [github-user] [dockerhub-user] [jenkins-url]
```

## Links

- GitHub: https://github.com/Mayanktan/calculator-devops
- Docker Hub: https://hub.docker.com/r/mayanktan/calculator-devops

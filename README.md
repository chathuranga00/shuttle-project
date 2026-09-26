# University Shuttle Management System

[![Spring Boot 3.5.5](https://img.shields.io/badge/Spring%20Boot-3.5.5-brightgreen.svg)](https://spring.io/projects/spring-boot)
[![Java 21](https://img.shields.io/badge/Java-21%20LTS-orange.svg)](https://www.oracle.com/java/)
[![Flutter 3.x](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev/)
[![MySQL 8.0](https://img.shields.io/badge/MySQL-8.0-blue.svg)](https://www.mysql.com/)
[![Docker Ready](https://img.shields.io/badge/Docker-Compose%20v2-2496ED.svg)](https://www.docker.com/)

A comprehensive, enterprise-grade campus shuttle management ecosystem designed for modern universities. The system provides real-time shuttle fleet coordination, student virtual smartcards, tamper-proof QR code boarding validation with pessimistic concurrency control, automated fare collection, digital wallets, monthly passes, and administrative fleet analytics.

---

## Architecture Overview

```
                                 [ University Community ]
                                            │
                        ┌───────────────────┴───────────────────┐
                        ▼                                       ▼
             [ Flutter Mobile App ]                  [ Flutter Admin Web ]
             • Student Virtual Card                  • Fleet & Bus Management
             • QR Code Boarding                      • Routes & Stops Setup
             • Digital Wallet & Passes               • Live Trip Coordination
             • Driver Duty & Trip Logs               • Revenue & Financial Audits
                        │                                       │
                        └───────────────────┬───────────────────┘
                                            ▼
                           [ Spring Boot 3 REST Backend ]
                           • Stateless JWT Authentication & Refresh
                           • Pessimistic Lock Concurrency (Double-Boarding Guard)
                           • HMAC-SHA256 Signed QR Generator & Validator
                           • Bucket4j Rate Limiting & Actuator Probes
                           • Flyway Schema Migrations
                                            │
                                            ▼
                               [ MySQL 8.0 Database ]
                               (InnoDB, utf8mb4, ACID)
```

---

## Repository Structure

```
shuttle-project/
├── backend/                  # Spring Boot 3 Backend (Java 21)
│   ├── src/main/java/        # Clean architecture (Controller, Service, Domain, Repo)
│   ├── src/main/resources/   # Application YAMLs, Flyway SQL migrations, Logback
│   ├── scripts/              # Automated database backup & restore shell scripts
│   └── Dockerfile            # Multi-stage production container build
├── mobile/                   # Flutter Mobile App (Android / iOS / Web)
│   ├── lib/                  # Riverpod state management, GoRouter, Dio
│   ├── assets/images/        # App icon, splash brand assets
│   └── android/              # Gradle Kotlin DSL, signing configuration
├── admin-web/                # Flutter Web Admin Dashboard
│   ├── lib/                  # Admin UI, tables, metrics, dispatch controls
│   ├── nginx.conf            # Production Nginx SPA & reverse proxy config
│   └── Dockerfile            # Multi-stage Flutter Web build + Nginx Alpine
├── docs/                     # Engineering Documentation
│   ├── DEPLOYMENT.md         # Production deployment, Docker, Nginx, SSL guide
│   ├── API.md                # Full REST API documentation from OpenAPI
│   ├── TEST_PLAN.md          # End-to-end lifecycle manual test script
│   └── SECURITY.md           # Security audit, IDOR, concurrency & rate-limit verification
├── docker-compose.yml        # Orchestration for Backend, MySQL & Admin Web
└── .env.example              # Environment variables template
```

---

## Quickstart with Docker Compose

The fastest way to spin up the entire platform (MySQL 8.0, Spring Boot backend, and Admin Web):

### 1. Clone & Configure Environment
```bash
cp .env.example .env
```
*(Optionally review `.env` for custom database passwords or ports).*

### 2. Launch Containers
```bash
docker compose up -d --build
```

### 3. Verify Health
```bash
docker compose ps
```
The services will be accessible at:
* **Backend API**: `http://localhost:8080`
* **Health Check**: `http://localhost:8080/actuator/health`
* **Swagger UI Documentation**: `http://localhost:8080/swagger-ui.html`
* **Admin Web Dashboard**: `http://localhost:8081`

---

## Manual Local Development Setup

### 1. Prerequisites
* **Java 21 LTS** & **Maven 3.9+**
* **MySQL 8.0** running locally on port `3306` (or `3308`)
* **Flutter SDK 3.13+**

### 2. Database Preparation
Create the MySQL database:
```sql
CREATE DATABASE shuttle_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 3. Start Backend
```bash
cd backend
mvn spring-boot:run
```
Flyway automatically applies all 10 SQL migrations and seeds demo data (routes, stops, bus `BUS-001`, and default credentials).

### 4. Run Mobile App
```bash
cd mobile
flutter pub get
flutter run
```
*Note: To target Chrome during development, run `flutter run -d chrome`.*

### 5. Run Admin Web Dashboard
```bash
cd admin-web
flutter pub get
flutter run -d chrome --web-port 8081
```

---

## Default Seed Credentials

| Role | Email | Password | Access Level |
|---|---|---|---|
| **Admin** | `admin@shuttle.dev` | `Admin@1234` | Full access to Admin Web & management endpoints |
| **Driver** | `driver@shuttle.dev` | `Driver@1234` | Driver dashboard, trip start/end, QR scanner, incidents |
| **Student** | `student@shuttle.dev` | `Student@1234` | Virtual bus card, wallet top-up, trip boarding, history |

---

## Quality Assurance & Testing

### Backend Unit & Integration Tests
Execute the comprehensive test suite (145 automated tests covering security, concurrency, pessimistic locking, rate limits, and transactions):
```bash
cd backend
mvn test
```

### Mobile Static Analysis & Tests
```bash
cd mobile
dart analyze lib
flutter test
```

### Admin Web Static Analysis
```bash
cd admin-web
dart analyze lib
```

---

## Release Building

### Android Release APK & AAB
Configure your keystore in `mobile/android/key.properties` (see [`mobile/android/key.properties.example`](file:///q:/MY%20Projects/shuttle%20project/mobile/android/key.properties.example)), then run:
```bash
cd mobile
flutter build apk --release --split-per-abi --dart-define=ENV=prod --dart-define=API_BASE_URL=https://api.shuttle.university.lk
flutter build appbundle --release --dart-define=ENV=prod --dart-define=API_BASE_URL=https://api.shuttle.university.lk
```

### Admin Web Production Build
```bash
cd admin-web
flutter build web --release --web-renderer canvaskit --dart-define=API_BASE_URL=https://api.shuttle.university.lk
```

---

## Detailed Documentation Links

* [**Deployment Guide (docs/DEPLOYMENT.md)**](file:///q:/MY%20Projects/shuttle%20project/docs/DEPLOYMENT.md): Detailed Docker, VPS, Nginx SSL, and database backup procedures.
* [**API Reference (docs/API.md)**](file:///q:/MY%20Projects/shuttle%20project/docs/API.md): Complete OpenAPI endpoint documentation and schemas.
* [**End-to-End Test Plan (docs/TEST_PLAN.md)**](file:///q:/MY%20Projects/shuttle%20project/docs/TEST_PLAN.md): Section 29 system lifecycle manual test execution script.
* [**Security Audit (docs/SECURITY.md)**](file:///q:/MY%20Projects/shuttle%20project/docs/SECURITY.md): Threat mitigation, concurrency control, and penetration verification notes.
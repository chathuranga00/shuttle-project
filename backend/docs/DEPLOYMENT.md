# University Shuttle Management System — Production & Staging Deployment Guide

This guide details the complete deployment lifecycle for the University Shuttle Management platform, including the Spring Boot backend, MySQL 8.0 database, Admin Web dashboard, and Flutter mobile applications.

---

## 1. System Architecture Overview

```
                                 [ Internet / Clients ]
                                           │
                        ┌──────────────────┴──────────────────┐
                        ▼                                     ▼
             [ Flutter Mobile Apps ]               [ Admin Web Dashboard ]
              (Android APK / AAB)                   (Nginx / Static SPA)
                        │                                     │
                        │   HTTPS / WSS                       │   HTTPS
                        └──────────────────┬──────────────────┘
                                           ▼
                            [ Nginx / Caddy Reverse Proxy ]
                              SSL Termination, HSTS, CORS
                                           │
                                           ▼ :8080
                            [ Spring Boot Backend (Java 21) ]
                             Actuator, Security, Flyway, JWT
                                           │
                                           ▼ :3306
                             [ MySQL 8.0 InnoDB Database ]
                              utf8mb4, Persistent Volume
```

---

## 2. Prerequisites

### Containerized Environment (Recommended)
* **Docker Engine** 24.0+
* **Docker Compose** v2.20+
* **OpenSSL** (for generating cryptographically secure JWT secrets)
* **Public Domain / DNS records** pointing to your host VM (e.g. `api.shuttle.university.lk`, `admin.shuttle.university.lk`)

### Bare-Metal / Native Environment
* **Java**: OpenJDK / Eclipse Temurin 21 LTS
* **Maven**: 3.9+
* **MySQL**: 8.0+
* **Flutter SDK**: 3.13+ (for building mobile & web frontends)
* **Android SDK**: API level 34, Android Build Tools 34.0.0

---

## 3. Environment Configuration & Secrets

Create a `.env` file at the repository root by copying `.env.example`:

```bash
cp .env.example .env
```

### Environment Variables Reference

| Variable | Description | Default / Example | Production Required |
|---|---|---|:---:|
| `SPRING_PROFILES_ACTIVE` | Spring Boot active profile (`dev` or `prod`) | `prod` | Yes |
| `SERVER_PORT` | Backend HTTP listening port | `8080` | Yes |
| `APP_BASE_URL` | Public base URL for payment callbacks | `https://api.shuttle.university.lk` | Yes |
| `DB_HOST` | Database hostname or Docker service name | `mysql` (Docker) or `127.0.0.1` | Yes |
| `DB_PORT` | Database port | `3306` | Yes |
| `DB_NAME` | Database schema name | `shuttle_db` | Yes |
| `DB_USERNAME` | MySQL user | `root` or dedicated application user | Yes |
| `DB_PASSWORD` | MySQL user password | *Strong random password* | Yes |
| `JWT_SECRET` | HMAC-SHA256 signature key (min 256 bits) | Generated via `openssl rand -base64 32` | Yes |
| `JWT_EXPIRATION_MS` | Access token lifespan in milliseconds | `900000` (15 minutes) | Yes |
| `JWT_REFRESH_EXPIRATION_MS` | Refresh token lifespan in milliseconds | `604800000` (7 days) | Yes |
| `ADMIN_SEED_EMAIL` | Default administrator account email | `admin@shuttle.dev` | Yes |
| `ADMIN_SEED_PASSWORD` | Initial admin account password | *Strong custom password* | Yes |
| `APP_CORS_ALLOWED_ORIGINS` | Comma-separated allowed Web origins | `https://admin.shuttle.university.lk` | Yes |
| `PAYMENT_GATEWAY` | Payment gateway driver (`mock` or `payhere`) | `payhere` | Yes |
| `PASS_MOCK_PAID` | Auto-activate monthly passes without gateway | `false` (Prod) / `true` (Dev) | Yes |
| `PAYHERE_MERCHANT_ID` | PayHere Merchant ID | From PayHere Merchant Portal | If PayHere |
| `PAYHERE_MERCHANT_SECRET` | PayHere Merchant Secret | From PayHere Merchant Portal | If PayHere |
| `PAYHERE_SANDBOX` | Use PayHere sandbox environment | `false` (Live) / `true` (Testing) | If PayHere |
| `FIREBASE_CONFIG_PATH` | Path to Google Service Account JSON | `/app/firebase-service-account.json` | Optional |

> [!IMPORTANT]
> To generate a secure 256-bit JWT secret:
> ```bash
> openssl rand -base64 32
> ```

---

## 4. Docker Compose Deployment (Local & Staging)

### Step 1: Start Services
Run the backend, MySQL database, and Admin Web dashboard in detached mode:

```bash
docker compose up -d --build
```

### Step 2: Monitor Startup & Health
Check the container health statuses:

```bash
docker compose ps
```

Expected output:
```
NAME                IMAGE                   STATUS                    PORTS
shuttle-mysql       mysql:8.0               Up (healthy)              0.0.0.0:3306->3306/tcp
shuttle-backend     shuttle-backend:latest  Up (healthy)              0.0.0.0:8080->8080/tcp
shuttle-admin-web   shuttle-admin-web:latest Up                       0.0.0.0:8081->80/tcp
```

### Step 3: Inspect Backend Logs
Ensure Flyway migrations executed cleanly up to version 10:

```bash
docker compose logs -f backend
```

Look for:
```
Successfully validated 10 migrations
Current version of schema "shuttle_db": 10
Schema "shuttle_db" is up to date. No migration necessary.
Exposing 2 endpoints beneath base path '/actuator'
```

### Step 4: Verify Actuator Health Endpoint
Test the health probe:

```bash
curl -i http://localhost:8080/actuator/health
```

Expected response:
```http
HTTP/1.1 200 OK
Content-Type: application/vnd.spring-boot.actuator.v3+json

{"status":"UP"}
```

---

## 5. Production Profile Configuration

When running with `SPRING_PROFILES_ACTIVE=prod`:
1. **Flyway Migrations**: Executed automatically upon application boot (`spring.flyway.baseline-on-migrate: true`).
2. **Database Pooling**: Tuned HikariCP connection pool (`max-pool-size: 20`, `min-idle: 5`, `leak-detection-threshold: 30000ms`).
3. **Hibernate SQL**: Disabled console SQL echoing (`spring.jpa.show-sql: false`) for performance and privacy.
4. **Actuator Health Probe**: Details are masked (`show-details: never`) to avoid exposing database topology while providing `{"status":"UP"}` for uptime checkers and load balancers.
5. **Reverse Proxy Headers**: `server.forward-headers-strategy=framework` enables standard `X-Forwarded-For` and `X-Forwarded-Proto` handling behind SSL termination proxies.
6. **Payment Gateway**: Strict signature validation against PayHere production webhooks with mock payments disabled.

---

## 6. Production Logging & Log Rotation

Structured logging is managed via [`backend/src/main/resources/logback-spring.xml`](file:///q:/MY%20Projects/shuttle%20project/backend/src/main/resources/logback-spring.xml).

### Logging Specifications
* **Active Appenders**:
  - `CONSOLE`: Formatted for Docker standard output / systemd journal.
  - `ASYNC_FILE`: Non-blocking asynchronous file appender writing to `${LOG_PATH}/shuttle-backend.log`.
* **Rolling Policy**: `SizeAndTimeBasedRollingPolicy`:
  - Daily rotation (`shuttle-backend.%d{yyyy-MM-dd}.%i.log.gz`)
  - Maximum single file size: **50 MB**
  - Retention window: **30 days**
  - Disk storage cap: **3 GB**
* **Log Levels**:
  - `com.shuttle`: `INFO`
  - `org.springframework.security`: `WARN`
  - `org.hibernate`: `WARN`

Logs are persisted inside the Docker named volume `shuttle_backend_logs` mapped to `/app/logs`.

---

## 7. Database Backup & Disaster Recovery

Consistent online backups are performed using MySQL's `--single-transaction` mode, creating zero locking on InnoDB tables.

### Automated Backup Script
The automated backup script is located at [`backend/scripts/backup.sh`](file:///q:/MY%20Projects/shuttle%20project/backend/scripts/backup.sh).

```bash
# Make executable
chmod +x backend/scripts/backup.sh

# Run manual backup
DB_PASSWORD="your_secure_password" ./backend/scripts/backup.sh
```

### Setup Daily Cron Job
On the production server, schedule daily backups at 02:00 AM UTC:

```bash
crontab -e
```

Add the following line:
```cron
0 2 * * * DB_PASSWORD="your_secure_password" /opt/shuttle/backend/scripts/backup.sh >> /var/log/shuttle_backup.cron.log 2>&1
```

### Disaster Recovery / Database Restore
To restore a database snapshot:

```bash
chmod +x backend/scripts/restore.sh
DB_PASSWORD="your_secure_password" ./backend/scripts/restore.sh /var/backups/shuttle/shuttle_backup_20260926_020000.sql.gz
```

---

## 8. Reverse Proxy & SSL Configuration

### Option A: Nginx Production Configuration

Place in `/etc/nginx/sites-available/shuttle`:

```nginx
# Rate limiting zone
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=30r/s;

# Backend API
server {
    listen 443 ssl http2;
    server_name api.shuttle.university.lk;

    ssl_certificate /etc/letsencrypt/live/api.shuttle.university.lk/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.shuttle.university.lk/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        limit_req zone=api_limit burst=20 nodelay;

        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;

        # WebSocket support for live tracking
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# Admin Web Dashboard
server {
    listen 443 ssl http2;
    server_name admin.shuttle.university.lk;

    ssl_certificate /etc/letsencrypt/live/admin.shuttle.university.lk/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/admin.shuttle.university.lk/privkey.pem;

    root /var/www/shuttle-admin-web;
    index index.html;

    types {
        application/wasm wasm;
    }

    location ~* \.(?:css|js|wasm|png|jpg|ico|svg|woff2?)$ {
        expires 7d;
        add_header Cache-Control "public, max-age=604800, immutable";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### Option B: Caddyfile (Automatic Let's Encrypt SSL)

```caddyfile
api.shuttle.university.lk {
    reverse_proxy 127.0.0.1:8080
}

admin.shuttle.university.lk {
    root * /var/www/shuttle-admin-web
    file_server
    try_files {path} /index.html
}
```

---

## 9. Flutter Mobile Release Build & Signing

### Step 1: Generate Android Upload Keystore
Generate a PKCS12 release keystore using Java's `keytool`:

```bash
keytool -genkey -v -keystore mobile/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias shuttle_release_key
```

### Step 2: Configure `key.properties`
Create `mobile/android/key.properties` (never commit this file to version control):

```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=shuttle_release_key
storeFile=../upload-keystore.jks
```

### Step 3: Verify App Icon & Splash Screen
The mobile application is pre-configured with custom brand assets (University Deep Navy `#1A3A6B` and Golden Amber `#F5A623`).
To regenerate if icons are changed:

```bash
cd mobile
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

### Step 4: Build Signed Release APK
Build universal or split per-ABI APKs:

```bash
cd mobile

# Split APKs (smaller download size per CPU architecture)
flutter build apk --release --split-per-abi \
  --dart-define=ENV=prod \
  --dart-define=API_BASE_URL=https://api.shuttle.university.lk

# Universal APK (single installer for all devices)
flutter build apk --release \
  --dart-define=ENV=prod \
  --dart-define=API_BASE_URL=https://api.shuttle.university.lk
```

Artifacts will be located at:
`mobile/build/app/outputs/flutter-apk/app-release.apk`

### Step 5: Build Signed Android App Bundle (Google Play Store)
Build the optimized `.aab` for Google Play deployment:

```bash
flutter build appbundle --release \
  --dart-define=ENV=prod \
  --dart-define=API_BASE_URL=https://api.shuttle.university.lk
```

Artifact:
`mobile/build/app/outputs/bundle/release/app-release.aab`

---

## 10. Admin Web Dashboard Production Build

### Step 1: Compile Web Production Bundle
Compile the Flutter Web dashboard using CanvasKit for high-performance rendering:

```bash
cd admin-web
flutter pub get
flutter build web --release --web-renderer canvaskit \
  --dart-define=API_BASE_URL=https://api.shuttle.university.lk
```

The output bundle is generated at `admin-web/build/web`.

### Step 2: Deploy to Web Server
Copy the output to your web server:

```bash
rsync -avz --delete admin-web/build/web/ user@server:/var/www/shuttle-admin-web/
```

Or deploy using the containerized Dockerfile:
```bash
docker build -t shuttle-admin-web:latest ./admin-web
```

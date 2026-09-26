# University Shuttle Management System — REST API Reference

This document provides a comprehensive reference for all REST endpoints exposed by the University Shuttle Management backend, generated from the OpenAPI v3 specification.

**Base URL**: `http://localhost:8080` (Development) or `https://api.shuttle.university.lk` (Production)  
**Interactive Swagger UI**: `http://localhost:8080/swagger-ui.html`  
**OpenAPI JSON Specification**: `http://localhost:8080/v3/api-docs`

---

## 1. Authentication & Security

All protected endpoints require an HTTP `Authorization` header containing a valid Bearer JWT:
```http
Authorization: Bearer <access_token>
```

### Rate Limiting
Public authentication and financial endpoints are protected via Bucket4j token bucket rate limiting:
* `POST /api/auth/login`: 10 requests / minute
* `POST /api/auth/register`: 10 requests / minute
* `POST /api/boarding/confirm`: 15 requests / minute
* `POST /api/wallet/top-up`: 10 requests / minute
* `POST /api/monthly-pass/purchase`: 10 requests / minute

Violations return `429 Too Many Requests`.

---

## 2. Authentication API (`/api/auth`)

### 2.1. User Login
Authenticate with email and password to receive access and refresh tokens.

* **Method**: `POST`
* **Path**: `/api/auth/login`
* **Access**: Public
* **Request Body**:
```json
{
  "email": "student@shuttle.dev",
  "password": "Student@1234"
}
```
* **Success Response (200 OK)**:
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiJ9...",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "role": "ROLE_STUDENT",
  "userId": 1,
  "email": "student@shuttle.dev",
  "fullName": "Kasun Perera"
}
```

### 2.2. Student Registration
Register a new student account. Automatically provisions a digital wallet and a virtual bus card.

* **Method**: `POST`
* **Path**: `/api/auth/register`
* **Access**: Public
* **Request Body**:
```json
{
  "email": "newstudent@shuttle.dev",
  "password": "Student@Password123",
  "fullName": "Anura Kumara",
  "phone": "+94771234567",
  "studentId": "IT2026001",
  "faculty": "Faculty of Computing",
  "enrollmentYear": 2026
}
```
* **Success Response (201 Created)**:
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiJ9...",
  "tokenType": "Bearer",
  "expiresIn": 900,
  "role": "ROLE_STUDENT",
  "userId": 4,
  "email": "newstudent@shuttle.dev",
  "fullName": "Anura Kumara"
}
```

### 2.3. Refresh Access Token
Obtain a new access token using a valid refresh token.

* **Method**: `POST`
* **Path**: `/api/auth/refresh`
* **Access**: Public
* **Request Body**:
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiJ9..."
}
```
* **Success Response (200 OK)**:
```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiJ9...",
  "tokenType": "Bearer",
  "expiresIn": 900
}
```

---

## 3. Student Self-Service API (`/api/students`)

### 3.1. Get Student Profile
Retrieve the authenticated student's profile information.

* **Method**: `GET`
* **Path**: `/api/students/me`
* **Access**: `ROLE_STUDENT`
* **Success Response (200 OK)**:
```json
{
  "userId": 1,
  "email": "student@shuttle.dev",
  "fullName": "Kasun Perera",
  "phone": "+94771234567",
  "studentId": "IT2024001",
  "faculty": "Faculty of Engineering",
  "enrollmentYear": 2024
}
```

### 3.2. Get Virtual Bus Card & Dynamic QR
Fetches the virtual card status, active monthly pass state, current wallet balance, and a short-lived signed QR token (60-second TTL).

* **Method**: `GET`
* **Path**: `/api/students/me/card`
* **Access**: `ROLE_STUDENT`
* **Success Response (200 OK)**:
```json
{
  "cardId": "CARD-8F92A1",
  "cardStatus": "ACTIVE",
  "monthlyPassStatus": "NONE",
  "wallet": {
    "balance": 1500.00,
    "status": "ACTIVE"
  },
  "qrToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwidHlwZSI6IlFSX0JPQVJESU5HIiwiZXhwIjoxNzg5..."
}
```

### 3.3. Verify Student Card QR (Driver/Admin)
Scans and verifies a student's virtual card QR token.

* **Method**: `POST`
* **Path**: `/api/cards/verify`
* **Access**: `ROLE_DRIVER`, `ROLE_ADMIN`
* **Request Body**:
```json
{
  "qrToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```
* **Success Response (200 OK)**:
```json
{
  "valid": true,
  "studentId": 1,
  "studentName": "Kasun Perera",
  "studentCode": "IT2024001",
  "cardStatus": "ACTIVE",
  "monthlyPassActive": false,
  "walletBalance": 1500.00
}
```

---

## 4. Wallet & Payments API (`/api/wallet`, `/api/payment`)

### 4.1. Get Wallet Balance
* **Method**: `GET`
* **Path**: `/api/wallet`
* **Access**: `ROLE_STUDENT`
* **Success Response (200 OK)**:
```json
{
  "walletId": 1,
  "balance": 1500.00,
  "currency": "LKR",
  "status": "ACTIVE"
}
```

### 4.2. Top-Up Wallet
Initiate a wallet balance top-up. In development or test, returns an approved transaction immediately. In production, returns payment gateway parameters for PayHere checkout.

* **Method**: `POST`
* **Path**: `/api/wallet/top-up`
* **Access**: `ROLE_STUDENT`
* **Request Body**:
```json
{
  "amount": 500.00
}
```
* **Success Response (200 OK)**:
```json
{
  "paymentId": 101,
  "orderId": "TOPUP-1-1789012345",
  "amount": 500.00,
  "currency": "LKR",
  "status": "COMPLETED",
  "gateway": "mock"
}
```

### 4.3. Wallet Transactions
* **Method**: `GET`
* **Path**: `/api/wallet/transactions?page=0&size=20`
* **Access**: `ROLE_STUDENT`
* **Success Response (200 OK)**:
```json
{
  "content": [
    {
      "id": 45,
      "type": "FARE_DEDUCTION",
      "amount": -100.00,
      "balanceAfter": 1400.00,
      "description": "Boarding deduction: Stop #1 to Campus",
      "createdAt": "2026-09-26T08:00:00Z"
    }
  ],
  "totalElements": 1,
  "totalPages": 1
}
```

### 4.4. Payment Webhook Callback
Asynchronous IPN webhook invoked by payment providers (PayHere).

* **Method**: `POST`
* **Path**: `/api/payment/webhook`
* **Access**: Public (HMAC-MD5 / SHA-256 signature verified in body)

---

## 5. Boarding & Fare Validation API (`/api/boarding`)

### 5.1. Validate Bus Stop QR
Validates a bus stop's HMAC-signed QR code before boarding. Returns route, stop name, and computed fare.

* **Method**: `POST`
* **Path**: `/api/boarding/validate`
* **Access**: `ROLE_STUDENT`
* **Request Body**:
```json
{
  "stopQrPayload": "STOP-001.c3VwZXJfc2VjcmV0X2htYWNfaGV4...",
  "tripId": 1
}
```
* **Success Response (200 OK)**:
```json
{
  "valid": true,
  "stopId": 1,
  "stopName": "Kandy Bus Stand",
  "routeId": 1,
  "routeName": "Kandy -> University Main Campus",
  "fareAmount": 100.00,
  "coveredByMonthlyPass": false
}
```

### 5.2. Confirm Boarding (Idempotent)
Executes boarding validation and financial fare deduction under a pessimistic database write lock.

* **Method**: `POST`
* **Path**: `/api/boarding/confirm`
* **Access**: `ROLE_STUDENT`
* **Request Body**:
```json
{
  "stopQrPayload": "STOP-001.c3VwZXJfc2VjcmV0X2htYWNfaGV4...",
  "tripId": 1,
  "idempotencyKey": "a9c2b4d1-81f7-4180-a681-30d8847b2c93"
}
```
* **Success Response (200 OK)**:
```json
{
  "boardingRecordId": 12,
  "status": "CONFIRMED",
  "fareDeducted": 100.00,
  "walletBalance": 1400.00,
  "paymentStatus": "PAID",
  "alreadyBoarded": false,
  "boardedAt": "2026-09-26T08:05:00Z"
}
```
* **Duplicate Attempt Response (409 Conflict)**:
```json
{
  "timestamp": "2026-09-26T08:05:30Z",
  "status": 409,
  "code": "ALREADY_BOARDED",
  "message": "You have already boarded this trip."
}
```

### 5.3. Student Boarding History
* **Method**: `GET`
* **Path**: `/api/boarding/history`
* **Access**: `ROLE_STUDENT`
* **Success Response (200 OK)**: List of student's past journeys.

---

## 6. Monthly Pass API (`/api/monthly-pass`)

* `GET /api/monthly-pass`: View active and historical passes.
* `GET /api/monthly-pass/status`: Check pass coverage status for current month.
* `POST /api/monthly-pass/purchase`: Purchase a pass for a specific route and calendar month.

---

## 7. Driver Duty & Trip API (`/api/driver`, `/api/trips`)

### 7.1. Get Driver Assigned Route & Bus
* **Method**: `GET`
* **Path**: `/api/driver/assignment`
* **Access**: `ROLE_DRIVER`
* **Success Response (200 OK)**:
```json
{
  "driverId": 1,
  "driverName": "Sunil Shantha",
  "licenseNumber": "B1234567",
  "driverStatus": "ACTIVE",
  "bus": {
    "id": 1,
    "busNumber": "BUS-001",
    "plateNumber": "NC-4521",
    "capacity": 54,
    "status": "ACTIVE"
  },
  "route": {
    "id": 1,
    "name": "Kandy -> University Main Campus",
    "code": "R1",
    "estimatedDurationMinutes": 45,
    "stops": [
      { "id": 1, "name": "Kandy Bus Stand", "qrCode": "STOP-001", "sequence": 1, "latitude": 7.2906, "longitude": 80.6337 },
      { "id": 2, "name": "University Gate", "qrCode": "STOP-002", "sequence": 2, "latitude": 7.2525, "longitude": 80.5925 }
    ]
  }
}
```

### 7.2. Start Trip
* **Method**: `POST`
* **Path**: `/api/trips/{id}/start`
* **Access**: `ROLE_DRIVER`
* **Success Response (200 OK)**: Status updated to `IN_PROGRESS`.

### 7.3. Complete Trip
* **Method**: `POST`
* **Path**: `/api/trips/{id}/end`
* **Access**: `ROLE_DRIVER`
* **Success Response (200 OK)**: Status updated to `COMPLETED`.

### 7.4. Report Incident or Emergency
* **Method**: `POST`
* **Path**: `/api/driver/emergency-report`
* **Access**: `ROLE_DRIVER`
* **Request Body**:
```json
{
  "tripId": 1,
  "incidentType": "BREAKDOWN",
  "description": "Engine overheating near Peradeniya bridge. Replacement requested.",
  "latitude": 7.2625,
  "longitude": 80.6012
}
```
* **Success Response (200 OK)**: Incident created, notifications dispatched.

---

## 8. Public Route & Schedule API (`/api/routes`)

* `GET /api/routes`: List all operational routes.
* `GET /api/routes/{id}`: Detailed route view with sequenced stops.
* `GET /api/routes/{id}/stops`: Stops and current fare pricing matrix.

---

## 9. Admin Management API (`/api/admin`)

*All admin endpoints require `ROLE_ADMIN`.*

| Endpoint | Method | Description |
|---|:---:|---|
| `/api/admin/dashboard` | `GET` | Fleet stats, today's passengers, revenue, and active trips |
| `/api/admin/buses` | `GET`, `POST` | List and create fleet buses |
| `/api/admin/buses/{id}` | `GET`, `PUT`, `DELETE` | Manage bus details, plate number, capacity, maintenance status |
| `/api/admin/drivers` | `GET`, `POST` | Manage driver records and license credentials |
| `/api/admin/drivers/{id}/assign` | `POST` | Assign driver to a specific bus and route |
| `/api/admin/routes` | `GET`, `POST` | Create routes and define stop sequences |
| `/api/admin/stops` | `GET`, `POST` | Create bus stops with GPS coordinates and QR identifiers |
| `/api/admin/stops/{id}/qr` | `GET` | Download generated high-resolution PNG QR image |
| `/api/admin/stops/{id}/qr/payload` | `GET` | Get HMAC-signed string payload for physical QR code generation |
| `/api/admin/fares` | `GET`, `POST` | Configure distance and flat fare rules |
| `/api/admin/trips` | `GET`, `POST` | Schedule new shuttle service trips |
| `/api/admin/trips/{id}/start` | `POST` | Force trip start (`SCHEDULED` -> `IN_PROGRESS`) |
| `/api/admin/trips/{id}/complete`| `POST` | Force trip completion (`IN_PROGRESS` -> `COMPLETED`) |
| `/api/admin/trips/{id}/cancel` | `POST` | Cancel trip (`SCHEDULED`/`IN_PROGRESS` -> `CANCELLED`) |
| `/api/admin/students` | `GET` | Paginated search of all student accounts |
| `/api/admin/students/{id}/suspend`| `POST`| Suspend a student's card and boarding rights |
| `/api/admin/students/{id}/activate`| `POST`| Reactivate a suspended student account |
| `/api/admin/payments` | `GET` | Paginated audit ledger of all top-ups and pass purchases |
| `/api/admin/reports/{type}` | `GET` | Generate CSV/JSON reports (`daily-revenue`, `trip-summary`) |
| `/api/admin/announcements` | `POST` | Broadcast campus-wide notifications to student and driver apps |

---

## 10. Actuator & Monitoring Endpoints

| Endpoint | Method | Access | Description |
|---|:---:|:---:|---|
| `/actuator/health` | `GET` | Public | Liveness and database connectivity probe (`{"status":"UP"}`) |
| `/actuator/info` | `GET` | Public | Build and version metadata |

# Shuttle Project — Security & Quality Audit Report

**Date:** September 2026  
**Status:** Audit & Remediation Completed  
**Test Suite Status:** 145 / 145 Backend Tests Passing | 27 / 27 Mobile Tests Passing  

---

## 1. Executive Summary

A comprehensive security, architecture, and code-quality review was performed across the complete Shuttle Project repository, encompassing the Spring Boot backend (`/backend`), Flutter mobile application (`/mobile`), and admin web interfaces (`/admin-web`). All identified vulnerabilities, insecure configurations, and missing controls have been remediated and verified through an automated security test suite.

---

## 2. Security Review & Hardening Checklist

| Checklist Item | Status | Verification & Fix Implemented |
|---|:---:|---|
| **Role Authorization (401 / 403)** | ✅ Passed | Every endpoint in `SecurityConfig.java` is explicitly guarded by role (`ADMIN`, `DRIVER`, `STUDENT`) or requires authentication. Anonymous requests receive `401 Unauthorized`. Cross-role unauthorized access receives `403 Forbidden`. |
| **IDOR Prevention** | ✅ Passed | All student self-service endpoints (`/api/students/me/**`, `/api/wallet/**`, `/api/boarding/**`, `/api/monthly-pass/**`, `/api/notifications/**`) derive student identity solely from authenticated JWT claims. Fixed `pollPaymentStatus` to verify student ownership or require `ADMIN` role. |
| **Secrets & Credentials Management** | ✅ Passed | Hardcoded database password fallback removed from `application.yml`. Provided comprehensive `.env.example` templates in root and `backend/`. Verified Flutter code contains no hardcoded secrets or API tokens. |
| **Input Validation & Safe Error Responses** | ✅ Passed | `GlobalExceptionHandler.java` catches validation, deserialization, data integrity, and unexpected exceptions. Internal exceptions log stack traces server-side via SLF4J, while returning sanitized JSON responses without leaking class names or stack traces to clients. |
| **CORS Lockdown** | ✅ Passed | Removed wildcard `*` with credentials. Restricted CORS strictly to configured admin origins (`app.cors.allowed-origins` defaulting to `http://localhost:5173,http://localhost:3000`). |
| **Rate Limiting** | ✅ Passed | Expanded `RateLimitFilter.java` using Bucket4j in-memory token buckets to rate-limit: `POST /api/auth/login` (10 req/min), `POST /api/auth/register` (10 req/min), `POST /api/boarding/confirm` (15 req/min), `POST /api/wallet/top-up` (10 req/min), and `POST /api/monthly-pass/purchase` (10 req/min). Returns `429 Too Many Requests`. |
| **Security Headers & HTTPS Enforcement** | ✅ Passed | Spring Security configured with `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `X-XSS-Protection`, `Content-Security-Policy: default-src 'self'`, and `Strict-Transport-Security` (HSTS). Prod profile enforces HTTPS channel via `requiresSecure()`. |
| **QR Code Tamper Resistance & Expiry** | ✅ Passed | Student virtual cards use short-lived signed JWTs (60s TTL) with `type=QR_BOARDING` preventing access-token replay. Bus stop QR codes use HMAC-SHA256 signatures validated via constant-time `MessageDigest.isEqual` to prevent timing attacks. |
| **Payment Security & Verification** | ✅ Passed | Server-to-server webhook verifies cryptographic gateway signature (`mock_hash` / `md5sig`). Idempotency deduplication prevents double-crediting via `gateway_transaction_id`. Client status polling is server-side verified and read-only. |
| **Concurrency & Transaction Safety** | ✅ Passed | `BoardingWriter.java` and `WalletService.java` acquire pessimistic write locks (`@Lock(LockModeType.PESSIMISTIC_WRITE)`) on the student's `Wallet`. Serializes all boarding and wallet operations, preventing race conditions, overdraws, and double-boarding. |

---

## 3. Automated Test Suite Matrix

The security test suite (`SecurityComprehensiveIntegrationTest.java` on the backend and `network_failure_test.dart` on Flutter) covers all mandatory attack vectors and edge cases:

| Scenario | Component | Test Method | Result |
|---|---|---|:---:|
| **Unauthorized API Access** | Backend | `unauthenticatedAccess_returns401()` | ✅ Passed (401) |
| **Cross-Role Access (Student to Admin/Driver)** | Backend | `studentRole_accessingRestrictedEndpoints_returns403()` | ✅ Passed (403) |
| **Cross-Role Access (Driver to Admin/Student/Wallet)** | Backend | `driverRole_accessingRestrictedEndpoints_returns403()` | ✅ Passed (403) |
| **IDOR Prevention (Payment Status)** | Backend | `idor_studentACannotReadStudentBPayment()` | ✅ Passed (403) |
| **IDOR Prevention (Notifications)** | Backend | `idor_studentACannotMarkStudentBNotificationAsRead()` | ✅ Passed (403) |
| **Invalid / Tampered QR Code** | Backend | `qrSecurity_tamperedStopQrRejected()` | ✅ Passed (400 `QR_INVALID`) |
| **Expired QR Code** | Backend | `qrSecurity_expiredStudentCardTokenRejected()` | ✅ Passed (401 `TOKEN_EXPIRED`) |
| **QR Replay Attack (Access Token Replay)** | Backend | `qrSecurity_accessTokenReplayRejected()` | ✅ Passed (401 `TOKEN_INVALID`) |
| **Duplicate Boarding on Same Trip** | Backend | `boarding_duplicateBoardingRejected()` | ✅ Passed (409 `ALREADY_BOARDED`) |
| **Idempotent Retry with Same Key** | Backend | `boarding_duplicateBoardingRejected()` (retry flow) | ✅ Passed (200 `alreadyBoarded=true`) |
| **Expired Monthly Pass** | Backend | `monthlyPass_expiredPass_requiresWalletBalance()` | ✅ Passed (402 `INSUFFICIENT_BALANCE`) |
| **Insufficient Wallet Balance** | Backend | `wallet_insufficientBalance_rejectedWith402()` | ✅ Passed (402 `INSUFFICIENT_BALANCE`) |
| **Failed Payment (Invalid Signature)** | Backend | `payment_invalidWebhookSignatureRejected()` | ✅ Passed (400 `WEBHOOK_INVALID`) |
| **GPS Proximity Outside Area** | Backend | `gps_outsideRadiusRejected()` | ✅ Passed (400 `GPS_TOO_FAR`) |
| **Cancelled Trip Boarding Attempt** | Backend | `trip_cancelledTripRejected()` | ✅ Passed (409 `TRIP_NOT_ACTIVE`) |
| **Rate Limiting Throttling** | Backend | `rateLimiting_loginEndpoint_returns429()` | ✅ Passed (429 `RATE_LIMIT_EXCEEDED`) |
| **Security Headers Verification** | Backend | `securityHeaders_areEnforced()` | ✅ Passed (HSTS, CSP, X-Frame) |
| **Network Failure & Offline Resilience** | Flutter | `Network failure fallback: RouteRepository returns cached routes` | ✅ Passed |
| **Prohibited Offline Actions Rejection** | Flutter | `Network failure protection: Critical financial & boarding actions are rejected offline` | ✅ Passed |
| **Safe Offline Actions Queueing** | Flutter | `Network failure resilience: Safe non-financial actions queue with idempotency keys` | ✅ Passed |
| **Network Status Banner UI** | Flutter | `UI response to network failure: ConnectivityBanner alerts user without crashing` | ✅ Passed |

---

## 4. Remediation Details

### 4.1. Access Control & IDOR Fixes
- **Location:** `PaymentController.java`, `PaymentWebhookService.java`
- **Issue:** `pollPaymentStatus` previously allowed any authenticated student to view payment amounts and statuses for arbitrary `paymentId` values.
- **Fix:** Injected `Authentication auth`. Verified that if caller is not `ROLE_ADMIN`, `payment.getStudent().getUser().getId()` must strictly equal `principal.getId()`. Unauthorized requests are denied with `403 Forbidden`.

### 4.2. Rate Limiting Protection
- **Location:** `RateLimitFilter.java`
- **Issue:** Only `POST /api/auth/login` was rate limited; registration, boarding, and payment endpoints lacked throttling, exposing the application to credential stuffing, SMS/email spam, and automated scanning.
- **Fix:** Implemented distinct Bucket4j token buckets mapped by client IP and action type for login (10/min), registration (10/min), boarding confirmation (15/min), wallet top-up (10/min), and monthly pass purchase (10/min).

### 4.3. Concurrency & Double-Boarding Prevention
- **Location:** `BoardingWriter.java`, `WalletService.java`
- **Issue:** High-frequency concurrent boarding requests could potentially race before database unique constraints fired or attempt concurrent deductions from wallet balance.
- **Fix:** `BoardingWriter.save` and `WalletService.deductFare` acquire a `PESSIMISTIC_WRITE` lock (`SELECT ... FOR UPDATE`) on the student's `Wallet` at the beginning of the transaction. Re-evaluates `existsByTripIdAndStudentId` under the acquired lock, serializing all boarding and wallet operations cleanly.

### 4.4. Information Leakage Prevention
- **Location:** `GlobalExceptionHandler.java`
- **Issue:** Exception handlers previously passed raw exception messages from `HttpMessageNotReadableException`, potentially leaking Jackson parser internals or internal classes.
- **Fix:** Sanitized all client-facing messages (`"Malformed or unreadable JSON request body."`, `"Invalid value for parameter."`). Wrapped unexpected errors in generic 500 error messages while capturing full diagnostics in server-side logs via SLF4J.

---

## 5. Residual Risk Assessment & Production Recommendations

| Risk Area | Severity | Current Mitigation | Recommended Production Hardening |
|---|:---:|---|---|
| **Rate Limiter Storage** | Low | In-memory `ConcurrentHashMap` with Bucket4j (sufficient for single-node). | In a multi-node horizontal deployment behind a load balancer, migrate bucket storage to Redis (`bucket4j-redis`). |
| **Mobile App Integrity** | Low | Signed JWT QR tokens with 60-second TTL and client IP rate limiting. | Enable Android Play Integrity API / iOS DeviceCheck for production APK/IPA builds to prevent rooted/jailbroken spoofing. |
| **Gateway Secret Storage** | Medium | Externalized to environment variables (`PAYHERE_MERCHANT_SECRET`). | In enterprise cloud environments (e.g. AWS KMS, GCP Secret Manager, or HashiCorp Vault), inject secrets dynamically via secret managers. |
| **Database Encryption** | Low | SSL enabled in `prod` profile (`useSSL=true&requireSSL=true`). | Enable transparent data encryption (TDE) or disk-level encryption (LUKS/dm-crypt) on the MySQL storage volume. |

---

## 6. Verification Summary

- **Total Backend Tests:** 145 passed (0 failures, 0 errors, 0 skipped).
- **Total Mobile Tests:** 27 passed (0 failures, 0 errors, 0 skipped).
- **Static Analysis:** `flutter analyze` completed with 0 errors and 0 warnings.

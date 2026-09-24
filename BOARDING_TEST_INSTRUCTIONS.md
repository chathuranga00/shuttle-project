# Boarding Flow — End-to-End Test Instructions

This guide walks through the full flow: **Login → Card → Scan stop QR → Fare preview → Confirm boarding → Record**.

---

## Prerequisites

| Requirement | Details |
|---|---|
| Backend running | `mvn spring-boot:run` — defaults to `http://localhost:8080` |
| Demo data seeded | V4 migration seeds: bus `BUS-001`, route `Kandy → University`, stops `STOP-001`…`STOP-005`, demo driver `driver@shuttle.dev` / `Driver@1234` |
| Admin credentials | `admin@shuttle.dev` / `Admin@1234` (seeded by `AdminSeeder` on `dev` profile) |
| Flutter app target | Android emulator **or** physical device with camera |
| Flutter base URL | `lib/core/config/app_config.dart` — dev = `http://10.0.2.2:8080` (emulator) or change to your machine's LAN IP for a physical device |

---

## Step 1 — Start an active trip (required before boarding)

The boarding flow requires a trip in `IN_PROGRESS` state. Use the admin API to create and start one.

### 1a. Get an admin access token

```bash
curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@shuttle.dev","password":"Admin@1234"}' \
  | python -m json.tool
```

Copy the `accessToken` value. Set it:

```bash
ADMIN_TOKEN="<paste_access_token_here>"
```

### 1b. Get IDs for bus, route and driver

```bash
# Route ID (should be 1 from seed)
curl -s http://localhost:8080/api/routes \
  -H "Authorization: Bearer $ADMIN_TOKEN" | python -m json.tool

# Bus ID
curl -s http://localhost:8080/api/admin/buses \
  -H "Authorization: Bearer $ADMIN_TOKEN" | python -m json.tool

# Driver ID
curl -s http://localhost:8080/api/admin/drivers \
  -H "Authorization: Bearer $ADMIN_TOKEN" | python -m json.tool
```

### 1c. Create a trip (SCHEDULED)

```bash
curl -s -X POST http://localhost:8080/api/admin/trips \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "routeId": 1,
    "busId": 1,
    "driverId": 1,
    "scheduledStart": "2026-01-01T06:00:00Z"
  }' | python -m json.tool
```

Note the `"id"` field. Set it:

```bash
TRIP_ID=<id>
```

### 1d. Start the trip (SCHEDULED → IN_PROGRESS)

```bash
curl -s -X POST "http://localhost:8080/api/admin/trips/$TRIP_ID/start" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | python -m json.tool
```

Confirm `"status": "IN_PROGRESS"`.

---

## Step 2 — Get the signed QR for a stop

The boarding flow requires a **signed stop QR payload** — the HMAC signature prevents forgery. Get the QR for stop 1 (Kandy Bus Stand):

### Option A — Get the PNG image and display it

```bash
# Get stop ID
curl -s http://localhost:8080/api/admin/stops \
  -H "Authorization: Bearer $ADMIN_TOKEN" | python -m json.tool
```

Download the PNG QR image for stop 1:

```bash
curl -s "http://localhost:8080/api/admin/stops/1/qr" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  --output stop1_qr.png
```

Then open `stop1_qr.png` on your computer and display it full-screen, or print it.

### Option B — Get the payload text and generate your own QR

```bash
curl -s "http://localhost:8080/api/admin/stops/1/qr/payload" \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

Response:
```json
{
  "stopId": 1,
  "qrCode": "STOP-001",
  "signedPayload": "STOP-001.<base64url-hmac>"
}
```

Copy the `signedPayload` string. On any QR generator website (e.g. https://qr.io or using `qrencode` on the CLI) encode this exact string as a QR code:

```bash
# Linux/macOS with qrencode installed:
qrencode -o stop1_signed.png "STOP-001.<paste-the-full-signed-payload>"
```

Display the image full-screen on your monitor.

---

## Step 3 — Run the Flutter app and board

1. **Register/login** as a student (or use an existing account).

2. From the **dashboard**, tap the blue **SCAN BOARDING QR** button.
   - The camera opens with a white viewfinder frame.
   - On first launch, Android shows a camera permission dialog — tap **Allow**.

3. **Point the camera** at the stop QR code displayed on your screen.
   - The scanner calls `POST /api/boarding/validate` automatically.
   - If valid, the frame turns amber and "Validating…" appears briefly.
   - The **Boarding Confirmation screen** opens showing:
     - Stop name (e.g. "Kandy Bus Stand")
     - Route name (e.g. "Kandy → University")
     - Fare (e.g. "LKR 100.00") — loaded from the DB, never hard-coded
     - Status chip: **VALID** (green)
     - Payment notice: "marked UNPAID, settled later"

4. Tap **Confirm Boarding**.
   - The app calls `POST /api/boarding/confirm` with a UUID idempotency key.
   - On success, the **Boarding Result screen** shows:
     - Large green tick
     - "Boarding Confirmed!"
     - Stop, route, fare, and **payment status = UNPAID**
   - On any error (duplicate, suspended, offline), a red X and the exact backend error message appear.

5. Tap **Done** → returns to dashboard.
   - The **Recent Journeys** section now shows the boarding record.
   - The UNPAID status label is visible in amber.

---

## Step 4 — Verify a duplicate boarding returns the correct message

Without completing the trip or starting a new one:

1. Tap **SCAN BOARDING QR** again on the dashboard.
2. Scan the same stop QR.
3. On the Confirmation screen, tap **Confirm Boarding** again.
4. The result screen should show:
   ```
   Boarding Failed
   You have already boarded this trip.
   ```
   (HTTP 409, code `ALREADY_BOARDED` — exact message from `BoardingService.MSG_ALREADY_BOARDED`)

---

## Step 5 — Verify retry with same idempotency key is safe

This is handled automatically by the app — the `uuid` package generates a fresh key per confirm tap. But if you want to verify idempotency:

```bash
KEY="test-idem-key-123"

curl -s -X POST http://localhost:8080/api/boarding/confirm \
  -H "Authorization: Bearer $STUDENT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"stopQrPayload\":\"STOP-001.<signed>\",\"tripId\":$TRIP_ID,\"idempotencyKey\":\"$KEY\"}"

# Second call with SAME key — must return alreadyBoarded=true, not an error
curl -s -X POST http://localhost:8080/api/boarding/confirm \
  -H "Authorization: Bearer $STUDENT_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"stopQrPayload\":\"STOP-001.<signed>\",\"tripId\":$TRIP_ID,\"idempotencyKey\":\"$KEY\"}"
```

Second response has `"alreadyBoarded": true` and `"paymentStatus": "UNPAID"`.

---

## Step 6 — View Travel History

From the dashboard tap **View all** next to Recent Journeys, or navigate to `/boarding/history`. The list shows all boardings with:
- Route name
- Stop name
- Date/time
- Fare amount (LKR)
- Payment status chip: **UNPAID** (amber) or **PAID** (green)

Pull down to refresh the list.

---

## Offline behaviour

1. Disable WiFi/mobile data on the device.
2. The red **"You are offline. Boarding is disabled."** banner appears at the top of the dashboard.
3. The SCAN BOARDING QR button becomes disabled (greyed out, labelled "OFFLINE — SCAN DISABLED").
4. If you navigate directly to the scanner screen and scan, the error message "You are offline…" appears without calling the server.
5. **A boarding is never shown as confirmed unless the server returned HTTP 200.** The app only navigates to the success result screen after a successful API response.

---

## Emulator tip — scanning a QR on the same machine

On an Android emulator, the camera shows the host machine's webcam. To scan a QR displayed on your monitor:

1. Generate and open `stop1_qr.png` full-screen.
2. Switch to the emulator, open the scanner.
3. Tilt/position the emulator camera (or use the **Extended Controls → Camera → Virtual scene**) to point at the screen.

Alternatively, use the **Extended Controls → Camera** to inject a custom image:
- In Android Studio emulator: `…` → Camera → Add image → select `stop1_qr.png`.

Or test via `curl` directly as shown in Step 5 above.

# Live Bus Tracking Specification & Guide

## 1. Overview and Architecture

The Live Bus Tracking feature provides near real-time visibility of active transit buses on interactive maps for both students (tracking their specific route's bus) and administrators (monitoring the entire active fleet).

```
                      +-----------------------------+
                      |   Driver Mobile Device      |
                      |  (Geolocator GPS Stream)    |
                      +--------------+--------------+
                                     |
                                     | POST /api/driver/trips/{tripId}/location
                                     | (Throttled >= 3s, Distance > 10m)
                                     v
                      +-----------------------------+
                      |     Spring Boot Backend     |
                      |   - BusLocationService      |
                      |   - bus_locations (Upsert)  |
                      |   - SimpMessagingTemplate   |
                      +-------+--------------+------+
                              |              |
      STOMP WebSocket         |              | STOMP WebSocket
      /topic/trips/{tripId}/location         | /topic/trips/locations
                              v              v
                  +-------------------+  +---------------------+
                  |   Student App     |  |   Admin Web Console |
                  | (flutter_map OSM) |  |  (flutter_map OSM)  |
                  +-------------------+  +---------------------+
```

---

## 2. Privacy & Battery Guarantees

### Continuous Tracking Limits
- **Driver Device Only**: Continuous GPS tracking is strictly restricted to the assigned driver's device while conducting an active trip.
- **No Continuous Student Tracking**: Students are **never** continuously tracked. The boarding-time geofence check (Step 8) remains a one-time, instantaneous check at the moment of QR scan and is completely separate from live bus tracking.
- **Active Trip Window**: Driver location streaming begins *only* after the trip enters `ACTIVE` / `IN_PROGRESS` status and terminates *immediately* when the trip ends, completes, or is cancelled.

### Driver Awareness & Transparency
- **Persistent Status Badge**: A glowing green "Sharing Location" badge is permanently visible on the driver's active trip dashboard.
- **Graceful Permission Handling**: If location permissions are denied, the app displays an informative warning explaining that students will not see the bus on the map, but the driver can still operate boarding and manage the trip without hindrance.

### Battery & Bandwidth Optimization
- **Distance Filtering**: The mobile driver client uses a 10-meter distance filter so GPS events are not broadcast when idling in traffic or waiting at a stop.
- **Rate-Limiting Throttle**:
  - The driver client enforces a minimum 3.5-second debounce.
  - The backend rate-limits updates to at most one per 3.0 seconds per trip, returning `429 Too Many Requests` (`RATE_LIMIT_EXCEEDED`) if updates are sent too frequently.
- **Heartbeat Update**: If stationary for more than 30 seconds, a keep-alive update is transmitted to refresh the "last updated" indicator.

---

## 3. Data Retention & Storage Policy

- **Current Position Only (Upsert)**: The `bus_locations` table stores **only the latest position** for each bus (`bus_id` is unique).
- **No Historical Log**: The system does **not** accumulate location history or breadcrumbs in `bus_locations`.
- **Ghost Bus Prevention**: When a trip is ended, completed, or cancelled:
  - The bus location row is deleted/cleared in `bus_locations`.
  - A STOMP message with `cleared: true` is broadcast over `/topic/trips/{tripId}/location` and `/topic/trips/locations`.
  - Student and admin map markers are instantly removed.

---

## 4. Database Schema

### Table: `bus_locations`
Created via Flyway migration `V11__bus_locations.sql`:

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | BIGINT | PRIMARY KEY, AUTO_INCREMENT | Surrogate key |
| `bus_id` | BIGINT | NOT NULL, UNIQUE, FK to `buses(id)` | 1-to-1 current location per bus |
| `trip_id` | BIGINT | NULLABLE, FK to `trips(id)` | Current active trip |
| `latitude` | DECIMAL(10, 7) | NOT NULL | WGS-84 Latitude |
| `longitude` | DECIMAL(10, 7) | NOT NULL | WGS-84 Longitude |
| `heading` | DECIMAL(6, 2) | NULLABLE | Compass heading in degrees (0–360) |
| `speed_kmh` | DECIMAL(6, 2) | NULLABLE | Velocity in km/h |
| `updated_at` | DATETIME / TIMESTAMP | NOT NULL | Timestamp of last received fix |

---

## 5. API Endpoints

### 1. Driver Location Ingestion
- **Endpoint**: `POST /api/driver/trips/{tripId}/location`
- **Role Required**: `ROLE_DRIVER` (must be the driver assigned to `tripId`)
- **Trip Condition**: Trip must be in `ACTIVE` / `IN_PROGRESS` state.
- **Rate Limit**: Max 1 request every 3 seconds per trip (`429 Too Many Requests` if exceeded).
- **Request Body**:
```json
{
  "latitude": 6.9271,
  "longitude": 79.8612,
  "heading": 182.5,
  "speed": 34.2
}
```
- **Response**: `200 OK`
```json
{
  "busId": 1,
  "busNumber": "NB-1001",
  "plateNumber": "WP-ND-5432",
  "tripId": 12,
  "routeName": "Route 100 - Colombo to Moratuwa",
  "latitude": 6.9271,
  "longitude": 79.8612,
  "heading": 182.5,
  "speedKmh": 34.2,
  "updatedAt": "2026-09-26T04:45:00Z",
  "cleared": false
}
```

### 2. Single Trip Current Location
- **Endpoint**: `GET /api/trips/{tripId}/location`
- **Role Required**: Any authenticated user (`STUDENT`, `DRIVER`, `ADMIN`)
- **Response**: `200 OK` with `BusLocationResponse` or `404 Not Found` if no fix is available.

### 3. Active Trips List
- **Endpoint**: `GET /api/trips/active`
- **Role Required**: Any authenticated user
- **Response**: `200 OK` with list of `ActiveTripResponse`:
```json
[
  {
    "tripId": 12,
    "routeId": 1,
    "routeName": "Route 100 - Colombo to Moratuwa",
    "busId": 1,
    "busNumber": "NB-1001",
    "plateNumber": "WP-ND-5432",
    "driverName": "Sunil Perera",
    "status": "IN_PROGRESS",
    "scheduledStart": "2026-09-26T04:30:00Z",
    "actualStart": "2026-09-26T04:32:10Z"
  }
]
```

### 4. Admin All Active Locations
- **Endpoint**: `GET /api/admin/trips/locations`
- **Role Required**: `ROLE_ADMIN`
- **Response**: `200 OK` with list of active `BusLocationResponse`.

---

## 6. WebSocket / STOMP Streaming

- **Connection URL**: `/ws` (e.g. `ws://localhost:8080/ws`)
- **Protocol**: STOMP 1.1 / 1.2 over WebSocket
- **Subscriptions**:
  - Student: `/topic/trips/{tripId}/location`
  - Admin: `/topic/trips/locations`
- **Payload Format**: JSON serialized `BusLocationResponse`
- **Fallback**: Both the student mobile app and admin web console automatically poll the corresponding HTTP GET endpoints every 8 seconds if WebSocket connection is closed or unavailable.

---

## 7. End-to-End Manual Testing Script

Follow these steps to manually verify real-time bus tracking:

### Prerequisites
1. Start MySQL database or verify backend database is running.
2. Start the Spring Boot backend:
   ```bash
   cd backend
   mvn spring-boot:run
   ```
3. Start the mobile app on an Android emulator or Chrome:
   ```bash
   cd mobile
   flutter run -d chrome --web-port 4165
   ```
4. Start the Admin Web console:
   ```bash
   cd admin-web
   flutter run -d chrome --web-port 8081
   ```

### Test Flow: Driver -> Student -> Admin Verification

#### Phase A: Start an Active Trip as Driver
1. Log in to the mobile app with driver credentials:
   - **Email**: `driver1@shuttle.dev`
   - **Password**: `password123`
2. Select an assigned scheduled trip and tap **Start Trip**.
3. Verify:
   - Trip transitions to **IN_PROGRESS** / **ACTIVE**.
   - Persistent **"Sharing location"** badge appears with glowing green indicator.
   - Position streaming starts automatically.

#### Phase B: Simulate GPS Movement
- If using an Android Emulator:
  - Open emulator extended controls (`...` icon) -> **Location**.
  - Set Latitude to `6.9271` and Longitude to `79.8612`.
  - Change coordinates by ~20 meters (e.g. `6.9274`, `79.8615`).
- If testing via REST / cURL:
  ```bash
  curl -X POST http://localhost:8080/api/driver/trips/{tripId}/location \
    -H "Authorization: Bearer <DRIVER_JWT_TOKEN>" \
    -H "Content-Type: application/json" \
    -d "{\"latitude\": 6.9271, \"longitude\": 79.8612, \"heading\": 90.0, \"speed\": 25.0}"
  ```

#### Phase C: View Real-Time Tracking in Student App
1. Log in as student (`student1@shuttle.dev` / `password123`).
2. Navigate to **Live Bus Tracking** via:
   - Dashboard "Quick Actions" -> **Track Live Bus**
   - Or "Bus Stops" screen -> Top-right radar icon.
3. Select the active trip from the dropdown.
4. **Verify**:
   - OpenStreetMap renders with static route bus stops.
   - The bus marker appears in real-time at the simulated location.
   - Compass heading rotation aligns with movement direction.
   - Speed pill displays current velocity (e.g. `25 km/h`).
   - "Updated X seconds ago" counter ticks up.
   - Update coordinates again -> marker moves on the map without page reload.

#### Phase D: View Admin Live Fleet Map
1. In the Admin Web dashboard (`http://localhost:8081`), click **Live Fleet Map** in the sidebar.
2. **Verify**:
   - The map displays all currently active buses.
   - The left sidebar lists the active bus, route name, speed, and last updated time.
   - Clicking **"Fit All Buses"** or clicking the bus card centers the map on the bus.

#### Phase E: Trip Completion & Ghost Bus Cleanup
1. As the driver, tap **End Trip**.
2. **Verify**:
   - Driver location sharing stops immediately.
   - In Student App: Bus marker disappears; status updates to "Trip Completed / Waiting for active trip".
   - In Admin Web: Bus marker is removed; active count decrements.
   - In Database: `SELECT * FROM bus_locations WHERE bus_id = <busId>;` returns 0 rows.

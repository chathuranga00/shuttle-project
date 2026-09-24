-- V4: Demo seed data
-- 1 bus, route "Kandy -> University" with 5 stops + fares, 1 demo driver.
-- Idempotent: uses INSERT IGNORE so re-running is safe.

-- ── 1. Demo bus ────────────────────────────────────────────────────────────
INSERT IGNORE INTO buses (bus_number, plate_number, capacity, model, status)
VALUES ('BUS-001', 'KY-1234', 50, 'Ashok Leyland Viking', 'ACTIVE');

-- ── 2. Bus stops ───────────────────────────────────────────────────────────
INSERT IGNORE INTO bus_stops (name, qr_code, latitude, longitude, address, status) VALUES
    ('Kandy Bus Stand',   'STOP-001', 7.2906,  80.6337, 'Kandy Bus Stand, Kandy',          'ACTIVE'),
    ('Katugastota',       'STOP-002', 7.3167,  80.6333, 'Katugastota Junction, Kandy',      'ACTIVE'),
    ('Peradeniya',        'STOP-003', 7.2661,  80.5967, 'Peradeniya Junction, Kandy',       'ACTIVE'),
    ('Pilimathalawa',     'STOP-004', 7.2578,  80.5706, 'Pilimathalawa Junction, Kandy',    'ACTIVE'),
    ('University Gate',   'STOP-005', 7.2540,  80.5930, 'University of Peradeniya, Kandy',  'ACTIVE');

-- ── 3. Route ───────────────────────────────────────────────────────────────
INSERT IGNORE INTO routes (name, code, description, estimated_duration_minutes, status)
VALUES ('Kandy → University', 'KDY-UNI-01',
        'Main shuttle route from Kandy Bus Stand to University of Peradeniya', 45, 'ACTIVE');

-- ── 4. Route stops (ordered) ───────────────────────────────────────────────
-- We use subqueries to avoid hard-coded IDs
INSERT IGNORE INTO route_stops (route_id, bus_stop_id, stop_order, estimated_offset_minutes)
SELECT r.id, s.id, 1, 0
FROM routes r, bus_stops s WHERE r.code = 'KDY-UNI-01' AND s.qr_code = 'STOP-001';

INSERT IGNORE INTO route_stops (route_id, bus_stop_id, stop_order, estimated_offset_minutes)
SELECT r.id, s.id, 2, 10
FROM routes r, bus_stops s WHERE r.code = 'KDY-UNI-01' AND s.qr_code = 'STOP-002';

INSERT IGNORE INTO route_stops (route_id, bus_stop_id, stop_order, estimated_offset_minutes)
SELECT r.id, s.id, 3, 25
FROM routes r, bus_stops s WHERE r.code = 'KDY-UNI-01' AND s.qr_code = 'STOP-003';

INSERT IGNORE INTO route_stops (route_id, bus_stop_id, stop_order, estimated_offset_minutes)
SELECT r.id, s.id, 4, 35
FROM routes r, bus_stops s WHERE r.code = 'KDY-UNI-01' AND s.qr_code = 'STOP-004';

INSERT IGNORE INTO route_stops (route_id, bus_stop_id, stop_order, estimated_offset_minutes)
SELECT r.id, s.id, 5, 45
FROM routes r, bus_stops s WHERE r.code = 'KDY-UNI-01' AND s.qr_code = 'STOP-005';

-- ── 5. Fares (per boarding stop, STANDARD class, open-ended from today) ───
-- Kandy (origin) = LKR 100; each subsequent stop cheaper
INSERT IGNORE INTO fares (route_id, stop_id, amount, fare_class, effective_from, effective_until)
SELECT r.id, s.id, 100.00, 'STANDARD', '2024-01-01', NULL
FROM routes r, bus_stops s WHERE r.code = 'KDY-UNI-01' AND s.qr_code = 'STOP-001';

INSERT IGNORE INTO fares (route_id, stop_id, amount, fare_class, effective_from, effective_until)
SELECT r.id, s.id, 80.00, 'STANDARD', '2024-01-01', NULL
FROM routes r, bus_stops s WHERE r.code = 'KDY-UNI-01' AND s.qr_code = 'STOP-002';

INSERT IGNORE INTO fares (route_id, stop_id, amount, fare_class, effective_from, effective_until)
SELECT r.id, s.id, 60.00, 'STANDARD', '2024-01-01', NULL
FROM routes r, bus_stops s WHERE r.code = 'KDY-UNI-01' AND s.qr_code = 'STOP-003';

INSERT IGNORE INTO fares (route_id, stop_id, amount, fare_class, effective_from, effective_until)
SELECT r.id, s.id, 40.00, 'STANDARD', '2024-01-01', NULL
FROM routes r, bus_stops s WHERE r.code = 'KDY-UNI-01' AND s.qr_code = 'STOP-004';

INSERT IGNORE INTO fares (route_id, stop_id, amount, fare_class, effective_from, effective_until)
SELECT r.id, s.id, 20.00, 'STANDARD', '2024-01-01', NULL
FROM routes r, bus_stops s WHERE r.code = 'KDY-UNI-01' AND s.qr_code = 'STOP-005';

-- ── 6. Demo driver (user + driver profile) ─────────────────────────────────
-- Password is BCrypt of "Driver@1234"
INSERT IGNORE INTO users (email, password_hash, full_name, role, status)
VALUES ('driver@shuttle.dev',
        '$2a$10$wF3hgFv4rBMzR6kKTJW5CeI7OkKaV8u3CfQpwCBmVlHf1n5DfIrbu',
        'Demo Driver',
        'DRIVER', 'ACTIVE');

INSERT IGNORE INTO drivers (user_id, license_number, license_expiry, status)
SELECT u.id, 'LIC-DEMO-001', '2027-12-31', 'ACTIVE'
FROM users u WHERE u.email = 'driver@shuttle.dev';

-- Assign demo driver to the demo bus on the demo route
INSERT IGNORE INTO driver_bus_assignments (driver_id, bus_id, route_id, assigned_at)
SELECT d.id, b.id, r.id, NOW()
FROM drivers d, buses b, routes r
WHERE d.license_number = 'LIC-DEMO-001'
  AND b.bus_number = 'BUS-001'
  AND r.code = 'KDY-UNI-01';

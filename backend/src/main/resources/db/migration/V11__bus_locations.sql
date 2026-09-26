-- V11: Add bus_locations table for live bus tracking
-- Stores ONLY the current position per bus (upsert pattern, not history log)

CREATE TABLE bus_locations (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    bus_id      BIGINT         NOT NULL UNIQUE,
    trip_id     BIGINT         NULL,
    latitude    DECIMAL(10, 7) NOT NULL,
    longitude   DECIMAL(10, 7) NOT NULL,
    heading     DOUBLE         NULL,
    speed_kmh   DOUBLE         NULL,
    created_at  DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at  DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_bus_locations_bus  FOREIGN KEY (bus_id)  REFERENCES buses (id) ON DELETE CASCADE,
    CONSTRAINT fk_bus_locations_trip FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE SET NULL,
    INDEX idx_bus_locations_trip_id (trip_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

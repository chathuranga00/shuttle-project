-- V11: Add bus_locations table for live bus tracking (H2 compatible)
CREATE TABLE bus_locations (
    id          BIGINT         AUTO_INCREMENT PRIMARY KEY,
    bus_id      BIGINT         NOT NULL UNIQUE,
    trip_id     BIGINT         NULL,
    latitude    DECIMAL(10, 7) NOT NULL,
    longitude   DECIMAL(10, 7) NOT NULL,
    heading     DOUBLE         NULL,
    speed_kmh   DOUBLE         NULL,
    created_at  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_bus_locations_bus  FOREIGN KEY (bus_id)  REFERENCES buses (id) ON DELETE CASCADE,
    CONSTRAINT fk_bus_locations_trip FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE SET NULL
);
CREATE INDEX idx_bus_locations_trip_id ON bus_locations (trip_id);

-- H2-compatible V3: Shuttle domain
-- Differences from MySQL version:
--   - No ENGINE/CHARSET clauses
--   - ON UPDATE CURRENT_TIMESTAMP(6) omitted (auditing handled by JPA)
--   - ALTER TABLE ... DROP CONSTRAINT IF EXISTS uses H2 syntax
--   - COMMENT keyword not supported — removed

ALTER TABLE fares DROP CONSTRAINT IF EXISTS uk_fares_route_stops_class;
ALTER TABLE fares DROP CONSTRAINT IF EXISTS fk_fares_from_stop;
ALTER TABLE fares DROP CONSTRAINT IF EXISTS fk_fares_to_stop;
ALTER TABLE fares DROP CONSTRAINT IF EXISTS fk_fares_route;

DROP TABLE IF EXISTS fares;

CREATE TABLE fares (
    id               BIGINT         AUTO_INCREMENT PRIMARY KEY,
    route_id         BIGINT         NOT NULL,
    stop_id          BIGINT         NOT NULL,
    amount           DECIMAL(10, 2) NOT NULL,
    fare_class       VARCHAR(32)    NOT NULL DEFAULT 'STANDARD',
    effective_from   DATE           NOT NULL,
    effective_until  DATE           NULL,
    created_at       DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at       DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_fares_route    FOREIGN KEY (route_id) REFERENCES routes   (id),
    CONSTRAINT fk_fares_stop     FOREIGN KEY (stop_id)  REFERENCES bus_stops (id),
    INDEX idx_fares_route_id     (route_id),
    INDEX idx_fares_stop_id      (stop_id),
    INDEX idx_fares_effective    (route_id, stop_id, fare_class, effective_from)
);

CREATE TABLE system_settings (
    id            BIGINT        AUTO_INCREMENT PRIMARY KEY,
    setting_key   VARCHAR(100)  NOT NULL,
    setting_value VARCHAR(500)  NOT NULL,
    description   VARCHAR(255)  NULL,
    created_at    DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at    DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_system_settings_key UNIQUE (setting_key)
);

INSERT INTO system_settings (setting_key, setting_value, description)
VALUES
    ('gps.radius.meters',        '100',  'Radius in metres for GPS proximity check'),
    ('gps.verification.enabled', 'true', 'Whether GPS check is enforced during boarding');

CREATE TABLE driver_bus_assignments (
    id            BIGINT      AUTO_INCREMENT PRIMARY KEY,
    driver_id     BIGINT      NOT NULL,
    bus_id        BIGINT      NOT NULL,
    route_id      BIGINT      NULL,
    assigned_at   DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    unassigned_at DATETIME(6) NULL,
    created_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_dba_driver FOREIGN KEY (driver_id) REFERENCES drivers (id),
    CONSTRAINT fk_dba_bus    FOREIGN KEY (bus_id)    REFERENCES buses   (id),
    CONSTRAINT fk_dba_route  FOREIGN KEY (route_id)  REFERENCES routes  (id),
    INDEX idx_dba_driver (driver_id),
    INDEX idx_dba_bus    (bus_id)
);

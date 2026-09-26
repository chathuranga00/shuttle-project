-- V9: Emergency reports table
CREATE TABLE emergency_reports (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    driver_id   BIGINT       NOT NULL,
    trip_id     BIGINT       NULL,
    type        VARCHAR(50)  NOT NULL,
    description TEXT         NOT NULL,
    location    VARCHAR(255) NULL,
    status      VARCHAR(32)  NOT NULL DEFAULT 'REPORTED',
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_er_driver FOREIGN KEY (driver_id) REFERENCES drivers (id),
    CONSTRAINT fk_er_trip   FOREIGN KEY (trip_id)   REFERENCES trips (id),
    INDEX idx_er_driver (driver_id),
    INDEX idx_er_created (created_at)
);

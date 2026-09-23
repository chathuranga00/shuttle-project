-- H2-compatible version of V1__init.sql for integration tests
-- Differences from MySQL version:
--   - Removed ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
--   - ON UPDATE CURRENT_TIMESTAMP(6) is silently ignored by H2 MySQL mode (auditing handled by JPA)

CREATE TABLE users (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    email           VARCHAR(255) NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    full_name       VARCHAR(150) NOT NULL,
    phone           VARCHAR(20)  NULL,
    role            VARCHAR(32)  NOT NULL,
    status          VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    created_at      DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at      DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_users_email UNIQUE (email),
    INDEX idx_users_role (role),
    INDEX idx_users_status (status)
);

CREATE TABLE students (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id          BIGINT       NOT NULL,
    student_id       VARCHAR(50)  NOT NULL,
    faculty          VARCHAR(100) NULL,
    department       VARCHAR(100) NULL,
    enrollment_year  INT          NULL,
    created_at       DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at       DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_students_user_id UNIQUE (user_id),
    CONSTRAINT uk_students_student_id UNIQUE (student_id),
    CONSTRAINT fk_students_user FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE TABLE drivers (
    id               BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id          BIGINT       NOT NULL,
    license_number   VARCHAR(50)  NOT NULL,
    license_expiry   DATE         NULL,
    status           VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    created_at       DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at       DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_drivers_user_id UNIQUE (user_id),
    CONSTRAINT uk_drivers_license_number UNIQUE (license_number),
    CONSTRAINT fk_drivers_user FOREIGN KEY (user_id) REFERENCES users (id),
    INDEX idx_drivers_status (status)
);

CREATE TABLE admins (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id     BIGINT       NOT NULL,
    job_title   VARCHAR(100) NULL,
    created_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_admins_user_id UNIQUE (user_id),
    CONSTRAINT fk_admins_user FOREIGN KEY (user_id) REFERENCES users (id)
);

CREATE TABLE buses (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    bus_number      VARCHAR(50)  NOT NULL,
    plate_number    VARCHAR(20)  NOT NULL,
    capacity        INT          NOT NULL,
    model           VARCHAR(100) NULL,
    status          VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    created_at      DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at      DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_buses_bus_number UNIQUE (bus_number),
    CONSTRAINT uk_buses_plate_number UNIQUE (plate_number),
    INDEX idx_buses_status (status)
);

CREATE TABLE routes (
    id                          BIGINT AUTO_INCREMENT PRIMARY KEY,
    name                        VARCHAR(150) NOT NULL,
    code                        VARCHAR(50)  NOT NULL,
    description                 VARCHAR(500) NULL,
    estimated_duration_minutes  INT          NULL,
    status                      VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    created_at                  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at                  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_routes_code UNIQUE (code),
    INDEX idx_routes_status (status)
);

CREATE TABLE bus_stops (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    name        VARCHAR(150)   NOT NULL,
    qr_code     VARCHAR(100)   NOT NULL,
    latitude    DECIMAL(10, 7) NULL,
    longitude   DECIMAL(10, 7) NULL,
    address     VARCHAR(255)   NULL,
    status      VARCHAR(32)    NOT NULL DEFAULT 'ACTIVE',
    created_at  DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at  DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_bus_stops_qr_code UNIQUE (qr_code),
    INDEX idx_bus_stops_status (status)
);

CREATE TABLE route_stops (
    id                         BIGINT AUTO_INCREMENT PRIMARY KEY,
    route_id                   BIGINT      NOT NULL,
    bus_stop_id                BIGINT      NOT NULL,
    stop_order                 INT         NOT NULL,
    estimated_offset_minutes   INT         NULL,
    created_at                 DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at                 DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_route_stops_route_stop UNIQUE (route_id, bus_stop_id),
    CONSTRAINT uk_route_stops_route_order UNIQUE (route_id, stop_order),
    CONSTRAINT fk_route_stops_route FOREIGN KEY (route_id) REFERENCES routes (id),
    CONSTRAINT fk_route_stops_bus_stop FOREIGN KEY (bus_stop_id) REFERENCES bus_stops (id),
    INDEX idx_route_stops_bus_stop_id (bus_stop_id)
);

CREATE TABLE fares (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    route_id      BIGINT         NOT NULL,
    from_stop_id  BIGINT         NOT NULL,
    to_stop_id    BIGINT         NOT NULL,
    amount        DECIMAL(10, 2) NOT NULL,
    fare_class    VARCHAR(32)    NOT NULL DEFAULT 'STANDARD',
    created_at    DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at    DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_fares_route_stops_class UNIQUE (route_id, from_stop_id, to_stop_id, fare_class),
    CONSTRAINT fk_fares_route FOREIGN KEY (route_id) REFERENCES routes (id),
    CONSTRAINT fk_fares_from_stop FOREIGN KEY (from_stop_id) REFERENCES bus_stops (id),
    CONSTRAINT fk_fares_to_stop FOREIGN KEY (to_stop_id) REFERENCES bus_stops (id),
    INDEX idx_fares_route_id (route_id)
);

CREATE TABLE trips (
    id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    bus_id            BIGINT       NOT NULL,
    route_id          BIGINT       NOT NULL,
    driver_id         BIGINT       NOT NULL,
    status            VARCHAR(32)  NOT NULL DEFAULT 'SCHEDULED',
    scheduled_start   DATETIME(6)  NOT NULL,
    scheduled_end     DATETIME(6)  NULL,
    actual_start      DATETIME(6)  NULL,
    actual_end        DATETIME(6)  NULL,
    notes             VARCHAR(500) NULL,
    created_at        DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at        DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_trips_bus FOREIGN KEY (bus_id) REFERENCES buses (id),
    CONSTRAINT fk_trips_route FOREIGN KEY (route_id) REFERENCES routes (id),
    CONSTRAINT fk_trips_driver FOREIGN KEY (driver_id) REFERENCES drivers (id),
    INDEX idx_trips_status (status),
    INDEX idx_trips_scheduled_start (scheduled_start),
    INDEX idx_trips_route_id (route_id),
    INDEX idx_trips_driver_id (driver_id),
    INDEX idx_trips_bus_id (bus_id)
);

CREATE TABLE monthly_passes (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id  BIGINT         NOT NULL,
    route_id    BIGINT         NULL,
    status      VARCHAR(32)    NOT NULL DEFAULT 'PENDING',
    valid_from  DATE           NOT NULL,
    valid_to    DATE           NOT NULL,
    price       DECIMAL(10, 2) NOT NULL,
    created_at  DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at  DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_monthly_passes_student FOREIGN KEY (student_id) REFERENCES students (id),
    CONSTRAINT fk_monthly_passes_route FOREIGN KEY (route_id) REFERENCES routes (id),
    INDEX idx_monthly_passes_student_id (student_id),
    INDEX idx_monthly_passes_status (status),
    INDEX idx_monthly_passes_valid_to (valid_to)
);

CREATE TABLE wallets (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id  BIGINT         NOT NULL,
    balance     DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    status      VARCHAR(32)    NOT NULL DEFAULT 'ACTIVE',
    created_at  DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at  DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_wallets_student_id UNIQUE (student_id),
    CONSTRAINT fk_wallets_student FOREIGN KEY (student_id) REFERENCES students (id),
    CONSTRAINT chk_wallets_balance_non_negative CHECK (balance >= 0)
);

CREATE TABLE wallet_transactions (
    id              BIGINT AUTO_INCREMENT PRIMARY KEY,
    wallet_id       BIGINT         NOT NULL,
    amount          DECIMAL(10, 2) NOT NULL,
    type            VARCHAR(32)    NOT NULL,
    description     VARCHAR(255)   NULL,
    reference_type  VARCHAR(50)    NULL,
    reference_id    BIGINT         NULL,
    balance_after   DECIMAL(10, 2) NOT NULL,
    created_at      DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at      DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_wallet_transactions_wallet FOREIGN KEY (wallet_id) REFERENCES wallets (id),
    INDEX idx_wallet_transactions_wallet_id (wallet_id),
    INDEX idx_wallet_transactions_created_at (created_at)
);

CREATE TABLE virtual_bus_cards (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id  BIGINT       NOT NULL,
    card_id     VARCHAR(64)  NOT NULL,
    status      VARCHAR(32)  NOT NULL DEFAULT 'ACTIVE',
    issued_at   DATETIME(6)  NOT NULL,
    expires_at  DATETIME(6)  NULL,
    qr_payload  VARCHAR(255) NULL,
    created_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at  DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_virtual_bus_cards_student_id UNIQUE (student_id),
    CONSTRAINT uk_virtual_bus_cards_card_id UNIQUE (card_id),
    CONSTRAINT fk_virtual_bus_cards_student FOREIGN KEY (student_id) REFERENCES students (id),
    INDEX idx_virtual_bus_cards_status (status)
);

CREATE TABLE boarding_records (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    trip_id       BIGINT         NOT NULL,
    student_id    BIGINT         NOT NULL,
    bus_stop_id   BIGINT         NOT NULL,
    boarded_at    DATETIME(6)    NOT NULL,
    fare_amount   DECIMAL(10, 2) NULL,
    pass_id       BIGINT         NULL,
    created_at    DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at    DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_boarding_records_trip_student UNIQUE (trip_id, student_id),
    CONSTRAINT fk_boarding_records_trip FOREIGN KEY (trip_id) REFERENCES trips (id),
    CONSTRAINT fk_boarding_records_student FOREIGN KEY (student_id) REFERENCES students (id),
    CONSTRAINT fk_boarding_records_bus_stop FOREIGN KEY (bus_stop_id) REFERENCES bus_stops (id),
    CONSTRAINT fk_boarding_records_pass FOREIGN KEY (pass_id) REFERENCES monthly_passes (id),
    INDEX idx_boarding_records_student_id (student_id),
    INDEX idx_boarding_records_boarded_at (boarded_at)
);

CREATE TABLE payments (
    id                     BIGINT AUTO_INCREMENT PRIMARY KEY,
    student_id             BIGINT         NOT NULL,
    amount                 DECIMAL(10, 2) NOT NULL,
    status                 VARCHAR(32)    NOT NULL DEFAULT 'PENDING',
    type                   VARCHAR(32)    NOT NULL,
    method                 VARCHAR(32)    NULL,
    provider_reference     VARCHAR(100)   NULL,
    description            VARCHAR(255)   NULL,
    trip_id                BIGINT         NULL,
    monthly_pass_id        BIGINT         NULL,
    boarding_record_id     BIGINT         NULL,
    wallet_transaction_id  BIGINT         NULL,
    created_at             DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at             DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT uk_payments_provider_reference UNIQUE (provider_reference),
    CONSTRAINT fk_payments_student FOREIGN KEY (student_id) REFERENCES students (id),
    CONSTRAINT fk_payments_trip FOREIGN KEY (trip_id) REFERENCES trips (id),
    CONSTRAINT fk_payments_monthly_pass FOREIGN KEY (monthly_pass_id) REFERENCES monthly_passes (id),
    CONSTRAINT fk_payments_boarding_record FOREIGN KEY (boarding_record_id) REFERENCES boarding_records (id),
    CONSTRAINT fk_payments_wallet_transaction FOREIGN KEY (wallet_transaction_id) REFERENCES wallet_transactions (id),
    INDEX idx_payments_student_id (student_id),
    INDEX idx_payments_status (status),
    INDEX idx_payments_type (type),
    INDEX idx_payments_created_at (created_at)
);

CREATE TABLE notifications (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id     BIGINT        NOT NULL,
    title       VARCHAR(150)  NOT NULL,
    message     VARCHAR(1000) NOT NULL,
    type        VARCHAR(32)   NOT NULL,
    is_read     BOOLEAN       NOT NULL DEFAULT FALSE,
    created_at  DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at  DATETIME(6)   NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users (id),
    INDEX idx_notifications_user_read (user_id, is_read),
    INDEX idx_notifications_created_at (created_at)
);

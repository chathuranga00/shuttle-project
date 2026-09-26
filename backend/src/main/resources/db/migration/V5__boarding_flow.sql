-- V5: Boarding flow additions
-- Adds idempotency_key and payment_status to boarding_records so that:
--   - Retries with the same key return the existing record instead of duplicating.
--   - Payment status can be tracked independently (UNPAID → PAID, future work).

ALTER TABLE boarding_records
    ADD COLUMN idempotency_key  VARCHAR(64)  NULL          COMMENT 'Client-supplied key; retries are idempotent',
    ADD COLUMN payment_status   VARCHAR(32)  NOT NULL DEFAULT 'UNPAID',
    ADD CONSTRAINT uk_boarding_idempotency UNIQUE (idempotency_key);

CREATE INDEX idx_boarding_idempotency ON boarding_records (idempotency_key);

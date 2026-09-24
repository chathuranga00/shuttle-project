-- H2-compatible V5: Boarding flow additions
-- H2 requires separate ALTER TABLE statements for each operation.

ALTER TABLE boarding_records ADD COLUMN idempotency_key VARCHAR(64) NULL;
ALTER TABLE boarding_records ADD COLUMN payment_status  VARCHAR(32) NOT NULL DEFAULT 'UNPAID';
ALTER TABLE boarding_records ADD CONSTRAINT uk_boarding_idempotency UNIQUE (idempotency_key);

CREATE INDEX idx_boarding_idempotency ON boarding_records (idempotency_key);

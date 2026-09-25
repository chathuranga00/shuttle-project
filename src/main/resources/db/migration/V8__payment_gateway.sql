-- V8: Payment gateway support
-- Adds gateway_transaction_id for idempotent webhook handling.
-- A unique index prevents the same gateway transaction from crediting
-- the wallet or activating a pass more than once.

ALTER TABLE payments
    ADD COLUMN gateway_transaction_id VARCHAR(128) NULL COMMENT 'ID from the payment gateway (unique, for idempotent webhook)';

CREATE UNIQUE INDEX uk_payments_gateway_tx
    ON payments (gateway_transaction_id)
    -- partial index — only non-null values must be unique
    -- MySQL does not support partial unique indexes on nullable columns via standard SQL,
    -- so we rely on the application-layer idempotency check plus this index.
    ;

ALTER TABLE payments
    ADD COLUMN checkout_url VARCHAR(500) NULL COMMENT 'Gateway redirect URL returned at checkout creation';

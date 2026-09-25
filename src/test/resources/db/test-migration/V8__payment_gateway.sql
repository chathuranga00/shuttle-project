-- H2-compatible V8: Payment gateway support

ALTER TABLE payments ADD COLUMN gateway_transaction_id VARCHAR(128) NULL;
ALTER TABLE payments ADD COLUMN checkout_url           VARCHAR(500) NULL;

CREATE UNIQUE INDEX uk_payments_gateway_tx ON payments (gateway_transaction_id);

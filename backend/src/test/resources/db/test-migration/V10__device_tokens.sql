-- V10: Store device tokens for FCM push notifications (H2 compatible)
CREATE TABLE device_tokens (
    id          BIGINT       AUTO_INCREMENT PRIMARY KEY,
    user_id     BIGINT       NOT NULL,
    token       VARCHAR(500) NOT NULL UNIQUE,
    device_type VARCHAR(32)  NOT NULL DEFAULT 'ANDROID',
    created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_device_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

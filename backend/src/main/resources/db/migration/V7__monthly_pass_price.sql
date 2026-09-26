-- V7: Seed default monthly pass price in system_settings.
-- The price is configurable by admins via PUT /api/admin/settings.

INSERT IGNORE INTO system_settings (setting_key, setting_value, description)
VALUES ('pass.price.monthly', '2500.00',
        'Default monthly pass price in LKR');

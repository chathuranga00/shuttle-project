-- H2-compatible V7
INSERT INTO system_settings (setting_key, setting_value, description)
    SELECT 'pass.price.monthly', '2500.00', 'Default monthly pass price in LKR'
    WHERE NOT EXISTS (SELECT 1 FROM system_settings WHERE setting_key = 'pass.price.monthly');

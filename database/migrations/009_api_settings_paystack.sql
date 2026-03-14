-- Platform-wide integrations and settings (extensible)
-- Payments
INSERT INTO platform_settings (setting_key, setting_value, updated_at) VALUES
  ('paystack_secret_key', NULL, NOW()),
  ('paystack_public_key', NULL, NOW()),
  ('paystack_test_mode', '1', NOW())
ON DUPLICATE KEY UPDATE updated_at = VALUES(updated_at);

-- SMS (placeholder for future providers)
INSERT INTO platform_settings (setting_key, setting_value, updated_at) VALUES
  ('sms_provider', NULL, NOW()),
  ('sms_api_key', NULL, NOW())
ON DUPLICATE KEY UPDATE updated_at = VALUES(updated_at);

-- Email (placeholder for future providers)
INSERT INTO platform_settings (setting_key, setting_value, updated_at) VALUES
  ('email_provider', NULL, NOW()),
  ('email_api_key', NULL, NOW())
ON DUPLICATE KEY UPDATE updated_at = VALUES(updated_at);

-- General platform
INSERT INTO platform_settings (setting_key, setting_value, updated_at) VALUES
  ('platform_support_email', NULL, NOW()),
  ('platform_support_phone', NULL, NOW())
ON DUPLICATE KEY UPDATE updated_at = VALUES(updated_at);

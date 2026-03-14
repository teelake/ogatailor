-- Platform currencies: admin-managed list for invoice currency dropdown.
-- Stored as JSON: [{"code":"NGN","symbol":"₦","name":"Nigerian Naira"}, ...]
INSERT INTO platform_settings (setting_key, setting_value, updated_at) VALUES
  ('platform_currencies', '[{"code":"NGN","symbol":"₦","name":"Nigerian Naira"},{"code":"USD","symbol":"$","name":"US Dollar"},{"code":"GBP","symbol":"£","name":"British Pound"}]', NOW())
ON DUPLICATE KEY UPDATE updated_at = VALUES(updated_at);

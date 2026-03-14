-- Plan prices for upgrade (in NGN, stored as integer for kobo: 5000 NGN = 500000)
INSERT INTO platform_settings (setting_key, setting_value, updated_at) VALUES
  ('plan_price_growth', '5000', NOW()),
  ('plan_price_pro', '10000', NOW())
ON DUPLICATE KEY UPDATE updated_at = VALUES(updated_at);

-- Platform URL and logo (used by mobile app)
INSERT INTO platform_settings (setting_key, setting_value, updated_at) VALUES
  ('platform_url', 'https://ogatailor.app', NOW())
ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_at = VALUES(updated_at);
INSERT INTO platform_settings (setting_key, setting_value, updated_at) VALUES
  ('platform_logo_url', '', NOW())
ON DUPLICATE KEY UPDATE updated_at = updated_at;

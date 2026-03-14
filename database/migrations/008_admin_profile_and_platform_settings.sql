-- Admin profile picture
ALTER TABLE admin_users
  ADD COLUMN profile_picture MEDIUMTEXT NULL AFTER full_name;

-- Platform-level settings (defaults for new users, feature toggles)
CREATE TABLE IF NOT EXISTS platform_settings (
    id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    setting_key VARCHAR(80) NOT NULL UNIQUE,
    setting_value TEXT NULL,
    updated_at DATETIME NOT NULL,
    KEY idx_platform_settings_key (setting_key)
);

-- Seed platform defaults (invoice, reminders, etc.)
INSERT INTO platform_settings (setting_key, setting_value, updated_at) VALUES
  ('invoice_default_currency', 'NGN', NOW()),
  ('invoice_default_vat_rate', '7.5', NOW()),
  ('invoice_default_payment_terms', 'Payment due within 7 days', NOW()),
  ('reminder_digest_enabled_default', '0', NOW()),
  ('reminder_days_before_due', '3', NOW()),
  ('logo_max_size_kb', '500', NOW()),
  ('logo_min_dimension', '64', NOW()),
  ('logo_max_dimension', '512', NOW())
ON DUPLICATE KEY UPDATE updated_at = VALUES(updated_at);

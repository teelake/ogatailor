-- Invoice watermark for plans not yet paid / lower tiers
-- watermark_type: logo | url | both
-- watermark_plans: comma-separated plan codes that get watermark (e.g. starter or starter,growth)
INSERT INTO platform_settings (setting_key, setting_value, updated_at) VALUES
  ('watermark_type', 'both', NOW()),
  ('watermark_logo_url', NULL, NOW()),
  ('watermark_website_url', 'https://ogatailor.app', NOW()),
  ('watermark_plans', 'starter', NOW())
ON DUPLICATE KEY UPDATE updated_at = VALUES(updated_at);

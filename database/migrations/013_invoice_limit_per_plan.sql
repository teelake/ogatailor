-- Invoice limit per plan (soft limit per month)
ALTER TABLE plan_settings
  ADD COLUMN invoices_per_month INT NULL AFTER can_advanced_reminders;

UPDATE plan_settings SET invoices_per_month = 25 WHERE plan_code = 'starter';
UPDATE plan_settings SET invoices_per_month = 100 WHERE plan_code = 'growth';
UPDATE plan_settings SET invoices_per_month = 500 WHERE plan_code = 'pro';

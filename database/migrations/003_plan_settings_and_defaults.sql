-- Migration: create configurable plan settings table and defaults.
-- Run this on existing databases after 002.

CREATE TABLE IF NOT EXISTS plan_settings (
  plan_code ENUM('starter', 'growth', 'pro') PRIMARY KEY,
  customer_limit INT NULL,
  can_sync TINYINT(1) NOT NULL DEFAULT 0,
  can_export TINYINT(1) NOT NULL DEFAULT 0,
  can_multi_device TINYINT(1) NOT NULL DEFAULT 0,
  can_advanced_reminders TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);

INSERT INTO plan_settings (
  plan_code, customer_limit, can_sync, can_export, can_multi_device, can_advanced_reminders, created_at, updated_at
) VALUES
  ('starter', 50, 0, 0, 0, 0, NOW(), NOW()),
  ('growth', 500, 1, 1, 0, 1, NOW(), NOW()),
  ('pro', NULL, 1, 1, 1, 1, NOW(), NOW())
ON DUPLICATE KEY UPDATE
  customer_limit = VALUES(customer_limit),
  can_sync = VALUES(can_sync),
  can_export = VALUES(can_export),
  can_multi_device = VALUES(can_multi_device),
  can_advanced_reminders = VALUES(can_advanced_reminders),
  updated_at = VALUES(updated_at);

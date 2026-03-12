-- Migration: add users.phone_number and move plan_code to starter/growth/pro.
-- Run this on existing databases.

ALTER TABLE users
  ADD COLUMN phone_number VARCHAR(20) NULL AFTER email;

UPDATE users SET plan_code = 'starter' WHERE plan_code = 'free';
UPDATE users SET plan_code = 'growth' WHERE plan_code = 'paid';

ALTER TABLE users
  MODIFY COLUMN plan_code ENUM('starter', 'growth', 'pro') NOT NULL DEFAULT 'starter';

-- Migration: add email_digest_enabled for daily order digest (Growth/Pro).
-- Run after 004.

ALTER TABLE users
  ADD COLUMN email_digest_enabled TINYINT(1) NOT NULL DEFAULT 0 AFTER plan_expires_at;

-- Migration: Add logo column to business_profiles for brand logo on invoices.
-- Run after 004/005.

ALTER TABLE business_profiles
  ADD COLUMN logo_data MEDIUMTEXT NULL COMMENT 'Base64-encoded logo (PNG/JPEG/WEBP, max 500KB, 64-512px)' AFTER payment_terms;

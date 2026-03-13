-- Migration: business profile and invoice setup for invoice feature.
-- Run this on existing databases after 003.
-- If business_name column already exists, comment out the ALTER below.

-- Add optional business/brand name to users (collected at signup).
ALTER TABLE users
  ADD COLUMN business_name VARCHAR(160) NULL AFTER full_name;

-- Business profile: invoice KYC (required before invoice generation).
CREATE TABLE IF NOT EXISTS business_profiles (
  id CHAR(36) PRIMARY KEY,
  owner_user_id CHAR(36) NOT NULL UNIQUE,
  business_name VARCHAR(160) NOT NULL,
  business_phone VARCHAR(20) NULL,
  business_email VARCHAR(160) NULL,
  business_address TEXT NULL,
  cac_registered TINYINT(1) NOT NULL DEFAULT 0,
  cac_registration_type ENUM('company', 'business') NULL,
  cac_number VARCHAR(40) NULL,
  vat_enabled TINYINT(1) NOT NULL DEFAULT 0,
  default_vat_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  currency VARCHAR(10) NOT NULL DEFAULT 'NGN',
  payment_terms VARCHAR(80) NULL,
  invoice_setup_completed_at DATETIME NULL,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  CONSTRAINT fk_business_profiles_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
  KEY idx_business_profiles_owner (owner_user_id)
);

-- Invoice items: line items for each invoice (one order = one line for MVP).
CREATE TABLE IF NOT EXISTS invoice_items (
  id CHAR(36) PRIMARY KEY,
  invoice_id CHAR(36) NOT NULL,
  description VARCHAR(255) NOT NULL,
  quantity DECIMAL(10,2) NOT NULL DEFAULT 1.00,
  unit_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  created_at DATETIME NOT NULL,
  CONSTRAINT fk_invoice_items_invoice FOREIGN KEY (invoice_id) REFERENCES invoices(id),
  KEY idx_invoice_items_invoice (invoice_id)
);

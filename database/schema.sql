CREATE TABLE IF NOT EXISTS users (
    id CHAR(36) PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    business_name VARCHAR(160) NULL,
    email VARCHAR(160) NULL UNIQUE,
    phone_number VARCHAR(20) NULL,
    password_hash VARCHAR(255) NULL,
    is_guest TINYINT(1) NOT NULL DEFAULT 0,
    guest_device_id VARCHAR(120) NULL UNIQUE,
    plan_code ENUM('starter', 'growth', 'pro') NOT NULL DEFAULT 'starter',
    plan_expires_at DATETIME NULL,
    email_digest_enabled TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL
);

CREATE TABLE IF NOT EXISTS auth_tokens (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    user_id CHAR(36) NOT NULL,
    token_hash CHAR(64) NOT NULL,
    expires_at DATETIME NULL,
    created_at DATETIME NOT NULL,
    CONSTRAINT fk_auth_tokens_user FOREIGN KEY (user_id) REFERENCES users(id),
    UNIQUE KEY uniq_auth_tokens_hash (token_hash),
    KEY idx_auth_tokens_user (user_id)
);

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

INSERT INTO plan_settings (plan_code, customer_limit, can_sync, can_export, can_multi_device, can_advanced_reminders, created_at, updated_at)
VALUES
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

CREATE TABLE IF NOT EXISTS customers (
    id CHAR(36) PRIMARY KEY,
    owner_user_id CHAR(36) NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    phone_number VARCHAR(20) NULL,
    gender VARCHAR(20) NULL,
    notes TEXT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    last_modified_at DATETIME NOT NULL,
    CONSTRAINT fk_customers_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
    UNIQUE KEY uniq_owner_phone (owner_user_id, phone_number),
    KEY idx_customers_owner (owner_user_id),
    KEY idx_customers_modified (last_modified_at)
);

CREATE TABLE IF NOT EXISTS measurements (
    id CHAR(36) PRIMARY KEY,
    customer_id CHAR(36) NOT NULL,
    taken_at DATETIME NOT NULL,
    payload_json JSON NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    last_modified_at DATETIME NOT NULL,
    CONSTRAINT fk_measurements_customer FOREIGN KEY (customer_id) REFERENCES customers(id),
    KEY idx_measurements_customer (customer_id),
    KEY idx_measurements_taken_at (taken_at),
    KEY idx_measurements_modified (last_modified_at)
);

CREATE TABLE IF NOT EXISTS devices (
    id CHAR(36) PRIMARY KEY,
    user_id CHAR(36) NOT NULL,
    device_name VARCHAR(120) NOT NULL,
    platform VARCHAR(40) NOT NULL,
    last_sync_cursor DATETIME NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    CONSTRAINT fk_devices_user FOREIGN KEY (user_id) REFERENCES users(id),
    KEY idx_devices_user (user_id)
);

CREATE TABLE IF NOT EXISTS sync_events (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    user_id CHAR(36) NOT NULL,
    entity_name VARCHAR(40) NOT NULL,
    entity_id CHAR(36) NOT NULL,
    operation ENUM('create', 'update', 'delete') NOT NULL,
    occurred_at DATETIME NOT NULL,
    KEY idx_sync_events_user_time (user_id, occurred_at),
    KEY idx_sync_events_entity (entity_name, entity_id)
);

CREATE TABLE IF NOT EXISTS orders (
    id CHAR(36) PRIMARY KEY,
    owner_user_id CHAR(36) NOT NULL,
    customer_id CHAR(36) NOT NULL,
    title VARCHAR(160) NOT NULL,
    status ENUM('pending', 'in_progress', 'ready', 'delivered', 'cancelled') NOT NULL DEFAULT 'pending',
    due_date DATETIME NULL,
    amount_total DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    notes TEXT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    last_modified_at DATETIME NOT NULL,
    CONSTRAINT fk_orders_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(id),
    KEY idx_orders_owner (owner_user_id),
    KEY idx_orders_customer (customer_id),
    KEY idx_orders_status (status),
    KEY idx_orders_modified (last_modified_at)
);

CREATE TABLE IF NOT EXISTS invoices (
    id CHAR(36) PRIMARY KEY,
    owner_user_id CHAR(36) NOT NULL,
    order_id CHAR(36) NOT NULL,
    invoice_number VARCHAR(40) NOT NULL,
    subtotal_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    discount_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    issued_at DATETIME NOT NULL,
    due_at DATETIME NULL,
    status ENUM('draft', 'issued', 'paid', 'partially_paid', 'overdue') NOT NULL DEFAULT 'draft',
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    last_modified_at DATETIME NOT NULL,
    CONSTRAINT fk_invoices_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
    CONSTRAINT fk_invoices_order FOREIGN KEY (order_id) REFERENCES orders(id),
    UNIQUE KEY uniq_invoice_owner_number (owner_user_id, invoice_number),
    KEY idx_invoices_owner (owner_user_id),
    KEY idx_invoices_order (order_id),
    KEY idx_invoices_status (status),
    KEY idx_invoices_modified (last_modified_at)
);

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
    logo_data MEDIUMTEXT NULL,
    invoice_setup_completed_at DATETIME NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    CONSTRAINT fk_business_profiles_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
    KEY idx_business_profiles_owner (owner_user_id)
);

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

CREATE TABLE IF NOT EXISTS payments (
    id CHAR(36) PRIMARY KEY,
    owner_user_id CHAR(36) NOT NULL,
    invoice_id CHAR(36) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    method ENUM('cash', 'transfer', 'pos', 'card', 'other') NOT NULL,
    reference_code VARCHAR(80) NULL,
    paid_at DATETIME NOT NULL,
    notes TEXT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    last_modified_at DATETIME NOT NULL,
    CONSTRAINT fk_payments_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
    CONSTRAINT fk_payments_invoice FOREIGN KEY (invoice_id) REFERENCES invoices(id),
    KEY idx_payments_owner (owner_user_id),
    KEY idx_payments_invoice (invoice_id),
    KEY idx_payments_paid_at (paid_at),
    KEY idx_payments_modified (last_modified_at)
);

CREATE TABLE IF NOT EXISTS business_records (
    id CHAR(36) PRIMARY KEY,
    owner_user_id CHAR(36) NOT NULL,
    record_type ENUM('income', 'expense', 'note') NOT NULL,
    title VARCHAR(160) NOT NULL,
    amount DECIMAL(12,2) NULL,
    occurred_at DATETIME NOT NULL,
    payload_json JSON NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    last_modified_at DATETIME NOT NULL,
    CONSTRAINT fk_business_records_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
    KEY idx_business_records_owner (owner_user_id),
    KEY idx_business_records_type (record_type),
    KEY idx_business_records_occurred_at (occurred_at),
    KEY idx_business_records_modified (last_modified_at)
);

CREATE TABLE IF NOT EXISTS admin_users (
    id CHAR(36) PRIMARY KEY,
    email VARCHAR(160) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    profile_picture MEDIUMTEXT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL
);

CREATE TABLE IF NOT EXISTS admin_sessions (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    admin_user_id CHAR(36) NOT NULL,
    token_hash CHAR(64) NOT NULL,
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL,
    CONSTRAINT fk_admin_sessions_admin FOREIGN KEY (admin_user_id) REFERENCES admin_users(id) ON DELETE CASCADE,
    UNIQUE KEY uniq_admin_sessions_hash (token_hash),
    KEY idx_admin_sessions_admin (admin_user_id)
);

INSERT INTO admin_users (id, email, password_hash, full_name, created_at, updated_at)
VALUES (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'admin@ogatailor.app',
    '$2y$10$ejzP7pSwovgd/mHjw.u0muweaYbJ4azFaUa.zn/c2V.2x8lOzvcwO',
    'Platform Admin',
    NOW(),
    NOW()
) ON DUPLICATE KEY UPDATE updated_at = NOW();

CREATE TABLE IF NOT EXISTS platform_settings (
    id INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    setting_key VARCHAR(80) NOT NULL UNIQUE,
    setting_value TEXT NULL,
    updated_at DATETIME NOT NULL,
    KEY idx_platform_settings_key (setting_key)
);

INSERT INTO platform_settings (setting_key, setting_value, updated_at) VALUES
  ('invoice_default_currency', 'NGN', NOW()),
  ('invoice_default_vat_rate', '7.5', NOW()),
  ('invoice_default_payment_terms', 'Payment due within 7 days', NOW()),
  ('reminder_digest_enabled_default', '0', NOW()),
  ('reminder_days_before_due', '3', NOW()),
  ('logo_max_size_kb', '500', NOW()),
  ('logo_min_dimension', '64', NOW()),
  ('logo_max_dimension', '512', NOW()),
  ('paystack_secret_key', NULL, NOW()),
  ('paystack_public_key', NULL, NOW()),
  ('paystack_test_mode', '1', NOW()),
  ('sms_provider', NULL, NOW()),
  ('sms_api_key', NULL, NOW()),
  ('email_provider', NULL, NOW()),
  ('email_api_key', NULL, NOW()),
  ('platform_support_email', NULL, NOW()),
  ('platform_support_phone', NULL, NOW()),
  ('watermark_type', 'both', NOW()),
  ('watermark_logo_url', NULL, NOW()),
  ('watermark_website_url', 'https://ogatailor.app', NOW()),
  ('watermark_plans', 'starter', NOW())
ON DUPLICATE KEY UPDATE updated_at = VALUES(updated_at);

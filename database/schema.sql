CREATE TABLE IF NOT EXISTS users (
    id CHAR(36) PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(160) NULL UNIQUE,
    password_hash VARCHAR(255) NULL,
    is_guest TINYINT(1) NOT NULL DEFAULT 0,
    guest_device_id VARCHAR(120) NULL UNIQUE,
    plan_code ENUM('free', 'paid') NOT NULL DEFAULT 'free',
    plan_expires_at DATETIME NULL,
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

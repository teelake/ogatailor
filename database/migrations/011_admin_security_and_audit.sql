-- Admin login attempts (brute-force protection)
CREATE TABLE IF NOT EXISTS admin_login_attempts (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(160) NOT NULL,
    ip_address VARCHAR(45) NULL,
    attempted_at DATETIME NOT NULL,
    KEY idx_login_attempts_email (email),
    KEY idx_login_attempts_time (attempted_at)
);

-- Admin password reset tokens
CREATE TABLE IF NOT EXISTS admin_password_reset_tokens (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    admin_user_id CHAR(36) NOT NULL,
    token_hash CHAR(64) NOT NULL,
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL,
    CONSTRAINT fk_reset_admin FOREIGN KEY (admin_user_id) REFERENCES admin_users(id) ON DELETE CASCADE,
    UNIQUE KEY uniq_reset_token (token_hash),
    KEY idx_reset_admin (admin_user_id),
    KEY idx_reset_expires (expires_at)
);

-- Admin audit log
CREATE TABLE IF NOT EXISTS admin_audit_log (
    id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
    admin_user_id CHAR(36) NULL,
    action VARCHAR(80) NOT NULL,
    entity_type VARCHAR(40) NULL,
    entity_id VARCHAR(36) NULL,
    details JSON NULL,
    ip_address VARCHAR(45) NULL,
    created_at DATETIME NOT NULL,
    KEY idx_audit_admin (admin_user_id),
    KEY idx_audit_action (action),
    KEY idx_audit_created (created_at)
);

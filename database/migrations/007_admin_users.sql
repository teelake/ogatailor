-- Admin users (super-admin only, separate from regular users)
CREATE TABLE IF NOT EXISTS admin_users (
    id CHAR(36) PRIMARY KEY,
    email VARCHAR(160) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(120) NOT NULL,
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

-- Seed default admin (password: admin123) - CHANGE IN PRODUCTION
INSERT INTO admin_users (id, email, password_hash, full_name, created_at, updated_at)
VALUES (
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'admin@ogatailor.app',
    '$2y$10$ejzP7pSwovgd/mHjw.u0muweaYbJ4azFaUa.zn/c2V.2x8lOzvcwO',
    'Platform Admin',
    NOW(),
    NOW()
) ON DUPLICATE KEY UPDATE updated_at = NOW();

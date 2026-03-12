INSERT INTO users (id, full_name, email, password_hash, plan_code, plan_expires_at, created_at, updated_at)
VALUES (
    '11111111-1111-4111-8111-111111111111',
    'Demo Tailor',
    'demo@ogatailor.app',
    '$2y$10$hR8c03fLA6Q.bjM2qf86n.L0EJAMrLf6blW4yqAhrYYg9jY3qp6mS',
    'starter',
    NULL,
    NOW(),
    NOW()
);

<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';

if (adminLoggedIn()) {
    $base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
    header('Location: ' . ($base ?: '/') . '/');
    exit;
}

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = strtolower(trim((string)($_POST['email'] ?? '')));
    $password = (string)($_POST['password'] ?? '');

    if ($email === '' || $password === '') {
        $error = 'Email and password are required.';
    } else {
        $stmt = $pdo->prepare(
            'SELECT id, email, full_name, password_hash, profile_picture FROM admin_users WHERE email = :email LIMIT 1'
        );
        $stmt->execute([':email' => $email]);
        $admin = $stmt->fetch();

        if (!$admin || !password_verify($password, (string)$admin['password_hash'])) {
            $error = 'Invalid email or password.';
        } else {
            $_SESSION['admin_id'] = $admin['id'];
            $_SESSION['admin_email'] = $admin['email'];
            $_SESSION['admin_name'] = $admin['full_name'];
            $_SESSION['admin_profile_picture'] = $admin['profile_picture'] ?? null;
            $base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
            header('Location: ' . ($base ?: '/') . '/');
            exit;
        }
    }
}

$base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
$base = $base ?: '/';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Oga Tailor Admin - Sign In</title>
    <link rel="stylesheet" href="<?= $base ?>/style.css">
</head>
<body class="login-page">
    <div class="login-card">
        <div class="login-header">
            <div class="logo">Oga Tailor</div>
            <h1>Admin</h1>
            <p>Sign in to manage your platform</p>
        </div>
        <form method="post" class="login-form">
            <?php if ($error): ?>
                <p class="error"><?= escapeHtml($error) ?></p>
            <?php endif; ?>
            <div class="field">
                <label for="email">Email</label>
                <input type="email" id="email" name="email" value="<?= escapeHtml($_POST['email'] ?? '') ?>" placeholder="admin@ogatailor.app" required autocomplete="email">
            </div>
            <div class="field">
                <label for="password">Password</label>
                <input type="password" id="password" name="password" placeholder="••••••••" required autocomplete="current-password">
            </div>
            <button type="submit" class="btn btn-primary">Sign in</button>
        </form>
    </div>
</body>
</html>

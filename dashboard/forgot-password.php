<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';

if (adminLoggedIn()) {
    $base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
    header('Location: ' . ($base ?: '/') . '/');
    exit;
}

$message = '';
$error = '';
$base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
$base = $base ?: '/';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (!verifyCsrf()) {
        $error = 'Invalid request. Please refresh and try again.';
    } else {
        $email = strtolower(trim((string)($_POST['email'] ?? '')));
        if ($email === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $error = 'Please enter a valid email address.';
        } else {
            $stmt = $pdo->prepare('SELECT id FROM admin_users WHERE email = :email LIMIT 1');
            $stmt->execute([':email' => $email]);
            $admin = $stmt->fetch();
            if (!$admin) {
                $message = 'If that email exists, a reset link has been sent.';
            } else {
                $token = bin2hex(random_bytes(32));
                $hash = hash('sha256', $token);
                $expires = date('Y-m-d H:i:s', time() + 3600);
                $pdo->prepare('DELETE FROM admin_password_reset_tokens WHERE admin_user_id = :id')->execute([':id' => $admin['id']]);
                $pdo->prepare(
                    'INSERT INTO admin_password_reset_tokens (admin_user_id, token_hash, expires_at, created_at) VALUES (:id, :hash, :exp, NOW())'
                )->execute([':id' => $admin['id'], ':hash' => $hash, ':exp' => $expires]);
                $resetUrl = ($_SERVER['REQUEST_SCHEME'] ?? 'https') . '://' . ($_SERVER['HTTP_HOST'] ?? '') . $base . '/reset-password?token=' . $token;
                $emailProvider = $pdo->query("SELECT setting_value FROM platform_settings WHERE setting_key = 'email_provider'")->fetchColumn();
                if ($emailProvider) {
                    $apiKey = $pdo->query("SELECT setting_value FROM platform_settings WHERE setting_key = 'email_api_key'")->fetchColumn();
                    if ($apiKey) {
                        error_log("Admin reset link for {$email}: {$resetUrl}");
                    }
                }
                error_log("Admin password reset: {$resetUrl}");
                $message = 'If that email exists, a reset link has been sent. Check your inbox or contact another admin.';
            }
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Oga Tailor Admin - Forgot Password</title>
    <link rel="stylesheet" href="<?= $base ?>/style.css">
</head>
<body class="login-page">
    <div class="login-card">
        <div class="login-header">
            <div class="logo">Oga Tailor</div>
            <h1>Forgot password</h1>
            <p>Enter your email to receive a reset link</p>
        </div>
        <form method="post" class="login-form">
            <?= csrfField() ?>
            <?php if ($error): ?>
                <p class="login-error"><?= escapeHtml($error) ?></p>
            <?php endif; ?>
            <?php if ($message): ?>
                <p class="login-success"><?= escapeHtml($message) ?></p>
            <?php endif; ?>
            <div class="field">
                <label for="email">Email</label>
                <input type="email" id="email" name="email" value="<?= escapeHtml($_POST['email'] ?? '') ?>" required autocomplete="email">
            </div>
            <button type="submit" class="btn btn-primary">Send reset link</button>
            <p class="login-footer"><a href="<?= $base ?>/login">Back to sign in</a></p>
        </form>
    </div>
</body>
</html>

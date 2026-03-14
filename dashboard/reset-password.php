<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';

if (adminLoggedIn()) {
    $base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
    header('Location: ' . ($base ?: '/') . '/');
    exit;
}

$error = '';
$message = '';
$base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
$base = $base ?: '/';
$token = trim((string)($_GET['token'] ?? $_POST['token'] ?? ''));

if ($token === '') {
    $error = 'Invalid or expired reset link.';
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && $token !== '' && !$error) {
    if (!verifyCsrf()) {
        $error = 'Invalid request. Please refresh and try again.';
    } else {
        $new = (string)($_POST['new_password'] ?? '');
        $confirm = (string)($_POST['confirm_password'] ?? '');
        if (strlen($new) < 6) {
            $error = 'Password must be at least 6 characters.';
        } elseif ($new !== $confirm) {
            $error = 'Passwords do not match.';
        } else {
            $hash = hash('sha256', $token);
            $stmt = $pdo->prepare(
                'SELECT t.admin_user_id FROM admin_password_reset_tokens t WHERE t.token_hash = :hash AND t.expires_at > NOW() LIMIT 1'
            );
            $stmt->execute([':hash' => $hash]);
            $row = $stmt->fetch();
            if (!$row) {
                $error = 'Invalid or expired reset link.';
            } else {
                $pdo->prepare('UPDATE admin_users SET password_hash = :hash, updated_at = NOW() WHERE id = :id')
                    ->execute([':hash' => password_hash($new, PASSWORD_DEFAULT), ':id' => $row['admin_user_id']]);
                $pdo->prepare('DELETE FROM admin_password_reset_tokens WHERE admin_user_id = :id')
                    ->execute([':id' => $row['admin_user_id']]);
                $message = 'Password reset. <a href="' . $base . '/login">Sign in</a>';
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
    <title>Oga Tailor Admin - Reset Password</title>
    <link rel="stylesheet" href="<?= $base ?>/style.css">
</head>
<body class="login-page">
    <div class="login-card">
        <div class="login-header">
            <div class="logo">Oga Tailor</div>
            <h1>Reset password</h1>
            <p>Enter your new password</p>
        </div>
        <?php if ($message): ?>
            <p class="login-success"><?= $message ?></p>
        <?php elseif ($error && $_SERVER['REQUEST_METHOD'] !== 'POST'): ?>
            <p class="login-error"><?= escapeHtml($error) ?></p>
            <p class="login-footer"><a href="<?= $base ?>/login">Back to sign in</a></p>
        <?php else: ?>
        <form method="post" class="login-form">
            <?= csrfField() ?>
            <input type="hidden" name="token" value="<?= escapeHtml($token) ?>">
            <?php if ($error): ?>
                <p class="login-error"><?= escapeHtml($error) ?></p>
            <?php endif; ?>
            <div class="field">
                <label for="new_password">New password</label>
                <input type="password" id="new_password" name="new_password" required minlength="6" autocomplete="new-password">
            </div>
            <div class="field">
                <label for="confirm_password">Confirm password</label>
                <input type="password" id="confirm_password" name="confirm_password" required minlength="6" autocomplete="new-password">
            </div>
            <button type="submit" class="btn btn-primary">Reset password</button>
            <p class="login-footer"><a href="<?= $base ?>/login">Back to sign in</a></p>
        </form>
        <?php endif; ?>
    </div>
</body>
</html>

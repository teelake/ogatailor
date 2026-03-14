<?php

declare(strict_types=1);

$logDir = dirname(__DIR__) . '/backend/storage/logs';
$logFile = $logDir . '/php-error.log';
if (!is_dir($logDir)) {
    @mkdir($logDir, 0775, true);
}
ini_set('log_errors', '1');
ini_set('error_log', $logFile);
error_reporting(E_ALL);

require_once dirname(__DIR__) . '/backend/bootstrap.php';

use App\Database\Connection;

$sessionLifetime = 3600; // 1 hour
$rememberLifetime = 2592000; // 30 days
if (session_status() === PHP_SESSION_NONE) {
    ini_set('session.gc_maxlifetime', (string)$sessionLifetime);
    session_set_cookie_params([
        'lifetime' => 0,
        'path' => '/',
        'secure' => isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on',
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
    session_start();
}

$pdo = Connection::make();

function adminLoggedIn(): bool
{
    if (empty($_SESSION['admin_id'])) return false;
    $maxIdle = !empty($_SESSION['remember']) ? 604800 : 3600; // 7 days or 1 hour
    if (!empty($_SESSION['last_activity']) && (time() - $_SESSION['last_activity'] > $maxIdle)) {
        $_SESSION = [];
        return false;
    }
    $_SESSION['last_activity'] = time();
    return true;
}

function requireAdmin(): void
{
    if (!adminLoggedIn()) {
        $base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
        header('Location: ' . ($base ?: '/') . '/login');
        exit;
    }
}

function adminUser(): ?array
{
    if (!adminLoggedIn()) return null;
    return [
        'id' => $_SESSION['admin_id'],
        'email' => $_SESSION['admin_email'] ?? '',
        'full_name' => $_SESSION['admin_name'] ?? '',
        'profile_picture' => $_SESSION['admin_profile_picture'] ?? null,
    ];
}

function refreshAdminSession(\PDO $pdo): void
{
    if (!adminLoggedIn()) return;
    $stmt = $pdo->prepare('SELECT full_name, email, profile_picture FROM admin_users WHERE id = :id');
    $stmt->execute([':id' => $_SESSION['admin_id']]);
    $row = $stmt->fetch();
    if ($row) {
        $_SESSION['admin_name'] = $row['full_name'];
        $_SESSION['admin_email'] = $row['email'];
        $_SESSION['admin_profile_picture'] = $row['profile_picture'];
    }
}

function escapeHtml(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}

function csrfToken(): string
{
    if (empty($_SESSION['csrf_token'])) {
        $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf_token'];
}

function csrfField(): string
{
    return '<input type="hidden" name="_csrf" value="' . escapeHtml(csrfToken()) . '">';
}

function verifyCsrf(): bool
{
    $token = $_POST['_csrf'] ?? '';
    return !empty($token) && hash_equals(csrfToken(), $token);
}

function requireCsrf(): void
{
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && !verifyCsrf()) {
        http_response_code(403);
        die('Invalid request. Please refresh and try again.');
    }
}

function adminAuditLog(\PDO $pdo, string $action, ?string $entityType = null, ?string $entityId = null, ?array $details = null): void
{
    $stmt = $pdo->prepare(
        'INSERT INTO admin_audit_log (admin_user_id, action, entity_type, entity_id, details, ip_address, created_at)
         VALUES (:aid, :action, :etype, :eid, :details, :ip, NOW())'
    );
    $stmt->execute([
        ':aid' => $_SESSION['admin_id'] ?? null,
        ':action' => $action,
        ':etype' => $entityType,
        ':eid' => $entityId,
        ':details' => $details ? json_encode($details) : null,
        ':ip' => $_SERVER['REMOTE_ADDR'] ?? null,
    ]);
}

function recordLoginAttempt(\PDO $pdo, string $email, bool $success): void
{
    if ($success) return;
    $stmt = $pdo->prepare('INSERT INTO admin_login_attempts (email, ip_address, attempted_at) VALUES (:email, :ip, NOW())');
    $stmt->execute([':email' => $email, ':ip' => $_SERVER['REMOTE_ADDR'] ?? null]);
}

function isLoginLocked(\PDO $pdo, string $email): bool
{
    $stmt = $pdo->prepare(
        'SELECT COUNT(*) FROM admin_login_attempts WHERE email = :email AND attempted_at > DATE_SUB(NOW(), INTERVAL 15 MINUTE)'
    );
    $stmt->execute([':email' => $email]);
    return (int)$stmt->fetchColumn() >= 5;
}

function clearLoginAttempts(\PDO $pdo, string $email): void
{
    $pdo->prepare('DELETE FROM admin_login_attempts WHERE email = :email')->execute([':email' => $email]);
}

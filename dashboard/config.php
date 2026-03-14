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

session_start();

$pdo = Connection::make();

function adminLoggedIn(): bool
{
    return !empty($_SESSION['admin_id']);
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
    if (!adminLoggedIn()) {
        return null;
    }
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

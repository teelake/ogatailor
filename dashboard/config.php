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
        header('Location: login.php');
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
    ];
}

function escapeHtml(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}

<?php

declare(strict_types=1);

use App\Config\Env;

spl_autoload_register(static function (string $class): void {
    $prefix = 'App\\';
    $baseDir = __DIR__ . '/src/';

    if (!str_starts_with($class, $prefix)) {
        return;
    }

    $relativeClass = substr($class, strlen($prefix));
    $file = $baseDir . str_replace('\\', '/', $relativeClass) . '.php';

    if (is_file($file)) {
        require_once $file;
    }
});

$envPath = __DIR__ . '/.env';
if (!is_file($envPath) && is_file(__DIR__ . '/.env.example')) {
    $envPath = __DIR__ . '/.env.example';
}

Env::load($envPath);

$appDebug = Env::getBool('APP_DEBUG', false);
$logDir = __DIR__ . '/storage/logs';
if (!is_dir($logDir)) {
    @mkdir($logDir, 0775, true);
}
$logFile = $logDir . '/php-error.log';

ini_set('log_errors', '1');
ini_set('error_log', $logFile);
ini_set('display_errors', $appDebug ? '1' : '0');
error_reporting(E_ALL);

// Ensure we always return JSON on uncaught errors (prevents "Invalid response from server" when client expects JSON)
set_exception_handler(static function (Throwable $e) use ($appDebug): void {
    error_log('Uncaught exception: ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    if (!headers_sent()) {
        http_response_code(500);
        header('Content-Type: application/json; charset=utf-8');
    }
    echo json_encode([
        'error' => $appDebug ? $e->getMessage() : 'An unexpected error occurred. Please try again.',
    ], JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
});

register_shutdown_function(static function () use ($appDebug): void {
    $err = error_get_last();
    if ($err !== null && in_array($err['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR], true)) {
        if (!headers_sent()) {
            http_response_code(500);
            header('Content-Type: application/json; charset=utf-8');
        }
        $msg = $appDebug ? ($err['message'] ?? 'Fatal error') : 'An unexpected error occurred. Please try again.';
        echo json_encode(['error' => $msg], JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
    }
});

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

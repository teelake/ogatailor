<?php

declare(strict_types=1);

namespace App\Config;

final class Env
{
    private static array $vars = [];
    private const TRUE_VALUES = ['1', 'true', 'yes', 'on'];

    public static function load(string $path): void
    {
        if (!is_file($path)) {
            return;
        }

        $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if ($lines === false) {
            return;
        }

        foreach ($lines as $line) {
            $trimmed = trim($line);
            if ($trimmed === '' || str_starts_with($trimmed, '#')) {
                continue;
            }

            $parts = explode('=', $trimmed, 2);
            if (count($parts) !== 2) {
                continue;
            }

            [$key, $value] = $parts;
            self::$vars[trim($key)] = trim($value);
        }
    }

    public static function get(string $key, ?string $default = null): ?string
    {
        return self::$vars[$key] ?? $default;
    }

    public static function getInt(string $key, int $default): int
    {
        $raw = self::get($key, (string)$default);
        if ($raw === null) {
            return $default;
        }
        $value = trim($raw);
        if ($value === '' || !is_numeric($value)) {
            return $default;
        }
        return (int)$value;
    }

    public static function getBool(string $key, bool $default = false): bool
    {
        $raw = self::get($key, $default ? 'true' : 'false');
        if ($raw === null) {
            return $default;
        }
        return in_array(strtolower(trim($raw)), self::TRUE_VALUES, true);
    }
}

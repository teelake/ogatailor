<?php

declare(strict_types=1);

namespace App\Http;

final class Response
{
    public static function json(array $data, int $statusCode = 200): void
    {
        http_response_code($statusCode);
        header('Content-Type: application/json; charset=utf-8');
        $encoded = json_encode($data, JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE);
        if ($encoded === false) {
            $encoded = json_encode(['error' => 'Failed to encode response']);
        }
        echo $encoded;
    }
}

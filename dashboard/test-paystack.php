<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
requireAdmin();

header('Content-Type: application/json');

$stmt = $pdo->prepare('SELECT setting_value FROM platform_settings WHERE setting_key = :key');
$stmt->execute([':key' => 'paystack_secret_key']);
$secret = $stmt->fetchColumn();

if (!$secret) {
    echo json_encode(['ok' => false, 'error' => 'No secret key configured']);
    exit;
}

$ch = curl_init('https://api.paystack.co/balance');
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => ['Authorization: Bearer ' . $secret],
]);
$res = curl_exec($ch);
$code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($code === 200) {
    $data = json_decode($res, true);
    echo json_encode(['ok' => true, 'message' => 'Connection successful', 'balance' => $data['data'][0]['balance'] ?? null]);
} else {
    $err = json_decode($res, true);
    echo json_encode(['ok' => false, 'error' => $err['message'] ?? 'Connection failed']);
}

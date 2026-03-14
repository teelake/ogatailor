<?php

declare(strict_types=1);

require_once __DIR__ . '/backend/bootstrap.php';

use App\Config\Env;
use App\Database\Connection;

$reference = trim((string)($_GET['reference'] ?? ''));

header('Content-Type: text/html; charset=utf-8');

if ($reference === '') {
    echo '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Payment</title></head><body style="font-family:sans-serif;padding:24px;text-align:center;"><h2>Invalid request</h2><p>No payment reference provided.</p></body></html>';
    exit;
}

try {
    $pdo = Connection::make();
} catch (Throwable $e) {
    error_log('Upgrade callback DB error: ' . $e->getMessage());
    echo '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Payment</title></head><body style="font-family:sans-serif;padding:24px;text-align:center;"><h2>Error</h2><p>Unable to verify payment. Please contact support.</p></body></html>';
    exit;
}

$stmt = $pdo->prepare('SELECT setting_value FROM platform_settings WHERE setting_key = :key');
$stmt->execute([':key' => 'paystack_secret_key']);
$secret = $stmt->fetchColumn();
if (!$secret || trim($secret) === '') {
    echo '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Payment</title></head><body style="font-family:sans-serif;padding:24px;text-align:center;"><h2>Configuration error</h2><p>Payment not configured.</p></body></html>';
    exit;
}

$ch = curl_init('https://api.paystack.co/transaction/verify/' . rawurlencode($reference));
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_HTTPHEADER => ['Authorization: Bearer ' . $secret],
]);
$res = curl_exec($ch);
$code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$result = json_decode($res, true);
if ($code !== 200 || empty($result['status']) || !$result['status']) {
    $msg = $result['message'] ?? 'Verification failed';
    error_log('Paystack verify failed: ' . $res);
    echo '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Payment</title></head><body style="font-family:sans-serif;padding:24px;text-align:center;"><h2>Verification failed</h2><p>' . htmlspecialchars($msg) . '</p></body></html>';
    exit;
}

$data = $result['data'] ?? [];
if (($data['status'] ?? '') !== 'success') {
    echo '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Payment</title></head><body style="font-family:sans-serif;padding:24px;text-align:center;"><h2>Payment not completed</h2><p>This payment was not successful.</p></body></html>';
    exit;
}

$metadata = $data['metadata'] ?? [];
$userId = trim((string)($metadata['user_id'] ?? ''));
$planCode = strtolower(trim((string)($metadata['plan_code'] ?? '')));

if ($userId === '' || !in_array($planCode, ['growth', 'pro'], true)) {
    error_log('Upgrade callback: invalid metadata user_id=' . $userId . ' plan_code=' . $planCode);
    echo '<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Payment</title></head><body style="font-family:sans-serif;padding:24px;text-align:center;"><h2>Invalid payment data</h2><p>Please contact support.</p></body></html>';
    exit;
}

$expiresAt = (new DateTimeImmutable('now'))->modify('+1 year')->format('Y-m-d H:i:s');
$updateStmt = $pdo->prepare(
    'UPDATE users SET plan_code = :plan_code, plan_expires_at = :expires_at, updated_at = NOW() WHERE id = :id'
);
$updateStmt->execute([
    ':plan_code' => $planCode,
    ':expires_at' => $expiresAt,
    ':id' => $userId,
]);

$planName = ucfirst($planCode);
?>
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Payment Successful</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; padding: 24px; text-align: center; max-width: 400px; margin: 0 auto; }
        .success { color: #10b981; font-size: 48px; margin-bottom: 16px; }
        h2 { margin-bottom: 8px; }
        p { color: #6b7280; }
    </style>
</head>
<body>
    <div class="success">✓</div>
    <h2>Payment Successful</h2>
    <p>You are now on the <strong><?= htmlspecialchars($planName) ?></strong> plan.</p>
    <p>You can close this page and return to the app.</p>
</body>
</html>

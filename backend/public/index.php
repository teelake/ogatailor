<?php

declare(strict_types=1);

use App\Database\Connection;
use App\Http\Response;
use App\Support\Uuid;

require_once dirname(__DIR__) . '/bootstrap.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Access-Control-Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS');

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$scriptDir = rtrim(str_replace('\\', '/', dirname($_SERVER['SCRIPT_NAME'] ?? '')), '/');
$configuredBasePath = trim((string) \App\Config\Env::get('APP_BASE_PATH', ''), '/');
$basePath = $configuredBasePath !== '' ? '/' . $configuredBasePath : $scriptDir;

if ($basePath !== '' && $basePath !== '.' && str_starts_with($uri, $basePath . '/')) {
    $uri = substr($uri, strlen($basePath));
} elseif ($basePath !== '' && $basePath !== '.' && $uri === $basePath) {
    $uri = '/';
}

if (str_starts_with($uri, '/index.php/')) {
    $uri = substr($uri, strlen('/index.php'));
} elseif ($uri === '/index.php') {
    $uri = '/';
}

$path = rtrim($uri, '/') ?: '/';
if ($path !== '/' && str_starts_with($path, '/oga-tailor/')) {
    $path = substr($path, strlen('/oga-tailor'));
    $path = $path === '' ? '/' : $path;
}

if ($method === 'OPTIONS') {
    http_response_code(204);
    return;
}

function requestBody(): array
{
    $raw = file_get_contents('php://input');
    if (!$raw) {
        return [];
    }

    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

function issueAuthToken(\PDO $pdo, string $userId): string
{
    $plainToken = bin2hex(random_bytes(32));
    $tokenHash = hash('sha256', $plainToken);
    $ttlDays = max(1, \App\Config\Env::getInt('AUTH_TOKEN_TTL_DAYS', 30));
    $expiresAt = (new \DateTimeImmutable('now'))
        ->modify('+' . $ttlDays . ' days')
        ->format('Y-m-d H:i:s');

    $stmt = $pdo->prepare(
        'INSERT INTO auth_tokens (user_id, token_hash, expires_at, created_at)
         VALUES (:user_id, :token_hash, :expires_at, NOW())'
    );
    $stmt->execute([
        ':user_id' => $userId,
        ':token_hash' => $tokenHash,
        ':expires_at' => $expiresAt,
    ]);

    return $plainToken;
}

function validateRequired(array $data, array $required): ?string
{
    foreach ($required as $field) {
        $value = $data[$field] ?? null;
        if ($value === null || (is_string($value) && trim($value) === '')) {
            return $field;
        }
    }
    return null;
}

function normalizeCustomerName(string $name): string
{
    $name = trim(preg_replace('/\s+/', ' ', $name));
    return ucwords(strtolower($name));
}

function bearerToken(): ?string
{
    $raw = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if ($raw === '' || !str_starts_with($raw, 'Bearer ')) {
        return null;
    }
    return trim(substr($raw, 7));
}

function authenticatedAdmin(\PDO $pdo): ?array
{
    $token = bearerToken();
    if ($token === null || $token === '') {
        return null;
    }
    $tokenHash = hash('sha256', $token);
    $stmt = $pdo->prepare(
        'SELECT a.id, a.email, a.full_name
         FROM admin_sessions s
         INNER JOIN admin_users a ON a.id = s.admin_user_id
         WHERE s.token_hash = :token_hash AND s.expires_at > NOW()
         LIMIT 1'
    );
    $stmt->execute([':token_hash' => $tokenHash]);
    $admin = $stmt->fetch();
    return $admin ?: null;
}

function issueAdminToken(\PDO $pdo, string $adminId): string
{
    $plainToken = bin2hex(random_bytes(32));
    $tokenHash = hash('sha256', $plainToken);
    $expiresAt = (new \DateTimeImmutable('now'))
        ->modify('+7 days')
        ->format('Y-m-d H:i:s');
    $stmt = $pdo->prepare(
        'INSERT INTO admin_sessions (admin_user_id, token_hash, expires_at, created_at)
         VALUES (:admin_user_id, :token_hash, :expires_at, NOW())'
    );
    $stmt->execute([
        ':admin_user_id' => $adminId,
        ':token_hash' => $tokenHash,
        ':expires_at' => $expiresAt,
    ]);
    return $plainToken;
}

function authenticatedUser(\PDO $pdo): ?array
{
    $token = bearerToken();
    if ($token === null || $token === '') {
        return null;
    }

    $tokenHash = hash('sha256', $token);
    $stmt = $pdo->prepare(
        'SELECT u.id, u.plan_code, u.is_guest
         FROM auth_tokens t
         INNER JOIN users u ON u.id = t.user_id
         WHERE t.token_hash = :token_hash
           AND (t.expires_at IS NULL OR t.expires_at > NOW())
         LIMIT 1'
    );
    $stmt->execute([':token_hash' => $tokenHash]);
    $user = $stmt->fetch();
    return $user ?: null;
}

function planSettingDefaults(string $planCode): array
{
    $plan = strtolower(trim($planCode));
    if ($plan === 'growth') {
        return [
            'plan_code' => 'growth',
            'customer_limit' => 500,
            'can_sync' => 1,
            'can_export' => 1,
            'can_multi_device' => 0,
            'can_advanced_reminders' => 1,
        ];
    }
    if ($plan === 'pro') {
        return [
            'plan_code' => 'pro',
            'customer_limit' => null,
            'can_sync' => 1,
            'can_export' => 1,
            'can_multi_device' => 1,
            'can_advanced_reminders' => 1,
        ];
    }

    return [
        'plan_code' => 'starter',
        'customer_limit' => 50,
        'can_sync' => 0,
        'can_export' => 0,
        'can_multi_device' => 0,
        'can_advanced_reminders' => 0,
    ];
}

function planSettings(\PDO $pdo, string $planCode): array
{
    $normalized = strtolower(trim($planCode));
    if (!in_array($normalized, ['starter', 'growth', 'pro'], true)) {
        $normalized = 'starter';
    }
    $stmt = $pdo->prepare(
        'SELECT plan_code, customer_limit, can_sync, can_export, can_multi_device, can_advanced_reminders
         FROM plan_settings
         WHERE plan_code = :plan_code
         LIMIT 1'
    );
    $stmt->execute([':plan_code' => $normalized]);
    $row = $stmt->fetch();
    if (!$row) {
        return planSettingDefaults($normalized);
    }
    return [
        'plan_code' => $row['plan_code'],
        'customer_limit' => $row['customer_limit'] === null ? null : (int)$row['customer_limit'],
        'can_sync' => (int)$row['can_sync'],
        'can_export' => (int)$row['can_export'],
        'can_multi_device' => (int)$row['can_multi_device'],
        'can_advanced_reminders' => (int)$row['can_advanced_reminders'],
    ];
}

function hasPlanFeature(\PDO $pdo, array $authUser, string $feature): bool
{
    $plan = (string)($authUser['plan_code'] ?? 'starter');
    $settings = planSettings($pdo, $plan);
    return ((int)($settings[$feature] ?? 0)) === 1;
}

function sendWelcomeOnboardingEmail(string $email, string $fullName): void
{
    $from = (string)\App\Config\Env::get('WELCOME_EMAIL_FROM', 'no-reply@ogatailor.app');
    $support = (string)\App\Config\Env::get('SUPPORT_EMAIL', $from);
    $subject = 'Welcome to Oga Tailor';
    $body = "Hi {$fullName},\n\n"
        . "Welcome to Oga Tailor.\n\n"
        . "Here are 3 quick steps to get started:\n"
        . "1) Add your first customer\n"
        . "2) Save the customer's measurements\n"
        . "3) Create orders with due dates and reminders\n\n"
        . "Need help? Reply to {$support}\n\n"
        . "Oga Tailor Team";

    $headers = [
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
        "From: Oga Tailor <{$from}>",
        'X-Mailer: PHP/' . phpversion(),
    ];

    try {
        @mail($email, $subject, $body, implode("\r\n", $headers));
    } catch (\Throwable $e) {
        error_log('welcome_email_failed: ' . $e->getMessage());
    }
}

function enforceRateLimit(string $key, int $maxHits, int $windowSeconds): bool
{
    $rateDir = dirname(__DIR__) . '/storage/logs';
    if (!is_dir($rateDir)) {
        @mkdir($rateDir, 0775, true);
    }
    $file = $rateDir . '/rate-limit.json';
    $now = time();
    $data = [];
    if (is_file($file)) {
        $raw = file_get_contents($file);
        $decoded = $raw ? json_decode($raw, true) : null;
        if (is_array($decoded)) {
            $data = $decoded;
        }
    }

    $entry = $data[$key] ?? ['count' => 0, 'window_start' => $now];
    if (($now - (int)$entry['window_start']) >= $windowSeconds) {
        $entry = ['count' => 0, 'window_start' => $now];
    }
    $entry['count'] = (int)$entry['count'] + 1;
    $data[$key] = $entry;
    file_put_contents($file, json_encode($data, JSON_UNESCAPED_SLASHES));

    return $entry['count'] <= $maxHits;
}

function routeMatches(string $path, string $route): bool
{
    if ($path === $route) {
        return true;
    }

    if (str_ends_with($path, $route)) {
        return true;
    }

    return str_contains($path, $route);
}

if ($method === 'GET' && ($path === '/' || routeMatches($path, '/health'))) {
    Response::json(['status' => 'ok', 'service' => 'oga-tailor-api']);
    return;
}

if ($method === 'GET' && routeMatches($path, '/api/debug/request')) {
    Response::json([
        'path' => $path,
        'request_uri' => $_SERVER['REQUEST_URI'] ?? '',
        'script_name' => $_SERVER['SCRIPT_NAME'] ?? '',
        'php_self' => $_SERVER['PHP_SELF'] ?? '',
    ]);
    return;
}

try {
    $pdo = Connection::make();
} catch (RuntimeException $exception) {
    Response::json(['error' => $exception->getMessage()], 500);
    return;
}

$ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
if (!enforceRateLimit($ip . '|' . $path, 120, 60)) {
    Response::json(['error' => 'Too many requests. Please retry shortly.'], 429);
    return;
}

$isPublicRoute = ($method === 'GET' && ($path === '/' || routeMatches($path, '/health'))) ||
    routeMatches($path, '/api/debug/request') ||
    routeMatches($path, '/api/auth/guest-start') ||
    routeMatches($path, '/api/auth/register') ||
    routeMatches($path, '/api/auth/login') ||
    routeMatches($path, '/api/auth/forgot-password') ||
    routeMatches($path, '/api/auth/reset-password') ||
    ($method === 'POST' && routeMatches($path, '/api/admin/login'));

$isAdminRoute = routeMatches($path, '/api/admin/dashboard') ||
    routeMatches($path, '/api/admin/plans') ||
    routeMatches($path, '/api/admin/logout');

if ($method === 'GET' && routeMatches($path, '/api/reminders/send-digests')) {
    $cronSecret = (string)\App\Config\Env::get('CRON_SECRET', '');
    $provided = $_GET['secret'] ?? $_GET['cron_secret'] ?? '';
    if ($cronSecret === '' || $provided !== $cronSecret) {
        Response::json(['error' => 'Unauthorized'], 401);
        return;
    }
    try {
        $stmt = $pdo->query(
            'SELECT u.id, u.full_name, u.email FROM users u
             WHERE u.email_digest_enabled = 1 AND u.email IS NOT NULL AND u.is_guest = 0'
        );
        $users = $stmt->fetchAll();
        $from = (string)\App\Config\Env::get('WELCOME_EMAIL_FROM', 'no-reply@ogatailor.app');
        $sent = 0;
        foreach ($users as $user) {
            $ordersStmt = $pdo->prepare(
                'SELECT o.title, o.due_date, c.full_name AS customer_name
                 FROM orders o
                 INNER JOIN customers c ON c.id = o.customer_id
                 WHERE o.owner_user_id = :owner_user_id
                   AND o.status NOT IN (\'delivered\', \'cancelled\')
                   AND o.due_date >= CURDATE()
                   AND o.due_date <= DATE_ADD(CURDATE(), INTERVAL 14 DAY)
                 ORDER BY o.due_date ASC
                 LIMIT 20'
            );
            $ordersStmt->execute([':owner_user_id' => $user['id']]);
            $orders = $ordersStmt->fetchAll();
            if (empty($orders)) {
                continue;
            }
            $lines = ["Hi {$user['full_name']},\n\nYour upcoming orders:\n\n"];
            foreach ($orders as $o) {
                $due = date('D, j M Y', strtotime($o['due_date']));
                $lines[] = "- {$o['title']} for {$o['customer_name']} — Due {$due}\n";
            }
            $lines[] = "\n— Oga Tailor";
            $body = implode('', $lines);
            $subject = 'Oga Tailor: Your upcoming orders';
            $headers = [
                'MIME-Version: 1.0',
                'Content-Type: text/plain; charset=UTF-8',
                "From: Oga Tailor <{$from}>",
            ];
            @mail($user['email'], $subject, $body, implode("\r\n", $headers));
            $sent++;
        }
        Response::json(['message' => "Digest sent to {$sent} users", 'sent' => $sent]);
    } catch (\Throwable $e) {
        error_log('send_digests_failed: ' . $e->getMessage());
        Response::json(['error' => $e->getMessage()], 500);
    }
    return;
}

$authUser = null;
$adminUser = null;
if (routeMatches($path, '/api/') && !$isPublicRoute) {
    if ($isAdminRoute) {
        $adminUser = authenticatedAdmin($pdo);
        if (!$adminUser) {
            Response::json(['error' => 'Unauthorized'], 401);
            return;
        }
    } else {
        $authUser = authenticatedUser($pdo);
        if (!$authUser) {
            Response::json(['error' => 'Unauthorized'], 401);
            return;
        }
    }
}

if ($method === 'POST' && routeMatches($path, '/api/auth/guest-start')) {
    $data = requestBody();
    $deviceId = trim((string)($data['device_id'] ?? ''));
    $deviceName = trim((string)($data['device_name'] ?? ''));

    if ($deviceId === '') {
        Response::json(['error' => 'device_id is required'], 422);
        return;
    }

    $lookupStmt = $pdo->prepare(
        'SELECT id FROM users WHERE guest_device_id = :guest_device_id AND is_guest = 1 LIMIT 1'
    );
    $lookupStmt->execute([':guest_device_id' => $deviceId]);
    $existing = $lookupStmt->fetch();

    if ($existing) {
        $token = issueAuthToken($pdo, (string)$existing['id']);
        Response::json([
            'user_id' => $existing['id'],
            'mode' => 'guest',
            'token' => $token,
        ]);
        return;
    }

    $userId = Uuid::v4();
    $displayName = $deviceName !== '' ? sprintf('Guest (%s)', $deviceName) : 'Guest User';
    $createStmt = $pdo->prepare(
        'INSERT INTO users (id, full_name, email, password_hash, is_guest, guest_device_id, plan_code, plan_expires_at, created_at, updated_at)
         VALUES (:id, :full_name, NULL, NULL, 1, :guest_device_id, :plan_code, NULL, NOW(), NOW())'
    );
    $createStmt->execute([
        ':id' => $userId,
        ':full_name' => $displayName,
        ':guest_device_id' => $deviceId,
        ':plan_code' => 'starter',
    ]);

    $token = issueAuthToken($pdo, $userId);
    Response::json([
        'user_id' => $userId,
        'mode' => 'guest',
        'token' => $token,
    ], 201);
    return;
}

function validateCacNumber(string $cac): bool
{
    $cac = strtoupper(trim($cac));
    if (strlen($cac) < 4) {
        return false;
    }
    $prefix = substr($cac, 0, 2);
    $rest = substr($cac, 2);
    return in_array($prefix, ['BN', 'RC'], true) && ctype_digit($rest);
}

/**
 * Validate logo: base64 PNG/JPEG/WEBP, max 500KB decoded, dimensions 64-512px.
 * Returns [valid: bool, error: ?string].
 */
function validateLogo(?string $base64): array
{
    if ($base64 === null || trim($base64) === '') {
        return [true, null];
    }
    $raw = base64_decode(str_replace([' ', "\r", "\n"], '', $base64), true);
    if ($raw === false || strlen($raw) === 0) {
        return [false, 'Logo must be valid base64'];
    }
    if (strlen($raw) > 512 * 1024) {
        return [false, 'Logo must be under 500KB'];
    }
    $finfo = new \finfo(FILEINFO_MIME_TYPE);
    $mime = $finfo->buffer($raw);
    $allowed = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'];
    if (!in_array($mime, $allowed, true)) {
        return [false, 'Logo must be PNG, JPEG or WEBP'];
    }
    $img = @imagecreatefromstring($raw);
    if ($img === false) {
        return [false, 'Logo must be a valid image file'];
    }
    $w = imagesx($img);
    $h = imagesy($img);
    imagedestroy($img);
    if ($w < 64 || $h < 64 || $w > 512 || $h > 512) {
        return [false, 'Logo must be between 64x64 and 512x512 pixels'];
    }
    return [true, null];
}

if ($method === 'POST' && routeMatches($path, '/api/auth/register')) {
    $data = requestBody();
    $fullName = trim((string)($data['full_name'] ?? ''));
    $businessName = trim((string)($data['business_name'] ?? ''));
    $phone = trim((string)($data['phone_number'] ?? ''));
    $email = strtolower(trim((string)($data['email'] ?? '')));
    $password = (string)($data['password'] ?? '');
    $guestUserId = trim((string)($data['guest_user_id'] ?? ''));

    if ($fullName === '' || $phone === '' || $email === '' || $password === '') {
        Response::json(['error' => 'full_name, phone_number, email and password are required'], 422);
        return;
    }

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        Response::json(['error' => 'email is invalid'], 422);
        return;
    }
    if (!ctype_digit($phone) || strlen($phone) !== 11) {
        Response::json(['error' => 'phone_number must be numeric and exactly 11 digits'], 422);
        return;
    }

    if (strlen($password) < 6) {
        Response::json(['error' => 'password must be at least 6 characters'], 422);
        return;
    }

    $emailExistsStmt = $pdo->prepare('SELECT id FROM users WHERE email = :email LIMIT 1');
    $emailExistsStmt->execute([':email' => $email]);
    if ($emailExistsStmt->fetch()) {
        Response::json(['error' => 'email already in use'], 409);
        return;
    }

    $passwordHash = password_hash($password, PASSWORD_DEFAULT);
    if ($guestUserId !== '') {
        $guestStmt = $pdo->prepare('SELECT id FROM users WHERE id = :id AND is_guest = 1 LIMIT 1');
        $guestStmt->execute([':id' => $guestUserId]);
        $guestUser = $guestStmt->fetch();
        if (!$guestUser) {
            Response::json(['error' => 'guest_user_id not found'], 404);
            return;
        }

        $upgradeStmt = $pdo->prepare(
            'UPDATE users
             SET full_name = :full_name,
                 business_name = :business_name,
                 email = :email,
                 phone_number = :phone_number,
                 password_hash = :password_hash,
                 is_guest = 0,
                 guest_device_id = NULL,
                 updated_at = NOW()
             WHERE id = :id'
        );
        $upgradeStmt->execute([
            ':id' => $guestUserId,
            ':full_name' => $fullName,
            ':business_name' => $businessName !== '' ? $businessName : null,
            ':email' => $email,
            ':phone_number' => $phone,
            ':password_hash' => $passwordHash,
        ]);

        $token = issueAuthToken($pdo, $guestUserId);
        sendWelcomeOnboardingEmail($email, $fullName);
        Response::json([
            'user_id' => $guestUserId,
            'mode' => 'registered',
            'token' => $token,
        ]);
        return;
    }

    $userId = Uuid::v4();
    $createUserStmt = $pdo->prepare(
        'INSERT INTO users (id, full_name, business_name, email, phone_number, password_hash, is_guest, guest_device_id, plan_code, plan_expires_at, created_at, updated_at)
         VALUES (:id, :full_name, :business_name, :email, :phone_number, :password_hash, 0, NULL, :plan_code, NULL, NOW(), NOW())'
    );
    $createUserStmt->execute([
        ':id' => $userId,
        ':full_name' => $fullName,
        ':business_name' => $businessName !== '' ? $businessName : null,
        ':email' => $email,
        ':phone_number' => $phone,
        ':password_hash' => $passwordHash,
        ':plan_code' => 'starter',
    ]);

    sendWelcomeOnboardingEmail($email, $fullName);

    $token = issueAuthToken($pdo, $userId);
    Response::json([
        'user_id' => $userId,
        'mode' => 'registered',
        'token' => $token,
    ], 201);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/auth/login')) {
    $data = requestBody();
    $email = strtolower(trim((string)($data['email'] ?? '')));
    $password = (string)($data['password'] ?? '');

    if ($email === '' || $password === '') {
        Response::json(['error' => 'email and password are required'], 422);
        return;
    }

    $stmt = $pdo->prepare(
        'SELECT id, password_hash FROM users WHERE email = :email AND is_guest = 0 LIMIT 1'
    );
    $stmt->execute([':email' => $email]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, (string)$user['password_hash'])) {
        Response::json(['error' => 'invalid credentials'], 401);
        return;
    }

    $token = issueAuthToken($pdo, (string)$user['id']);
    Response::json([
        'user_id' => $user['id'],
        'mode' => 'registered',
        'token' => $token,
    ]);
    return;
}

if ($method === 'GET' && routeMatches($path, '/api/auth/profile')) {
    $userId = (string)($authUser['id'] ?? '');
    $stmt = $pdo->prepare('SELECT id, full_name, business_name, email, phone_number, is_guest, plan_code FROM users WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $userId]);
    $user = $stmt->fetch();
    if (!$user) {
        Response::json(['error' => 'user not found'], 404);
        return;
    }
    $bpStmt = $pdo->prepare('SELECT invoice_setup_completed_at FROM business_profiles WHERE owner_user_id = :owner_user_id LIMIT 1');
    $bpStmt->execute([':owner_user_id' => $userId]);
    $bp = $bpStmt->fetch();
    $user['invoice_setup_completed'] = $bp && $bp['invoice_setup_completed_at'] !== null;
    Response::json(['data' => $user]);
    return;
}

if ($method === 'PATCH' && routeMatches($path, '/api/auth/profile')) {
    $userId = (string)($authUser['id'] ?? '');
    $data = requestBody();
    $fullName = trim((string)($data['full_name'] ?? ''));
    $businessName = trim((string)($data['business_name'] ?? ''));
    $email = strtolower(trim((string)($data['email'] ?? '')));
    $phone = trim((string)($data['phone_number'] ?? ''));
    if ($fullName === '' || $email === '' || $phone === '') {
        Response::json(['error' => 'full_name, email and phone_number are required'], 422);
        return;
    }
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        Response::json(['error' => 'email is invalid'], 422);
        return;
    }
    if (!ctype_digit($phone) || strlen($phone) !== 11) {
        Response::json(['error' => 'phone_number must be numeric and exactly 11 digits'], 422);
        return;
    }

    $stmt = $pdo->prepare(
        'UPDATE users
         SET full_name = :full_name, business_name = :business_name, email = :email, phone_number = :phone_number, updated_at = NOW()
         WHERE id = :id'
    );
    $stmt->execute([
        ':id' => $userId,
        ':full_name' => $fullName,
        ':business_name' => $businessName !== '' ? $businessName : null,
        ':email' => $email,
        ':phone_number' => $phone,
    ]);
    Response::json(['message' => 'Profile updated']);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/auth/logout')) {
    $token = bearerToken();
    if ($token === null || $token === '') {
        Response::json(['error' => 'Unauthorized'], 401);
        return;
    }
    $tokenHash = hash('sha256', $token);
    $stmt = $pdo->prepare('DELETE FROM auth_tokens WHERE token_hash = :token_hash');
    $stmt->execute([':token_hash' => $tokenHash]);
    Response::json(['message' => 'Logged out']);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/auth/logout-all')) {
    $ownerId = (string)($authUser['id'] ?? '');
    if ($ownerId === '') {
        Response::json(['error' => 'Unauthorized'], 401);
        return;
    }
    $stmt = $pdo->prepare('DELETE FROM auth_tokens WHERE user_id = :user_id');
    $stmt->execute([':user_id' => $ownerId]);
    Response::json(['message' => 'Logged out from all devices']);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/auth/change-password')) {
    $userId = (string)($authUser['id'] ?? '');
    $data = requestBody();
    $currentPassword = (string)($data['current_password'] ?? '');
    $newPassword = (string)($data['new_password'] ?? '');

    if ($currentPassword === '' || $newPassword === '') {
        Response::json(['error' => 'current_password and new_password are required'], 422);
        return;
    }
    if (strlen($newPassword) < 6) {
        Response::json(['error' => 'new_password must be at least 6 characters'], 422);
        return;
    }

    $stmt = $pdo->prepare('SELECT password_hash FROM users WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $userId]);
    $row = $stmt->fetch();
    if (!$row || !password_verify($currentPassword, (string)$row['password_hash'])) {
        Response::json(['error' => 'current password is incorrect'], 401);
        return;
    }

    $newHash = password_hash($newPassword, PASSWORD_DEFAULT);
    $updateStmt = $pdo->prepare(
        'UPDATE users SET password_hash = :password_hash, updated_at = NOW() WHERE id = :id'
    );
    $updateStmt->execute([
        ':id' => $userId,
        ':password_hash' => $newHash,
    ]);

    Response::json(['message' => 'Password changed successfully']);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/auth/forgot-password')) {
    $data = requestBody();
    $email = strtolower(trim((string)($data['email'] ?? '')));
    if ($email === '') {
        Response::json(['error' => 'email is required'], 422);
        return;
    }

    $userStmt = $pdo->prepare('SELECT id FROM users WHERE email = :email AND is_guest = 0 LIMIT 1');
    $userStmt->execute([':email' => $email]);
    $user = $userStmt->fetch();
    if (!$user) {
        Response::json(['error' => 'account not found'], 404);
        return;
    }

    $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);
    $resetFile = dirname(__DIR__) . '/storage/logs/password-resets.json';
    $resets = [];
    if (is_file($resetFile)) {
        $raw = file_get_contents($resetFile);
        $decoded = $raw ? json_decode($raw, true) : null;
        if (is_array($decoded)) {
            $resets = $decoded;
        }
    }
    $resets[$email] = [
        'code_hash' => hash('sha256', $code),
        'expires_at' => time() + 900,
    ];
    file_put_contents($resetFile, json_encode($resets, JSON_UNESCAPED_SLASHES));

    Response::json([
        'message' => 'Reset code generated',
        'reset_code' => $code,
        'note' => 'For MVP/testing. Replace with email delivery provider in production.',
    ]);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/auth/reset-password')) {
    $data = requestBody();
    $email = strtolower(trim((string)($data['email'] ?? '')));
    $code = trim((string)($data['reset_code'] ?? ''));
    $newPassword = (string)($data['new_password'] ?? '');

    if ($email === '' || $code === '' || $newPassword === '') {
        Response::json(['error' => 'email, reset_code and new_password are required'], 422);
        return;
    }
    if (strlen($newPassword) < 6) {
        Response::json(['error' => 'new_password must be at least 6 characters'], 422);
        return;
    }

    $resetFile = dirname(__DIR__) . '/storage/logs/password-resets.json';
    $resets = [];
    if (is_file($resetFile)) {
        $raw = file_get_contents($resetFile);
        $decoded = $raw ? json_decode($raw, true) : null;
        if (is_array($decoded)) {
            $resets = $decoded;
        }
    }

    $entry = $resets[$email] ?? null;
    if (!$entry || (int)($entry['expires_at'] ?? 0) < time()) {
        Response::json(['error' => 'reset code is invalid or expired'], 422);
        return;
    }
    if ((string)($entry['code_hash'] ?? '') !== hash('sha256', $code)) {
        Response::json(['error' => 'reset code is invalid'], 422);
        return;
    }

    $newHash = password_hash($newPassword, PASSWORD_DEFAULT);
    $updateStmt = $pdo->prepare(
        'UPDATE users SET password_hash = :password_hash, updated_at = NOW() WHERE email = :email'
    );
    $updateStmt->execute([
        ':email' => $email,
        ':password_hash' => $newHash,
    ]);

    unset($resets[$email]);
    file_put_contents($resetFile, json_encode($resets, JSON_UNESCAPED_SLASHES));

    Response::json(['message' => 'Password reset successful']);
    return;
}

if ($method === 'GET' && routeMatches($path, '/api/plan/summary')) {
    $ownerId = (string)($authUser['id'] ?? '');

    $planStmt = $pdo->prepare('SELECT plan_code, plan_expires_at FROM users WHERE id = :id LIMIT 1');
    $planStmt->execute([':id' => $ownerId]);
    $user = $planStmt->fetch();
    if (!$user) {
        Response::json(['error' => 'owner user not found'], 404);
        return;
    }

    $countStmt = $pdo->prepare('SELECT COUNT(*) FROM customers WHERE owner_user_id = :owner_user_id');
    $countStmt->execute([':owner_user_id' => $ownerId]);
    $customerCount = (int)$countStmt->fetchColumn();
    $settings = planSettings($pdo, (string)($user['plan_code'] ?? 'starter'));

    Response::json([
        'plan_code' => $user['plan_code'],
        'plan_expires_at' => $user['plan_expires_at'],
        'customer_count' => $customerCount,
        'customer_limit' => $settings['customer_limit'],
        'features' => [
            'can_sync' => ((int)$settings['can_sync']) === 1,
            'can_export' => ((int)$settings['can_export']) === 1,
            'can_multi_device' => ((int)$settings['can_multi_device']) === 1,
            'can_advanced_reminders' => ((int)$settings['can_advanced_reminders']) === 1,
        ],
    ]);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/customers')) {
    $data = requestBody();
    $customerId = Uuid::v4();
    $ownerId = (string)($authUser['id'] ?? '');
    $fullName = normalizeCustomerName(trim((string)($data['full_name'] ?? '')));
    $gender = strtolower(trim((string)($data['gender'] ?? '')));
    $phone = trim((string)($data['phone_number'] ?? ''));
    $notes = trim((string)($data['notes'] ?? ''));

    if ($fullName === '' || $gender === '') {
        Response::json(['error' => 'full_name and gender are required'], 422);
        return;
    }
    if (!in_array($gender, ['male', 'female', 'other'], true)) {
        Response::json(['error' => 'gender must be male, female or other'], 422);
        return;
    }
    if ($phone !== '' && (!ctype_digit($phone) || strlen($phone) > 11)) {
        Response::json(['error' => 'phone_number must be numeric and max 11 digits'], 422);
        return;
    }

    $checkStmt = $pdo->prepare(
        'SELECT id FROM customers
         WHERE owner_user_id = :owner_user_id
         AND LOWER(TRIM(full_name)) = LOWER(TRIM(:full_name))
         AND (notes IS NULL OR notes NOT LIKE \'[ARCHIVED]%\')
         LIMIT 1'
    );
    $checkStmt->execute([':owner_user_id' => $ownerId, ':full_name' => $fullName]);
    $existing = $checkStmt->fetch(\PDO::FETCH_ASSOC);
    if ($existing) {
        Response::json([
            'error' => 'duplicate_name',
            'message' => 'A customer with this name already exists.',
            'existing_customer_id' => $existing['id'],
        ], 409);
        return;
    }

    $settings = planSettings($pdo, (string)($authUser['plan_code'] ?? 'starter'));
    $customerLimit = $settings['customer_limit'];
    if ($customerLimit !== null) {
        $countStmt = $pdo->prepare('SELECT COUNT(*) FROM customers WHERE owner_user_id = :owner_user_id');
        $countStmt->execute([':owner_user_id' => $ownerId]);
        $customerCount = (int)$countStmt->fetchColumn();
        if ($customerCount >= (int)$customerLimit) {
            Response::json([
                'error' => ucfirst((string)($authUser['plan_code'] ?? 'starter')) . ' plan limit reached (' . $customerLimit . ' customers). Upgrade to continue.',
            ], 403);
            return;
        }
    }

    $stmt = $pdo->prepare(
        'INSERT INTO customers (id, owner_user_id, full_name, phone_number, gender, notes, created_at, updated_at, last_modified_at)
         VALUES (:id, :owner_user_id, :full_name, :phone_number, :gender, :notes, NOW(), NOW(), NOW())'
    );
    $stmt->execute([
        ':id' => $customerId,
        ':owner_user_id' => $ownerId,
        ':full_name' => $fullName,
        ':phone_number' => $phone !== '' ? $phone : null,
        ':gender' => $gender,
        ':notes' => $notes !== '' ? $notes : null,
    ]);

    Response::json(['id' => $customerId], 201);
    return;
}

if ($method === 'GET' && routeMatches($path, '/api/customers')) {
    $ownerId = (string)($authUser['id'] ?? '');
    $limit = max(1, min(200, (int)($_GET['limit'] ?? 50)));
    $offset = max(0, (int)($_GET['offset'] ?? 0));
    $query = trim((string)($_GET['q'] ?? ''));
    $startsWith = strtolower(trim((string)($_GET['starts_with'] ?? '')));
    $archivedMode = strtolower(trim((string)($_GET['archived'] ?? 'exclude')));
    if ($startsWith !== '' && !preg_match('/^[a-z]$/', $startsWith)) {
        Response::json(['error' => 'starts_with must be one letter a-z'], 422);
        return;
    }
    if (!in_array($archivedMode, ['exclude', 'only', 'all'], true)) {
        Response::json(['error' => 'archived must be one of: exclude, only, all'], 422);
        return;
    }

    $countSql = 'SELECT COUNT(*)
                 FROM customers
                 WHERE owner_user_id = :owner_user_id';
    $rowsSql = 'SELECT id, owner_user_id, full_name, phone_number, notes, created_at, updated_at, last_modified_at
                , gender
                FROM customers
                WHERE owner_user_id = :owner_user_id';
    $params = [':owner_user_id' => $ownerId];
    if ($archivedMode === 'exclude') {
        $countSql .= ' AND (notes IS NULL OR notes NOT LIKE \'[ARCHIVED]%\')';
        $rowsSql .= ' AND (notes IS NULL OR notes NOT LIKE \'[ARCHIVED]%\')';
    } elseif ($archivedMode === 'only') {
        $countSql .= ' AND notes LIKE \'[ARCHIVED]%\'';
        $rowsSql .= ' AND notes LIKE \'[ARCHIVED]%\'';
    }
    if ($query !== '') {
        $qVal = '%' . strtolower($query) . '%';
        $countSql .= ' AND (LOWER(full_name) LIKE :q1 OR phone_number LIKE :q2)';
        $rowsSql .= ' AND (LOWER(full_name) LIKE :q1 OR phone_number LIKE :q2)';
        $params[':q1'] = $qVal;
        $params[':q2'] = $qVal;
    }
    if ($startsWith !== '') {
        $countSql .= ' AND LOWER(full_name) LIKE :starts_with';
        $rowsSql .= ' AND LOWER(full_name) LIKE :starts_with';
        $params[':starts_with'] = $startsWith . '%';
    }
    $rowsSql .= ' ORDER BY full_name ASC LIMIT :limit_rows OFFSET :offset_rows';

    $countStmt = $pdo->prepare($countSql);
    $countStmt->execute($params);
    $total = (int)$countStmt->fetchColumn();

    $stmt = $pdo->prepare($rowsSql);
    foreach ($params as $k => $v) {
        $stmt->bindValue($k, $v);
    }
    $stmt->bindValue(':limit_rows', $limit, \PDO::PARAM_INT);
    $stmt->bindValue(':offset_rows', $offset, \PDO::PARAM_INT);
    $stmt->execute();
    $rows = $stmt->fetchAll();
    Response::json([
        'data' => $rows,
        'meta' => [
            'total' => $total,
            'limit' => $limit,
            'offset' => $offset,
            'has_more' => ($offset + count($rows)) < $total,
        ],
    ]);
    return;
}

if ($method === 'PATCH' && routeMatches($path, '/api/customers')) {
    $data = requestBody();
    $customerId = trim((string)($data['customer_id'] ?? ''));
    $ownerId = (string)($authUser['id'] ?? '');
    $fullName = normalizeCustomerName(trim((string)($data['full_name'] ?? '')));
    $gender = strtolower(trim((string)($data['gender'] ?? '')));
    $phone = trim((string)($data['phone_number'] ?? ''));
    $notes = trim((string)($data['notes'] ?? ''));
    $clientLastModifiedAt = trim((string)($data['client_last_modified_at'] ?? ''));

    if ($customerId === '' || $fullName === '' || $gender === '') {
        Response::json(['error' => 'customer_id, full_name and gender are required'], 422);
        return;
    }
    if (!in_array($gender, ['male', 'female', 'other'], true)) {
        Response::json(['error' => 'gender must be male, female or other'], 422);
        return;
    }
    if ($phone !== '' && (!ctype_digit($phone) || strlen($phone) > 11)) {
        Response::json(['error' => 'phone_number must be numeric and max 11 digits'], 422);
        return;
    }

    $checkStmt = $pdo->prepare(
        'SELECT id FROM customers
         WHERE owner_user_id = :owner_user_id
         AND id != :customer_id
         AND LOWER(TRIM(full_name)) = LOWER(TRIM(:full_name))
         AND (notes IS NULL OR notes NOT LIKE \'[ARCHIVED]%\')
         LIMIT 1'
    );
    $checkStmt->execute([
        ':owner_user_id' => $ownerId,
        ':customer_id' => $customerId,
        ':full_name' => $fullName,
    ]);
    $existing = $checkStmt->fetch(\PDO::FETCH_ASSOC);
    if ($existing) {
        Response::json([
            'error' => 'duplicate_name',
            'message' => 'Another customer with this name already exists.',
            'existing_customer_id' => $existing['id'],
        ], 409);
        return;
    }

    $existingStmt = $pdo->prepare(
        'SELECT id, last_modified_at
         FROM customers
         WHERE id = :id AND owner_user_id = :owner_user_id
         LIMIT 1'
    );
    $existingStmt->execute([
        ':id' => $customerId,
        ':owner_user_id' => $ownerId,
    ]);
    $existingCustomer = $existingStmt->fetch();
    if (!$existingCustomer) {
        Response::json(['error' => 'customer not found'], 404);
        return;
    }
    if ($clientLastModifiedAt !== '') {
        $serverTs = strtotime((string)$existingCustomer['last_modified_at']);
        $clientTs = strtotime($clientLastModifiedAt);
        if ($serverTs !== false && $clientTs !== false && $serverTs > $clientTs) {
            Response::json([
                'error' => 'conflict',
                'message' => 'Customer has changed on another device.',
                'server_last_modified_at' => $existingCustomer['last_modified_at'],
            ], 409);
            return;
        }
    }

    $stmt = $pdo->prepare(
        'UPDATE customers
         SET full_name = :full_name,
             phone_number = :phone_number,
             gender = :gender,
             notes = :notes,
             updated_at = NOW(),
             last_modified_at = NOW()
         WHERE id = :id AND owner_user_id = :owner_user_id'
    );
    $stmt->execute([
        ':id' => $customerId,
        ':owner_user_id' => $ownerId,
        ':full_name' => $fullName,
        ':phone_number' => $phone !== '' ? $phone : null,
        ':gender' => $gender,
        ':notes' => $notes !== '' ? $notes : null,
    ]);

    if ($stmt->rowCount() < 1) {
        Response::json(['error' => 'customer not found'], 404);
        return;
    }

    Response::json(['message' => 'Customer updated']);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/customers/archive')) {
    $data = requestBody();
    $customerId = trim((string)($data['customer_id'] ?? ''));
    $ownerId = (string)($authUser['id'] ?? '');
    $archived = (bool)($data['archived'] ?? true);

    if ($customerId === '') {
        Response::json(['error' => 'customer_id is required'], 422);
        return;
    }

    if ($archived) {
        $stmt = $pdo->prepare(
            'UPDATE customers
             SET notes = CASE
                    WHEN notes IS NULL OR notes = \'\' THEN \'[ARCHIVED]\'
                    WHEN notes LIKE \'[ARCHIVED]%\' THEN notes
                    ELSE CONCAT(\'[ARCHIVED] \', notes)
                 END,
                 updated_at = NOW(),
                 last_modified_at = NOW()
             WHERE id = :id AND owner_user_id = :owner_user_id'
        );
    } else {
        $stmt = $pdo->prepare(
            'UPDATE customers
             SET notes = TRIM(REPLACE(COALESCE(notes, \'\'), \'[ARCHIVED]\', \'\')),
                 updated_at = NOW(),
                 last_modified_at = NOW()
             WHERE id = :id AND owner_user_id = :owner_user_id'
        );
    }

    $stmt->execute([
        ':id' => $customerId,
        ':owner_user_id' => $ownerId,
    ]);

    if ($stmt->rowCount() < 1) {
        Response::json(['error' => 'customer not found'], 404);
        return;
    }

    Response::json(['message' => $archived ? 'Customer archived' : 'Customer unarchived']);
    return;
}

if ($method === 'DELETE' && routeMatches($path, '/api/customers')) {
    $data = requestBody();
    $customerId = trim((string)($data['customer_id'] ?? ''));
    $ownerId = (string)($authUser['id'] ?? '');

    if ($customerId === '') {
        Response::json(['error' => 'customer_id is required'], 422);
        return;
    }

    try {
        $pdo->beginTransaction();

        $deleteMeasurementsStmt = $pdo->prepare('DELETE FROM measurements WHERE customer_id = :customer_id');
        $deleteMeasurementsStmt->execute([':customer_id' => $customerId]);

        $deleteCustomerStmt = $pdo->prepare(
            'DELETE FROM customers WHERE id = :id AND owner_user_id = :owner_user_id'
        );
        $deleteCustomerStmt->execute([
            ':id' => $customerId,
            ':owner_user_id' => $ownerId,
        ]);

        if ($deleteCustomerStmt->rowCount() < 1) {
            $pdo->rollBack();
            Response::json(['error' => 'customer not found'], 404);
            return;
        }

        $pdo->commit();
        Response::json(['message' => 'Customer deleted']);
        return;
    } catch (\Throwable $exception) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        Response::json(['error' => 'Delete failed: ' . $exception->getMessage()], 500);
        return;
    }
}

if ($method === 'POST' && routeMatches($path, '/api/measurements')) {
    $data = requestBody();
    $measurementId = Uuid::v4();
    $ownerId = (string)($authUser['id'] ?? '');
    $customerId = $data['customer_id'] ?? null;
    $takenAt = $data['taken_at'] ?? null;
    $payload = $data['payload'] ?? null;

    if (!$customerId || !$takenAt || !is_array($payload)) {
        Response::json(['error' => 'customer_id, taken_at and payload are required'], 422);
        return;
    }

    $ownerCheck = $pdo->prepare(
        'SELECT id FROM customers WHERE id = :customer_id AND owner_user_id = :owner_user_id LIMIT 1'
    );
    $ownerCheck->execute([
        ':customer_id' => $customerId,
        ':owner_user_id' => $ownerId,
    ]);
    if (!$ownerCheck->fetch()) {
        Response::json(['error' => 'customer not found for current user'], 404);
        return;
    }

    $stmt = $pdo->prepare(
        'INSERT INTO measurements (id, customer_id, taken_at, payload_json, created_at, updated_at, last_modified_at)
         VALUES (:id, :customer_id, :taken_at, :payload_json, NOW(), NOW(), NOW())'
    );
    $stmt->execute([
        ':id' => $measurementId,
        ':customer_id' => $customerId,
        ':taken_at' => $takenAt,
        ':payload_json' => json_encode($payload, JSON_UNESCAPED_SLASHES),
    ]);

    Response::json(['id' => $measurementId], 201);
    return;
}

if ($method === 'GET' && routeMatches($path, '/api/measurements')) {
    $ownerId = (string)($authUser['id'] ?? '');
    $customerId = $_GET['customer_id'] ?? null;
    if (!$customerId) {
        Response::json(['error' => 'customer_id is required'], 422);
        return;
    }

    $ownerCheck = $pdo->prepare(
        'SELECT id FROM customers WHERE id = :customer_id AND owner_user_id = :owner_user_id LIMIT 1'
    );
    $ownerCheck->execute([
        ':customer_id' => $customerId,
        ':owner_user_id' => $ownerId,
    ]);
    if (!$ownerCheck->fetch()) {
        Response::json(['error' => 'customer not found for current user'], 404);
        return;
    }

    $stmt = $pdo->prepare(
        'SELECT id, customer_id, taken_at, payload_json, created_at, updated_at, last_modified_at
         FROM measurements
         WHERE customer_id = :customer_id
         ORDER BY taken_at DESC'
    );
    $stmt->execute([':customer_id' => $customerId]);
    $rows = $stmt->fetchAll();

    $data = array_map(static function (array $row): array {
        $row['payload'] = json_decode((string)$row['payload_json'], true);
        unset($row['payload_json']);
        return $row;
    }, $rows);

    Response::json(['data' => $data]);
    return;
}

if ($method === 'PATCH' && routeMatches($path, '/api/measurements')) {
    $data = requestBody();
    $ownerId = (string)($authUser['id'] ?? '');
    $measurementId = trim((string)($data['measurement_id'] ?? ''));
    $takenAt = trim((string)($data['taken_at'] ?? ''));
    $clientLastModifiedAt = trim((string)($data['client_last_modified_at'] ?? ''));
    $payload = $data['payload'] ?? null;

    if ($measurementId === '' || $takenAt === '' || !is_array($payload)) {
        Response::json(['error' => 'measurement_id, taken_at and payload are required'], 422);
        return;
    }

    $existingStmt = $pdo->prepare(
        'SELECT m.id, m.last_modified_at
         FROM measurements m
         INNER JOIN customers c ON c.id = m.customer_id
         WHERE m.id = :id AND c.owner_user_id = :owner_user_id
         LIMIT 1'
    );
    $existingStmt->execute([
        ':id' => $measurementId,
        ':owner_user_id' => $ownerId,
    ]);
    $existing = $existingStmt->fetch();
    if (!$existing) {
        Response::json(['error' => 'measurement not found'], 404);
        return;
    }

    if ($clientLastModifiedAt !== '') {
        $serverTs = strtotime((string)$existing['last_modified_at']);
        $clientTs = strtotime($clientLastModifiedAt);
        if ($serverTs !== false && $clientTs !== false && $serverTs > $clientTs) {
            Response::json([
                'error' => 'conflict',
                'message' => 'Measurement has changed on another device.',
                'server_last_modified_at' => $existing['last_modified_at'],
            ], 409);
            return;
        }
    }

    $stmt = $pdo->prepare(
        'UPDATE measurements
         SET taken_at = :taken_at,
             payload_json = :payload_json,
             updated_at = NOW(),
             last_modified_at = NOW()
         WHERE id = :id'
    );
    $stmt->execute([
        ':id' => $measurementId,
        ':taken_at' => $takenAt,
        ':payload_json' => json_encode($payload, JSON_UNESCAPED_SLASHES),
    ]);

    if ($stmt->rowCount() < 1) {
        Response::json(['error' => 'measurement not found'], 404);
        return;
    }

    Response::json(['message' => 'Measurement updated']);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/orders')) {
    $data = requestBody();
    $orderId = Uuid::v4();
    $ownerId = (string)($authUser['id'] ?? '');
    $customerId = trim((string)($data['customer_id'] ?? ''));
    $title = trim((string)($data['title'] ?? ''));
    $status = trim((string)($data['status'] ?? 'pending'));
    $dueDate = trim((string)($data['due_date'] ?? ''));
    $allowPastDueDate = filter_var(($data['allow_past_due_date'] ?? false), FILTER_VALIDATE_BOOLEAN);
    $amountTotal = (float)($data['amount_total'] ?? 0);
    $notes = trim((string)($data['notes'] ?? ''));

    if ($customerId === '' || $title === '') {
        Response::json(['error' => 'customer_id and title are required'], 422);
        return;
    }
    if ($amountTotal < 0) {
        Response::json(['error' => 'amount_total cannot be negative'], 422);
        return;
    }

    $ownerCheck = $pdo->prepare(
        'SELECT id FROM customers WHERE id = :customer_id AND owner_user_id = :owner_user_id LIMIT 1'
    );
    $ownerCheck->execute([
        ':customer_id' => $customerId,
        ':owner_user_id' => $ownerId,
    ]);
    if (!$ownerCheck->fetch()) {
        Response::json(['error' => 'customer not found for current user'], 404);
        return;
    }

    $allowedStatuses = ['pending', 'in_progress', 'ready', 'delivered', 'cancelled'];
    if (!in_array($status, $allowedStatuses, true)) {
        Response::json(['error' => 'invalid order status'], 422);
        return;
    }
    if ($dueDate !== '') {
        $dueTs = strtotime($dueDate);
        if ($dueTs === false) {
            Response::json(['error' => 'due_date is invalid'], 422);
            return;
        }
        $todayStart = strtotime(date('Y-m-d 00:00:00'));
        if (!$allowPastDueDate && $todayStart !== false && $dueTs < $todayStart) {
            Response::json(['error' => 'due_date cannot be in the past'], 422);
            return;
        }
    }

    $stmt = $pdo->prepare(
        'INSERT INTO orders (id, owner_user_id, customer_id, title, status, due_date, amount_total, notes, created_at, updated_at, last_modified_at)
         VALUES (:id, :owner_user_id, :customer_id, :title, :status, :due_date, :amount_total, :notes, NOW(), NOW(), NOW())'
    );
    $stmt->execute([
        ':id' => $orderId,
        ':owner_user_id' => $ownerId,
        ':customer_id' => $customerId,
        ':title' => $title,
        ':status' => $status,
        ':due_date' => $dueDate !== '' ? $dueDate : null,
        ':amount_total' => $amountTotal,
        ':notes' => $notes !== '' ? $notes : null,
    ]);

    Response::json(['id' => $orderId], 201);
    return;
}

if ($method === 'GET' && routeMatches($path, '/api/orders')) {
    $ownerId = (string)($authUser['id'] ?? '');

    $stmt = $pdo->prepare(
        'SELECT o.id, o.owner_user_id, o.customer_id, c.full_name AS customer_name, o.title, o.status, o.due_date, o.amount_total, o.notes, o.created_at, o.updated_at, o.last_modified_at
         FROM orders o
         INNER JOIN customers c ON c.id = o.customer_id
         WHERE o.owner_user_id = :owner_user_id
         ORDER BY o.created_at DESC'
    );
    $stmt->execute([':owner_user_id' => $ownerId]);
    Response::json(['data' => $stmt->fetchAll()]);
    return;
}

if ($method === 'PATCH' && routeMatches($path, '/api/orders/status')) {
    $data = requestBody();
    $orderId = trim((string)($data['order_id'] ?? ''));
    $ownerId = (string)($authUser['id'] ?? '');
    $status = trim((string)($data['status'] ?? ''));
    $clientLastModifiedAt = trim((string)($data['client_last_modified_at'] ?? ''));

    if ($orderId === '' || $status === '') {
        Response::json(['error' => 'order_id and status are required'], 422);
        return;
    }

    $allowedStatuses = ['pending', 'in_progress', 'ready', 'delivered', 'cancelled'];
    if (!in_array($status, $allowedStatuses, true)) {
        Response::json(['error' => 'invalid order status'], 422);
        return;
    }

    $existingStmt = $pdo->prepare('SELECT id, last_modified_at FROM orders WHERE id = :id AND owner_user_id = :owner_user_id LIMIT 1');
    $existingStmt->execute([
        ':id' => $orderId,
        ':owner_user_id' => $ownerId,
    ]);
    $existing = $existingStmt->fetch();
    if (!$existing) {
        Response::json(['error' => 'order not found'], 404);
        return;
    }
    if ($clientLastModifiedAt !== '') {
        $serverTs = strtotime((string)$existing['last_modified_at']);
        $clientTs = strtotime($clientLastModifiedAt);
        if ($serverTs !== false && $clientTs !== false && $serverTs > $clientTs) {
            Response::json([
                'error' => 'conflict',
                'message' => 'Order has changed on another device.',
                'server_last_modified_at' => $existing['last_modified_at'],
            ], 409);
            return;
        }
    }

    $stmt = $pdo->prepare(
        'UPDATE orders
         SET status = :status, updated_at = NOW(), last_modified_at = NOW()
         WHERE id = :id AND owner_user_id = :owner_user_id'
    );
    $stmt->execute([
        ':id' => $orderId,
        ':owner_user_id' => $ownerId,
        ':status' => $status,
    ]);

    if ($stmt->rowCount() < 1) {
        Response::json(['error' => 'order not found'], 404);
        return;
    }

    Response::json(['message' => 'Order status updated']);
    return;
}

if ($method === 'PATCH' && routeMatches($path, '/api/orders/due-date')) {
    $data = requestBody();
    $orderId = trim((string)($data['order_id'] ?? ''));
    $ownerId = (string)($authUser['id'] ?? '');
    $dueDate = trim((string)($data['due_date'] ?? ''));
    $allowPastDueDate = filter_var(($data['allow_past_due_date'] ?? false), FILTER_VALIDATE_BOOLEAN);
    $clientLastModifiedAt = trim((string)($data['client_last_modified_at'] ?? ''));

    if ($orderId === '') {
        Response::json(['error' => 'order_id is required'], 422);
        return;
    }
    if ($dueDate !== '') {
        $dueTs = strtotime($dueDate);
        if ($dueTs === false) {
            Response::json(['error' => 'due_date is invalid'], 422);
            return;
        }
        $todayStart = strtotime(date('Y-m-d 00:00:00'));
        if (!$allowPastDueDate && $todayStart !== false && $dueTs < $todayStart) {
            Response::json(['error' => 'due_date cannot be in the past'], 422);
            return;
        }
    }

    $existingStmt = $pdo->prepare('SELECT id, last_modified_at FROM orders WHERE id = :id AND owner_user_id = :owner_user_id LIMIT 1');
    $existingStmt->execute([
        ':id' => $orderId,
        ':owner_user_id' => $ownerId,
    ]);
    $existing = $existingStmt->fetch();
    if (!$existing) {
        Response::json(['error' => 'order not found'], 404);
        return;
    }
    if ($clientLastModifiedAt !== '') {
        $serverTs = strtotime((string)$existing['last_modified_at']);
        $clientTs = strtotime($clientLastModifiedAt);
        if ($serverTs !== false && $clientTs !== false && $serverTs > $clientTs) {
            Response::json([
                'error' => 'conflict',
                'message' => 'Order has changed on another device.',
                'server_last_modified_at' => $existing['last_modified_at'],
            ], 409);
            return;
        }
    }

    $stmt = $pdo->prepare(
        'UPDATE orders
         SET due_date = :due_date, updated_at = NOW(), last_modified_at = NOW()
         WHERE id = :id AND owner_user_id = :owner_user_id'
    );
    $stmt->execute([
        ':id' => $orderId,
        ':owner_user_id' => $ownerId,
        ':due_date' => $dueDate !== '' ? $dueDate : null,
    ]);

    if ($stmt->rowCount() < 1) {
        Response::json(['error' => 'order not found'], 404);
        return;
    }

    Response::json(['message' => 'Order due date updated']);
    return;
}

if ($method === 'GET' && routeMatches($path, '/api/business-profile')) {
    $ownerId = (string)($authUser['id'] ?? '');
    $stmt = $pdo->prepare(
        'SELECT id, owner_user_id, business_name, business_phone, business_email, business_address,
                cac_registered, cac_registration_type, cac_number, vat_enabled, default_vat_rate,
                currency, payment_terms, logo_data, invoice_setup_completed_at, created_at, updated_at
         FROM business_profiles
         WHERE owner_user_id = :owner_user_id
         LIMIT 1'
    );
    $stmt->execute([':owner_user_id' => $ownerId]);
    $row = $stmt->fetch();
    if (!$row) {
        Response::json(['error' => 'Business profile not found. Complete invoice setup first.'], 404);
        return;
    }
    $row['invoice_setup_completed'] = $row['invoice_setup_completed_at'] !== null;
    Response::json(['data' => $row]);
    return;
}

if ($method === 'PATCH' && routeMatches($path, '/api/business-profile')) {
    $ownerId = (string)($authUser['id'] ?? '');
    $data = requestBody();
    $businessName = trim((string)($data['business_name'] ?? ''));
    $businessPhone = trim((string)($data['business_phone'] ?? ''));
    $businessEmail = strtolower(trim((string)($data['business_email'] ?? '')));
    $businessAddress = trim((string)($data['business_address'] ?? ''));
    $cacRegistered = filter_var($data['cac_registered'] ?? false, FILTER_VALIDATE_BOOLEAN);
    $cacRegistrationType = strtolower(trim((string)($data['cac_registration_type'] ?? '')));
    $cacNumber = trim((string)($data['cac_number'] ?? ''));
    $vatEnabled = filter_var($data['vat_enabled'] ?? false, FILTER_VALIDATE_BOOLEAN);
    $defaultVatRate = (float)($data['default_vat_rate'] ?? 0);
    $currency = strtoupper(trim((string)($data['currency'] ?? 'NGN')));
    $paymentTerms = trim((string)($data['payment_terms'] ?? ''));
    $logoData = null;
    $updateLogo = false;
    if (array_key_exists('logo_data', $data)) {
        $logoData = trim((string)($data['logo_data'] ?? ''));
        if ($logoData === '') {
            $logoData = null;
        }
        $updateLogo = true;
        if ($logoData !== null) {
            [$logoValid, $logoError] = validateLogo($logoData);
            if (!$logoValid) {
                Response::json(['error' => $logoError], 422);
                return;
            }
        }
    }

    if ($businessName === '') {
        Response::json(['error' => 'business_name is required'], 422);
        return;
    }
    if ($businessPhone !== '' && (!ctype_digit($businessPhone) || strlen($businessPhone) > 15)) {
        Response::json(['error' => 'business_phone must be numeric and max 15 digits'], 422);
        return;
    }
    if ($businessEmail !== '' && !filter_var($businessEmail, FILTER_VALIDATE_EMAIL)) {
        Response::json(['error' => 'business_email is invalid'], 422);
        return;
    }
    if ($cacRegistered) {
        if (!in_array($cacRegistrationType, ['company', 'business'], true)) {
            Response::json(['error' => 'cac_registration_type must be company or business when CAC registered'], 422);
            return;
        }
        if ($cacNumber === '' || !validateCacNumber($cacNumber)) {
            Response::json(['error' => 'cac_number is required and must start with BN or RC followed by digits'], 422);
            return;
        }
    } else {
        $cacRegistrationType = null;
        $cacNumber = null;
    }
    if ($vatEnabled && ($defaultVatRate < 0 || $defaultVatRate > 100)) {
        Response::json(['error' => 'default_vat_rate must be between 0 and 100 when VAT is enabled'], 422);
        return;
    }

    $existingStmt = $pdo->prepare('SELECT id FROM business_profiles WHERE owner_user_id = :owner_user_id LIMIT 1');
    $existingStmt->execute([':owner_user_id' => $ownerId]);
    $existing = $existingStmt->fetch();

    $now = date('Y-m-d H:i:s');
    if ($existing) {
        $logoClause = $updateLogo ? ', logo_data = :logo_data' : '';
        $stmt = $pdo->prepare(
            'UPDATE business_profiles
             SET business_name = :business_name, business_phone = :business_phone, business_email = :business_email,
                 business_address = :business_address, cac_registered = :cac_registered,
                 cac_registration_type = :cac_registration_type, cac_number = :cac_number,
                 vat_enabled = :vat_enabled, default_vat_rate = :default_vat_rate,
                 currency = :currency, payment_terms = :payment_terms'
            . $logoClause . ',
                 invoice_setup_completed_at = :invoice_setup_completed_at, updated_at = :updated_at
             WHERE owner_user_id = :owner_user_id'
        );
        $params = [
            ':owner_user_id' => $ownerId,
            ':business_name' => $businessName,
            ':business_phone' => $businessPhone !== '' ? $businessPhone : null,
            ':business_email' => $businessEmail !== '' ? $businessEmail : null,
            ':business_address' => $businessAddress !== '' ? $businessAddress : null,
            ':cac_registered' => $cacRegistered ? 1 : 0,
            ':cac_registration_type' => $cacRegistrationType,
            ':cac_number' => $cacNumber !== '' ? $cacNumber : null,
            ':vat_enabled' => $vatEnabled ? 1 : 0,
            ':default_vat_rate' => $defaultVatRate,
            ':currency' => $currency !== '' ? $currency : 'NGN',
            ':payment_terms' => $paymentTerms !== '' ? $paymentTerms : null,
            ':invoice_setup_completed_at' => $now,
            ':updated_at' => $now,
        ];
        if ($updateLogo) {
            $params[':logo_data'] = $logoData;
        }
        $stmt->execute($params);
    } else {
        $profileId = Uuid::v4();
        $stmt = $pdo->prepare(
            'INSERT INTO business_profiles (id, owner_user_id, business_name, business_phone, business_email, business_address,
                    cac_registered, cac_registration_type, cac_number, vat_enabled, default_vat_rate,
                    currency, payment_terms, logo_data, invoice_setup_completed_at, created_at, updated_at)
             VALUES (:id, :owner_user_id, :business_name, :business_phone, :business_email, :business_address,
                    :cac_registered, :cac_registration_type, :cac_number, :vat_enabled, :default_vat_rate,
                    :currency, :payment_terms, :logo_data, :invoice_setup_completed_at, :created_at, :updated_at)'
        );
        $stmt->execute([
            ':id' => $profileId,
            ':owner_user_id' => $ownerId,
            ':business_name' => $businessName,
            ':business_phone' => $businessPhone !== '' ? $businessPhone : null,
            ':business_email' => $businessEmail !== '' ? $businessEmail : null,
            ':business_address' => $businessAddress !== '' ? $businessAddress : null,
            ':cac_registered' => $cacRegistered ? 1 : 0,
            ':cac_registration_type' => $cacRegistrationType,
            ':cac_number' => $cacNumber !== '' ? $cacNumber : null,
            ':vat_enabled' => $vatEnabled ? 1 : 0,
            ':default_vat_rate' => $defaultVatRate,
            ':currency' => $currency !== '' ? $currency : 'NGN',
            ':payment_terms' => $paymentTerms !== '' ? $paymentTerms : null,
            ':logo_data' => $logoData,
            ':invoice_setup_completed_at' => $now,
            ':created_at' => $now,
            ':updated_at' => $now,
        ]);
    }
    Response::json(['message' => 'Invoice setup completed']);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/invoices/generate')) {
    $ownerId = (string)($authUser['id'] ?? '');
    $data = requestBody();
    $orderId = trim((string)($data['order_id'] ?? ''));

    if ($orderId === '') {
        Response::json(['error' => 'order_id is required'], 422);
        return;
    }

    $bpStmt = $pdo->prepare(
        'SELECT business_name, business_phone, business_email, business_address, vat_enabled, default_vat_rate, currency, payment_terms
         FROM business_profiles
         WHERE owner_user_id = :owner_user_id AND invoice_setup_completed_at IS NOT NULL
         LIMIT 1'
    );
    $bpStmt->execute([':owner_user_id' => $ownerId]);
    $bp = $bpStmt->fetch();
    if (!$bp) {
        Response::json(['error' => 'Complete invoice setup in Settings before generating invoices'], 403);
        return;
    }

    $orderStmt = $pdo->prepare(
        'SELECT o.id, o.customer_id, o.title, o.amount_total, o.due_date, c.full_name AS customer_name, c.phone_number AS customer_phone
         FROM orders o
         INNER JOIN customers c ON c.id = o.customer_id
         WHERE o.id = :order_id AND o.owner_user_id = :owner_user_id
         LIMIT 1'
    );
    $orderStmt->execute([':order_id' => $orderId, ':owner_user_id' => $ownerId]);
    $order = $orderStmt->fetch();
    if (!$order) {
        Response::json(['error' => 'Order not found'], 404);
        return;
    }

    $existingInvoiceStmt = $pdo->prepare('SELECT id, invoice_number FROM invoices WHERE order_id = :order_id AND owner_user_id = :owner_user_id LIMIT 1');
    $existingInvoiceStmt->execute([':order_id' => $orderId, ':owner_user_id' => $ownerId]);
    $existingInvoice = $existingInvoiceStmt->fetch();
    if ($existingInvoice) {
        Response::json([
            'message' => 'Invoice already exists for this order',
            'invoice_id' => $existingInvoice['id'],
            'invoice_number' => $existingInvoice['invoice_number'],
        ], 200);
        return;
    }

    $seqStmt = $pdo->prepare(
        'SELECT COALESCE(MAX(CAST(invoice_number AS UNSIGNED)), 0) + 1 AS next_num
         FROM invoices
         WHERE owner_user_id = :owner_user_id'
    );
    $seqStmt->execute([':owner_user_id' => $ownerId]);
    $nextNum = (int)$seqStmt->fetchColumn();
    $invoiceNumber = (string)$nextNum;

    $subtotal = (float)$order['amount_total'];
    $vatRate = ((int)$bp['vat_enabled']) === 1 ? (float)$bp['default_vat_rate'] : 0;
    $vatAmount = $subtotal * ($vatRate / 100);
    $total = $subtotal + $vatAmount;
    $issuedAt = date('Y-m-d H:i:s');
    $dueAt = $order['due_date'] ?? null;

    $invoiceId = Uuid::v4();
    $itemId = Uuid::v4();

    try {
        $pdo->beginTransaction();

        $invStmt = $pdo->prepare(
            'INSERT INTO invoices (id, owner_user_id, order_id, invoice_number, subtotal_amount, discount_amount, total_amount, issued_at, due_at, status, created_at, updated_at, last_modified_at)
             VALUES (:id, :owner_user_id, :order_id, :invoice_number, :subtotal, 0, :total, :issued_at, :due_at, \'issued\', NOW(), NOW(), NOW())'
        );
        $invStmt->execute([
            ':id' => $invoiceId,
            ':owner_user_id' => $ownerId,
            ':order_id' => $orderId,
            ':invoice_number' => $invoiceNumber,
            ':subtotal' => $subtotal,
            ':total' => $total,
            ':issued_at' => $issuedAt,
            ':due_at' => $dueAt,
        ]);

        $itemStmt = $pdo->prepare(
            'INSERT INTO invoice_items (id, invoice_id, description, quantity, unit_price, amount, created_at)
             VALUES (:id, :invoice_id, :description, 1, :unit_price, :amount, NOW())'
        );
        $itemStmt->execute([
            ':id' => $itemId,
            ':invoice_id' => $invoiceId,
            ':description' => (string)$order['title'],
            ':unit_price' => $subtotal,
            ':amount' => $subtotal,
        ]);

        $pdo->commit();
    } catch (\Throwable $e) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        Response::json(['error' => 'Failed to create invoice: ' . $e->getMessage()], 500);
        return;
    }

    Response::json([
        'message' => 'Invoice generated',
        'invoice_id' => $invoiceId,
        'invoice_number' => $invoiceNumber,
        'order_id' => $orderId,
        'total_amount' => $total,
        'currency' => (string)$bp['currency'],
    ], 201);
}

if ($method === 'GET' && routeMatches($path, '/api/invoices/by-order')) {
    $ownerId = (string)($authUser['id'] ?? '');
    $orderId = trim((string)($_GET['order_id'] ?? ''));
    if ($orderId === '') {
        Response::json(['error' => 'order_id is required'], 422);
        return;
    }

    $stmt = $pdo->prepare(
        'SELECT i.id, i.order_id, i.invoice_number, i.subtotal_amount, i.discount_amount, i.total_amount,
                i.issued_at, i.due_at, i.status,
                bp.business_name, bp.business_phone, bp.business_email, bp.business_address,
                bp.currency, bp.vat_enabled, bp.default_vat_rate, bp.payment_terms, bp.logo_data,
                o.title AS order_title, o.amount_total AS order_amount, o.notes AS order_notes,
                c.full_name AS customer_name, c.phone_number AS customer_phone'
        . ' FROM invoices i'
        . ' INNER JOIN business_profiles bp ON bp.owner_user_id = i.owner_user_id'
        . ' INNER JOIN orders o ON o.id = i.order_id'
        . ' INNER JOIN customers c ON c.id = o.customer_id'
        . ' WHERE i.order_id = :order_id AND i.owner_user_id = :owner_user_id'
        . ' LIMIT 1'
    );
    $stmt->execute([':order_id' => $orderId, ':owner_user_id' => $ownerId]);
    $invoice = $stmt->fetch();
    if (!$invoice) {
        Response::json(['error' => 'Invoice not found for this order'], 404);
        return;
    }

    $itemsStmt = $pdo->prepare(
        'SELECT id, description, quantity, unit_price, amount FROM invoice_items WHERE invoice_id = :invoice_id ORDER BY created_at'
    );
    $itemsStmt->execute([':invoice_id' => $invoice['id']]);
    $invoice['items'] = $itemsStmt->fetchAll();

    Response::json(['data' => $invoice]);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/reminders/daily-digest/subscribe')) {
    $ownerId = (string)($authUser['id'] ?? '');
    $planCode = (string)($authUser['plan_code'] ?? 'starter');
    if (!in_array($planCode, ['growth', 'pro'], true)) {
        Response::json(['error' => 'Daily email digest is available on Growth/Pro plan only'], 403);
        return;
    }
    try {
        $stmt = $pdo->prepare('UPDATE users SET email_digest_enabled = 1 WHERE id = :id');
        $stmt->execute([':id' => $ownerId]);
    } catch (\Throwable $e) {
        if (str_contains($e->getMessage(), 'email_digest_enabled')) {
            Response::json(['error' => 'Email digest not available. Run migration 005.'], 500);
            return;
        }
        throw $e;
    }
    Response::json(['message' => 'Subscribed to daily email digest']);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/reminders/daily-digest/unsubscribe')) {
    $ownerId = (string)($authUser['id'] ?? '');
    try {
        $stmt = $pdo->prepare('UPDATE users SET email_digest_enabled = 0 WHERE id = :id');
        $stmt->execute([':id' => $ownerId]);
    } catch (\Throwable $e) {
        if (str_contains($e->getMessage(), 'email_digest_enabled')) {
            Response::json(['message' => 'Unsubscribed']);
            return;
        }
        throw $e;
    }
    Response::json(['message' => 'Unsubscribed from daily email digest']);
    return;
}

if ($method === 'GET' && routeMatches($path, '/api/reminders/daily-digest/status')) {
    $ownerId = (string)($authUser['id'] ?? '');
    try {
        $stmt = $pdo->prepare('SELECT email_digest_enabled FROM users WHERE id = :id LIMIT 1');
        $stmt->execute([':id' => $ownerId]);
        $row = $stmt->fetch();
        $enabled = $row && ((int)($row['email_digest_enabled'] ?? 0)) === 1;
    } catch (\Throwable $e) {
        $enabled = false;
    }
    Response::json(['email_digest_enabled' => $enabled]);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/sync/push')) {
    if (!hasPlanFeature($pdo, (array)$authUser, 'can_sync')) {
        Response::json(['error' => 'Cloud sync is available on Growth/Pro plan only'], 403);
        return;
    }
    // Placeholder for mobile offline queue upload.
    Response::json([
        'message' => 'Sync push accepted',
        'next' => 'Implement per-entity conflict handling by last_modified_at',
    ]);
    return;
}

if ($method === 'GET' && routeMatches($path, '/api/sync/pull')) {
    if (!hasPlanFeature($pdo, (array)$authUser, 'can_sync')) {
        Response::json(['error' => 'Cloud sync is available on Growth/Pro plan only'], 403);
        return;
    }
    // Placeholder for incremental changes download.
    Response::json([
        'message' => 'Sync pull accepted',
        'next' => 'Return changed records since cursor timestamp',
    ]);
    return;
}

if ($method === 'GET' && routeMatches($path, '/api/export/measurements')) {
    if (!hasPlanFeature($pdo, (array)$authUser, 'can_export')) {
        Response::json(['error' => 'Export is available on Growth/Pro plan only'], 403);
        return;
    }

    $ownerId = (string)($authUser['id'] ?? '');
    $customerId = trim((string)($_GET['customer_id'] ?? ''));
    $startDate = trim((string)($_GET['start_date'] ?? ''));
    $endDate = trim((string)($_GET['end_date'] ?? ''));

    $sql = 'SELECT m.id, c.id AS customer_id, c.full_name AS customer_name, m.taken_at, m.payload_json
            FROM measurements m
            INNER JOIN customers c ON c.id = m.customer_id
            WHERE c.owner_user_id = :owner_user_id';
    $params = [':owner_user_id' => $ownerId];
    if ($customerId !== '') {
        $sql .= ' AND c.id = :customer_id';
        $params[':customer_id'] = $customerId;
    }
    if ($startDate !== '') {
        $sql .= ' AND m.taken_at >= :start_date';
        $params[':start_date'] = $startDate . ' 00:00:00';
    }
    if ($endDate !== '') {
        $sql .= ' AND m.taken_at <= :end_date';
        $params[':end_date'] = $endDate . ' 23:59:59';
    }
    $sql .= ' ORDER BY m.taken_at DESC';

    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    $rows = $stmt->fetchAll();

    Response::json(['data' => $rows]);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/admin/login')) {
    $data = requestBody();
    $email = strtolower(trim((string)($data['email'] ?? '')));
    $password = (string)($data['password'] ?? '');
    if ($email === '' || $password === '') {
        Response::json(['error' => 'email and password are required'], 422);
        return;
    }
    $stmt = $pdo->prepare(
        'SELECT id, password_hash, full_name FROM admin_users WHERE email = :email LIMIT 1'
    );
    $stmt->execute([':email' => $email]);
    $admin = $stmt->fetch();
    if (!$admin || !password_verify($password, (string)$admin['password_hash'])) {
        Response::json(['error' => 'Invalid email or password'], 401);
        return;
    }
    $token = issueAdminToken($pdo, (string)$admin['id']);
    Response::json([
        'token' => $token,
        'admin' => [
            'id' => $admin['id'],
            'email' => $email,
            'full_name' => $admin['full_name'],
        ],
    ]);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/admin/logout')) {
    $token = bearerToken();
    if ($token !== null && $token !== '') {
        $tokenHash = hash('sha256', $token);
        $pdo->prepare('DELETE FROM admin_sessions WHERE token_hash = :token_hash')
            ->execute([':token_hash' => $tokenHash]);
    }
    Response::json(['message' => 'Logged out']);
    return;
}

if ($method === 'GET' && routeMatches($path, '/api/admin/dashboard')) {
    $upcomingLimit = max(1, min(30, (int)($_GET['upcoming_limit'] ?? 8)));

    $userCountStmt = $pdo->query('SELECT COUNT(*) FROM users WHERE is_guest = 0');
    $userCount = (int)$userCountStmt->fetchColumn();

    $customerCountStmt = $pdo->query('SELECT COUNT(*) FROM customers');
    $customerCount = (int)$customerCountStmt->fetchColumn();

    $measurementCountStmt = $pdo->query('SELECT COUNT(*) FROM measurements');
    $measurementCount = (int)$measurementCountStmt->fetchColumn();

    $orderCountStmt = $pdo->query('SELECT COUNT(*) FROM orders');
    $orderCount = (int)$orderCountStmt->fetchColumn();

    $orderStatusStmt = $pdo->query(
        'SELECT status, COUNT(*) AS total FROM orders GROUP BY status'
    );
    $orderStatuses = $orderStatusStmt->fetchAll();

    $upcomingStmt = $pdo->prepare(
        'SELECT o.id, o.title, c.full_name AS customer_name, o.due_date, o.status
         FROM orders o
         INNER JOIN customers c ON c.id = o.customer_id
         WHERE o.due_date IS NOT NULL
           AND o.status NOT IN (\'delivered\', \'cancelled\')
         ORDER BY o.due_date ASC
         LIMIT :limit_rows'
    );
    $upcomingStmt->bindValue(':limit_rows', $upcomingLimit, \PDO::PARAM_INT);
    $upcomingStmt->execute();
    $upcoming = $upcomingStmt->fetchAll();

    Response::json([
        'summary' => [
            'users' => $userCount,
            'customers' => $customerCount,
            'measurements' => $measurementCount,
            'orders' => $orderCount,
        ],
        'order_statuses' => $orderStatuses,
        'upcoming_orders' => $upcoming,
    ]);
    return;
}

if ($method === 'GET' && routeMatches($path, '/api/admin/plans')) {
    $stmt = $pdo->query(
        'SELECT plan_code, customer_limit, can_sync, can_export, can_multi_device, can_advanced_reminders, updated_at
         FROM plan_settings
         ORDER BY FIELD(plan_code, \'starter\', \'growth\', \'pro\')'
    );
    Response::json(['data' => $stmt->fetchAll()]);
    return;
}

if ($method === 'PATCH' && routeMatches($path, '/api/admin/plans')) {
    $data = requestBody();
    $planCode = strtolower(trim((string)($data['plan_code'] ?? '')));
    if (!in_array($planCode, ['starter', 'growth', 'pro'], true)) {
        Response::json(['error' => 'plan_code must be starter, growth, or pro'], 422);
        return;
    }

    $fields = [];
    $params = [':plan_code' => $planCode];

    if (array_key_exists('customer_limit', $data)) {
        $limit = $data['customer_limit'];
        if ($limit !== null && (!is_numeric($limit) || (int)$limit < 1 || (int)$limit > 500000)) {
            Response::json(['error' => 'customer_limit must be null or an integer between 1 and 500000'], 422);
            return;
        }
        $fields[] = 'customer_limit = :customer_limit';
        $params[':customer_limit'] = $limit === null ? null : (int)$limit;
    }

    $boolFields = ['can_sync', 'can_export', 'can_multi_device', 'can_advanced_reminders'];
    foreach ($boolFields as $name) {
        if (array_key_exists($name, $data)) {
            $value = filter_var($data[$name], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
            if ($value === null) {
                Response::json(['error' => $name . ' must be a boolean'], 422);
                return;
            }
            $fields[] = $name . ' = :' . $name;
            $params[':' . $name] = $value ? 1 : 0;
        }
    }

    if (empty($fields)) {
        Response::json(['error' => 'No updatable fields provided'], 422);
        return;
    }

    $sql = 'UPDATE plan_settings SET ' . implode(', ', $fields) . ', updated_at = NOW() WHERE plan_code = :plan_code';
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);

    $read = $pdo->prepare(
        'SELECT plan_code, customer_limit, can_sync, can_export, can_multi_device, can_advanced_reminders, updated_at
         FROM plan_settings
         WHERE plan_code = :plan_code
         LIMIT 1'
    );
    $read->execute([':plan_code' => $planCode]);
    $row = $read->fetch();
    if (!$row) {
        Response::json(['error' => 'Plan settings not found'], 404);
        return;
    }

    Response::json(['message' => 'Plan settings updated', 'data' => $row]);
    return;
}

if ($method === 'GET' && routeMatches($path, '/api/diagnostics')) {
    $dbOk = false;
    try {
        $pingStmt = $pdo->query('SELECT 1');
        $dbOk = $pingStmt !== false;
    } catch (\Throwable) {
        $dbOk = false;
    }

    Response::json([
        'service' => 'oga-tailor-api',
        'db_ok' => $dbOk,
        'auth_user_id' => $authUser['id'] ?? null,
        'timestamp' => date('c'),
    ]);
    return;
}

$logDir = dirname(__DIR__) . '/storage/logs';
$logFile = $logDir . '/php-error.log';
if (!is_dir($logDir)) {
    @mkdir($logDir, 0775, true);
}
$logMsg = sprintf(
    "[%s] Route not found. method=%s path=%s uri=%s script_name=%s request_filename=%s\n",
    date('Y-m-d H:i:s'),
    $method,
    $path,
    $_SERVER['REQUEST_URI'] ?? '',
    $_SERVER['SCRIPT_NAME'] ?? '',
    $_SERVER['REQUEST_FILENAME'] ?? '(not set)'
);
@file_put_contents($logFile, $logMsg, FILE_APPEND | LOCK_EX);
error_log('Route not found: ' . $path);
Response::json(['error' => 'Not Found'], 404);

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

    $stmt = $pdo->prepare(
        'INSERT INTO auth_tokens (user_id, token_hash, expires_at, created_at)
         VALUES (:user_id, :token_hash, NULL, NOW())'
    );
    $stmt->execute([
        ':user_id' => $userId,
        ':token_hash' => $tokenHash,
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
         LIMIT 1'
    );
    $stmt->execute([':token_hash' => $tokenHash]);
    $user = $stmt->fetch();
    return $user ?: null;
}

function requirePaid(array $authUser): bool
{
    return ($authUser['plan_code'] ?? 'free') === 'paid';
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
    routeMatches($path, '/api/auth/reset-password');

$authUser = null;
if (routeMatches($path, '/api/') && !$isPublicRoute) {
    $authUser = authenticatedUser($pdo);
    if (!$authUser) {
        Response::json(['error' => 'Unauthorized'], 401);
        return;
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
        ':plan_code' => 'free',
    ]);

    $token = issueAuthToken($pdo, $userId);
    Response::json([
        'user_id' => $userId,
        'mode' => 'guest',
        'token' => $token,
    ], 201);
    return;
}

if ($method === 'POST' && routeMatches($path, '/api/auth/register')) {
    $data = requestBody();
    $fullName = trim((string)($data['full_name'] ?? ''));
    $email = strtolower(trim((string)($data['email'] ?? '')));
    $password = (string)($data['password'] ?? '');
    $guestUserId = trim((string)($data['guest_user_id'] ?? ''));

    if ($fullName === '' || $email === '' || $password === '') {
        Response::json(['error' => 'full_name, email and password are required'], 422);
        return;
    }

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        Response::json(['error' => 'email is invalid'], 422);
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
                 email = :email,
                 password_hash = :password_hash,
                 is_guest = 0,
                 guest_device_id = NULL,
                 updated_at = NOW()
             WHERE id = :id'
        );
        $upgradeStmt->execute([
            ':id' => $guestUserId,
            ':full_name' => $fullName,
            ':email' => $email,
            ':password_hash' => $passwordHash,
        ]);

        $token = issueAuthToken($pdo, $guestUserId);
        Response::json([
            'user_id' => $guestUserId,
            'mode' => 'registered',
            'token' => $token,
        ]);
        return;
    }

    $userId = Uuid::v4();
    $createUserStmt = $pdo->prepare(
        'INSERT INTO users (id, full_name, email, password_hash, is_guest, guest_device_id, plan_code, plan_expires_at, created_at, updated_at)
         VALUES (:id, :full_name, :email, :password_hash, 0, NULL, :plan_code, NULL, NOW(), NOW())'
    );
    $createUserStmt->execute([
        ':id' => $userId,
        ':full_name' => $fullName,
        ':email' => $email,
        ':password_hash' => $passwordHash,
        ':plan_code' => 'free',
    ]);

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
    $stmt = $pdo->prepare('SELECT id, full_name, email, is_guest, plan_code FROM users WHERE id = :id LIMIT 1');
    $stmt->execute([':id' => $userId]);
    $user = $stmt->fetch();
    if (!$user) {
        Response::json(['error' => 'user not found'], 404);
        return;
    }
    Response::json(['data' => $user]);
    return;
}

if ($method === 'PATCH' && routeMatches($path, '/api/auth/profile')) {
    $userId = (string)($authUser['id'] ?? '');
    $data = requestBody();
    $fullName = trim((string)($data['full_name'] ?? ''));
    $email = strtolower(trim((string)($data['email'] ?? '')));
    if ($fullName === '' || $email === '') {
        Response::json(['error' => 'full_name and email are required'], 422);
        return;
    }
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        Response::json(['error' => 'email is invalid'], 422);
        return;
    }

    $stmt = $pdo->prepare(
        'UPDATE users
         SET full_name = :full_name, email = :email, updated_at = NOW()
         WHERE id = :id'
    );
    $stmt->execute([
        ':id' => $userId,
        ':full_name' => $fullName,
        ':email' => $email,
    ]);
    Response::json(['message' => 'Profile updated']);
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

    Response::json([
        'plan_code' => $user['plan_code'],
        'plan_expires_at' => $user['plan_expires_at'],
        'customer_count' => $customerCount,
        'customer_limit' => ($user['plan_code'] ?? 'free') === 'free' ? 100 : null,
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

    if (($authUser['plan_code'] ?? 'free') === 'free') {
        $countStmt = $pdo->prepare('SELECT COUNT(*) FROM customers WHERE owner_user_id = :owner_user_id');
        $countStmt->execute([':owner_user_id' => $ownerId]);
        $customerCount = (int)$countStmt->fetchColumn();
        if ($customerCount >= 100) {
            Response::json([
                'error' => 'Free plan limit reached (100 customers). Upgrade to continue.',
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

    $stmt = $pdo->prepare(
        'SELECT id, owner_user_id, full_name, phone_number, notes, created_at, updated_at, last_modified_at
         , gender
         FROM customers
         WHERE owner_user_id = :owner_user_id
         AND (notes IS NULL OR notes NOT LIKE \'[ARCHIVED]%\')
         ORDER BY full_name ASC'
    );
    $stmt->execute([':owner_user_id' => $ownerId]);
    Response::json(['data' => $stmt->fetchAll()]);
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
    $customerId = $data['customer_id'] ?? null;
    $takenAt = $data['taken_at'] ?? null;
    $payload = $data['payload'] ?? null;

    if (!$customerId || !$takenAt || !is_array($payload)) {
        Response::json(['error' => 'customer_id, taken_at and payload are required'], 422);
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
    $customerId = $_GET['customer_id'] ?? null;
    if (!$customerId) {
        Response::json(['error' => 'customer_id is required'], 422);
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
    $measurementId = trim((string)($data['measurement_id'] ?? ''));
    $takenAt = trim((string)($data['taken_at'] ?? ''));
    $payload = $data['payload'] ?? null;

    if ($measurementId === '' || $takenAt === '' || !is_array($payload)) {
        Response::json(['error' => 'measurement_id, taken_at and payload are required'], 422);
        return;
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
    $amountTotal = (float)($data['amount_total'] ?? 0);
    $notes = trim((string)($data['notes'] ?? ''));

    if ($customerId === '' || $title === '') {
        Response::json(['error' => 'customer_id and title are required'], 422);
        return;
    }

    $allowedStatuses = ['pending', 'in_progress', 'ready', 'delivered', 'cancelled'];
    if (!in_array($status, $allowedStatuses, true)) {
        Response::json(['error' => 'invalid order status'], 422);
        return;
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
        'SELECT o.id, o.owner_user_id, o.customer_id, c.full_name AS customer_name, o.title, o.status, o.due_date, o.amount_total, o.notes, o.created_at, o.updated_at
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

    if ($orderId === '' || $status === '') {
        Response::json(['error' => 'order_id and status are required'], 422);
        return;
    }

    $allowedStatuses = ['pending', 'in_progress', 'ready', 'delivered', 'cancelled'];
    if (!in_array($status, $allowedStatuses, true)) {
        Response::json(['error' => 'invalid order status'], 422);
        return;
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

    if ($orderId === '') {
        Response::json(['error' => 'order_id is required'], 422);
        return;
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

if ($method === 'POST' && routeMatches($path, '/api/sync/push')) {
    if (!requirePaid((array)$authUser)) {
        Response::json(['error' => 'Cloud sync is available on paid plan only'], 403);
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
    if (!requirePaid((array)$authUser)) {
        Response::json(['error' => 'Cloud sync is available on paid plan only'], 403);
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
    if (!requirePaid((array)$authUser)) {
        Response::json(['error' => 'Export is available on paid plan only'], 403);
        return;
    }

    $ownerId = (string)($authUser['id'] ?? '');
    $stmt = $pdo->prepare(
        'SELECT c.full_name AS customer_name, m.taken_at, m.payload_json
         FROM measurements m
         INNER JOIN customers c ON c.id = m.customer_id
         WHERE c.owner_user_id = :owner_user_id
         ORDER BY m.taken_at DESC'
    );
    $stmt->execute([':owner_user_id' => $ownerId]);
    $rows = $stmt->fetchAll();

    Response::json(['data' => $rows]);
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

error_log(sprintf(
    'Route not found. method=%s path=%s uri=%s script_name=%s',
    $method,
    $path,
    $_SERVER['REQUEST_URI'] ?? '',
    $_SERVER['SCRIPT_NAME'] ?? ''
));
Response::json(['error' => 'Not Found'], 404);

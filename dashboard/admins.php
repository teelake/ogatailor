<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
requireAdmin();

use App\Support\Uuid;

$message = '';
$messageType = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = strtolower(trim((string)($_POST['email'] ?? '')));
    $fullName = trim((string)($_POST['full_name'] ?? ''));
    $password = (string)($_POST['password'] ?? '');

    if ($email === '' || $fullName === '' || $password === '') {
        $message = 'All fields are required.';
        $messageType = 'error';
    } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        $message = 'Invalid email format.';
        $messageType = 'error';
    } elseif (strlen($password) < 6) {
        $message = 'Password must be at least 6 characters.';
        $messageType = 'error';
    } else {
        $exists = $pdo->prepare('SELECT id FROM admin_users WHERE email = :email');
        $exists->execute([':email' => $email]);
        if ($exists->fetch()) {
            $message = 'Email already in use.';
            $messageType = 'error';
        } else {
            $id = Uuid::v4();
            $hash = password_hash($password, PASSWORD_DEFAULT);
            $pdo->prepare(
                'INSERT INTO admin_users (id, email, password_hash, full_name, created_at, updated_at)
                 VALUES (:id, :email, :hash, :name, NOW(), NOW())'
            )->execute([':id' => $id, ':email' => $email, ':hash' => $hash, ':name' => $fullName]);
            $message = 'Admin added successfully.';
            $messageType = 'success';
        }
    }
}

$admins = $pdo->query(
    'SELECT id, email, full_name, created_at FROM admin_users ORDER BY created_at DESC'
)->fetchAll();

$pageTitle = 'Admins';
require __DIR__ . '/includes/header.php';
?>

<div class="page-header">
    <h1>Admins</h1>
</div>

<?php if ($message): ?>
<div class="alert alert-<?= $messageType ?>"><?= escapeHtml($message) ?></div>
<?php endif; ?>

<div class="grid-2">
    <div class="card">
        <div class="card-title">Add new admin</div>
        <form method="post">
            <div class="form-group">
                <label>Full name</label>
                <input type="text" name="full_name" class="form-control" required>
            </div>
            <div class="form-group">
                <label>Email</label>
                <input type="email" name="email" class="form-control" required>
            </div>
            <div class="form-group">
                <label>Password</label>
                <input type="password" name="password" class="form-control" required minlength="6">
            </div>
            <button type="submit" class="btn btn-primary">Add admin</button>
        </form>
    </div>

    <div class="card">
        <div class="card-title">Admin users</div>
        <div class="table-wrap">
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Joined</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($admins as $a): ?>
                    <tr>
                        <td><?= escapeHtml($a['full_name']) ?></td>
                        <td><?= escapeHtml($a['email']) ?></td>
                        <td><?= date('M j, Y', strtotime($a['created_at'])) ?></td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<?php require __DIR__ . '/includes/footer.php'; ?>

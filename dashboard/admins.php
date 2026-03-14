<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
requireAdmin();

use App\Support\Uuid;

$message = '';
$messageType = '';
$currentAdminId = $_SESSION['admin_id'];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    requireCsrf();
    $action = $_POST['_action'] ?? 'add';

    if ($action === 'add') {
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
                adminAuditLog($pdo, 'admin_add', 'admin_users', $id, ['email' => $email]);
                $message = 'Admin added successfully.';
                $messageType = 'success';
            }
        }
    } elseif ($action === 'edit') {
        $id = trim((string)($_POST['admin_id'] ?? ''));
        $fullName = trim((string)($_POST['full_name'] ?? ''));
        $email = strtolower(trim((string)($_POST['email'] ?? '')));
        if ($id === '' || $fullName === '' || $email === '') {
            $message = 'All fields are required.';
            $messageType = 'error';
        } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $message = 'Invalid email format.';
            $messageType = 'error';
        } else {
            $check = $pdo->prepare('SELECT id FROM admin_users WHERE email = :email AND id != :id');
            $check->execute([':email' => $email, ':id' => $id]);
            if ($check->fetch()) {
                $message = 'Email already in use.';
                $messageType = 'error';
            } else {
                $pdo->prepare('UPDATE admin_users SET full_name = :name, email = :email, updated_at = NOW() WHERE id = :id')
                    ->execute([':name' => $fullName, ':email' => $email, ':id' => $id]);
                if ($id === $currentAdminId) {
                    $_SESSION['admin_name'] = $fullName;
                    $_SESSION['admin_email'] = $email;
                }
                adminAuditLog($pdo, 'admin_edit', 'admin_users', $id, ['email' => $email]);
                $message = 'Admin updated.';
                $messageType = 'success';
            }
        }
    } elseif ($action === 'reset_password') {
        $id = trim((string)($_POST['admin_id'] ?? ''));
        $newPass = (string)($_POST['new_password'] ?? '');
        if ($id === '' || strlen($newPass) < 6) {
            $message = 'Password must be at least 6 characters.';
            $messageType = 'error';
        } else {
            $hash = password_hash($newPass, PASSWORD_DEFAULT);
            $pdo->prepare('UPDATE admin_users SET password_hash = :hash, updated_at = NOW() WHERE id = :id')
                ->execute([':hash' => $hash, ':id' => $id]);
            adminAuditLog($pdo, 'admin_reset_password', 'admin_users', $id, []);
            $message = 'Password reset.';
            $messageType = 'success';
        }
    } elseif ($action === 'remove') {
        $id = trim((string)($_POST['admin_id'] ?? ''));
        if ($id === $currentAdminId) {
            $message = 'You cannot remove yourself.';
            $messageType = 'error';
        } elseif ($id === '') {
            $message = 'Invalid admin.';
            $messageType = 'error';
        } else {
            $pdo->prepare('DELETE FROM admin_users WHERE id = :id')->execute([':id' => $id]);
            adminAuditLog($pdo, 'admin_remove', 'admin_users', $id, []);
            $message = 'Admin removed.';
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
            <?= csrfField() ?>
            <input type="hidden" name="_action" value="add">
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
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($admins as $a): ?>
                    <tr>
                        <td><?= escapeHtml($a['full_name']) ?></td>
                        <td><?= escapeHtml($a['email']) ?></td>
                        <td><?= date('M j, Y', strtotime($a['created_at'])) ?></td>
                        <td class="actions-cell">
                            <button type="button" class="btn btn-sm btn-secondary btn-edit-admin" data-id="<?= escapeHtml($a['id']) ?>" data-name="<?= escapeHtml($a['full_name']) ?>" data-email="<?= escapeHtml($a['email']) ?>">Edit</button>
                            <button type="button" class="btn btn-sm btn-secondary btn-reset-admin" data-id="<?= escapeHtml($a['id']) ?>" data-name="<?= escapeHtml($a['full_name']) ?>">Reset password</button>
                            <?php if ($a['id'] !== $currentAdminId): ?>
                            <form method="post" class="inline-form confirm-submit" data-confirm="Remove this admin?">
                                <?= csrfField() ?>
                                <input type="hidden" name="_action" value="remove">
                                <input type="hidden" name="admin_id" value="<?= escapeHtml($a['id']) ?>">
                                <button type="submit" class="btn btn-sm btn-danger">Remove</button>
                            </form>
                            <?php endif; ?>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<div id="edit-modal" class="modal" style="display:none;">
    <div class="modal-backdrop"></div>
    <div class="modal-content">
        <div class="modal-header">
            <h3>Edit admin</h3>
            <button type="button" class="modal-close">&times;</button>
        </div>
        <form method="post" id="edit-form">
            <?= csrfField() ?>
            <input type="hidden" name="_action" value="edit">
            <input type="hidden" name="admin_id" id="edit-admin-id">
            <div class="form-group">
                <label>Full name</label>
                <input type="text" name="full_name" id="edit-full-name" class="form-control" required>
            </div>
            <div class="form-group">
                <label>Email</label>
                <input type="email" name="email" id="edit-email" class="form-control" required>
            </div>
            <button type="submit" class="btn btn-primary">Save</button>
        </form>
    </div>
</div>

<div id="reset-modal" class="modal" style="display:none;">
    <div class="modal-backdrop"></div>
    <div class="modal-content">
        <div class="modal-header">
            <h3>Reset password for <span id="reset-admin-name"></span></h3>
            <button type="button" class="modal-close">&times;</button>
        </div>
        <form method="post" id="reset-form">
            <?= csrfField() ?>
            <input type="hidden" name="_action" value="reset_password">
            <input type="hidden" name="admin_id" id="reset-admin-id">
            <div class="form-group">
                <label>New password</label>
                <input type="password" name="new_password" class="form-control" required minlength="6">
            </div>
            <button type="submit" class="btn btn-primary">Reset password</button>
        </form>
    </div>
</div>

<script>
document.querySelectorAll('.btn-edit-admin').forEach(btn => {
    btn.addEventListener('click', () => {
        document.getElementById('edit-admin-id').value = btn.dataset.id;
        document.getElementById('edit-full-name').value = btn.dataset.name;
        document.getElementById('edit-email').value = btn.dataset.email;
        document.getElementById('edit-modal').style.display = 'flex';
    });
});
document.querySelectorAll('.btn-reset-admin').forEach(btn => {
    btn.addEventListener('click', () => {
        document.getElementById('reset-admin-id').value = btn.dataset.id;
        document.getElementById('reset-admin-name').textContent = btn.dataset.name;
        document.getElementById('reset-modal').style.display = 'flex';
    });
});
document.querySelectorAll('.modal-close, .modal-backdrop').forEach(el => {
    el.addEventListener('click', () => {
        document.querySelectorAll('.modal').forEach(m => m.style.display = 'none');
    });
});
document.querySelectorAll('.confirm-submit').forEach(form => {
    form.addEventListener('submit', e => {
        if (!confirm(form.dataset.confirm || 'Are you sure?')) e.preventDefault();
    });
});
</script>

<?php require __DIR__ . '/includes/footer.php'; ?>

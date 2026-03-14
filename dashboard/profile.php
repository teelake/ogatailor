<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
requireAdmin();

$admin = adminUser();
$message = '';
$messageType = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    requireCsrf();
    $action = $_POST['_action'] ?? '';

    if ($action === 'profile') {
        $fullName = trim((string)($_POST['full_name'] ?? ''));
        $email = strtolower(trim((string)($_POST['email'] ?? '')));
        if ($fullName === '' || $email === '') {
            $message = 'Name and email are required.';
            $messageType = 'error';
        } elseif (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $message = 'Invalid email format.';
            $messageType = 'error';
        } else {
            $check = $pdo->prepare('SELECT id FROM admin_users WHERE email = :email AND id != :id');
            $check->execute([':email' => $email, ':id' => $admin['id']]);
            if ($check->fetch()) {
                $message = 'Email already in use.';
                $messageType = 'error';
            } else {
                $pdo->prepare('UPDATE admin_users SET full_name = :name, email = :email, updated_at = NOW() WHERE id = :id')
                    ->execute([':name' => $fullName, ':email' => $email, ':id' => $admin['id']]);
                $_SESSION['admin_name'] = $fullName;
                $_SESSION['admin_email'] = $email;
                $message = 'Profile updated.';
                $messageType = 'success';
                $admin = adminUser();
            }
        }
    } elseif ($action === 'password') {
        $current = (string)($_POST['current_password'] ?? '');
        $new = (string)($_POST['new_password'] ?? '');
        $confirm = (string)($_POST['confirm_password'] ?? '');
        if ($current === '' || $new === '' || $confirm === '') {
            $message = 'All password fields are required.';
            $messageType = 'error';
        } elseif (strlen($new) < 6) {
            $message = 'New password must be at least 6 characters.';
            $messageType = 'error';
        } elseif ($new !== $confirm) {
            $message = 'New passwords do not match.';
            $messageType = 'error';
        } else {
            $row = $pdo->prepare('SELECT password_hash FROM admin_users WHERE id = :id')->execute([':id' => $admin['id']]);
            $row = $pdo->prepare('SELECT password_hash FROM admin_users WHERE id = :id');
            $row->execute([':id' => $admin['id']]);
            $user = $row->fetch();
            if (!$user || !password_verify($current, (string)$user['password_hash'])) {
                $message = 'Current password is incorrect.';
                $messageType = 'error';
            } else {
                $hash = password_hash($new, PASSWORD_DEFAULT);
                $pdo->prepare('UPDATE admin_users SET password_hash = :hash, updated_at = NOW() WHERE id = :id')
                    ->execute([':hash' => $hash, ':id' => $admin['id']]);
                $message = 'Password changed.';
                $messageType = 'success';
            }
        }
    } elseif ($action === 'avatar') {
        $remove = isset($_POST['remove_avatar']);
        $data = trim((string)($_POST['profile_picture'] ?? ''));
        if ($remove || ($data === '')) {
            $pdo->prepare('UPDATE admin_users SET profile_picture = NULL, updated_at = NOW() WHERE id = :id')
                ->execute([':id' => $admin['id']]);
            unset($_SESSION['admin_profile_picture']);
            $message = 'Profile picture removed.';
            $messageType = 'success';
            refreshAdminSession($pdo);
        } elseif ($data !== '' && str_starts_with($data, 'data:image/')) {
            if (strlen($data) > 500 * 1024) {
                $message = 'Image too large (max 500KB).';
                $messageType = 'error';
            } else {
                $pdo->prepare('UPDATE admin_users SET profile_picture = :pic, updated_at = NOW() WHERE id = :id')
                    ->execute([':pic' => $data, ':id' => $admin['id']]);
                $_SESSION['admin_profile_picture'] = $data;
                $message = 'Profile picture updated.';
                $messageType = 'success';
                $admin = adminUser();
            }
        }
    }
}

refreshAdminSession($pdo);
$stmt = $pdo->prepare('SELECT id, full_name, email, profile_picture FROM admin_users WHERE id = :id');
$stmt->execute([':id' => $_SESSION['admin_id']]);
$admin = $stmt->fetch();

$pageTitle = 'Profile';
require __DIR__ . '/includes/header.php';
?>

<div class="page-header">
    <h1>Profile</h1>
</div>

<?php if ($message): ?>
<div class="alert alert-<?= $messageType ?>"><?= escapeHtml($message) ?></div>
<?php endif; ?>

<div class="grid-2">
    <div class="card">
        <div class="card-title">Profile picture</div>
        <form method="post" id="avatar-form">
            <?= csrfField() ?>
            <input type="hidden" name="_action" value="avatar">
            <div class="avatar-upload">
                <div class="avatar-preview">
                    <?php if (!empty($admin['profile_picture'])): ?>
                    <img src="<?= escapeHtml($admin['profile_picture']) ?>" alt="">
                    <?php else: ?>
                    <?= strtoupper(substr($admin['full_name'] ?? 'A', 0, 1)) ?>
                    <?php endif; ?>
                </div>
                <div class="avatar-actions">
                    <label class="btn btn-secondary btn-sm">
                        Upload image
                        <input type="file" accept="image/*" id="avatar-input" style="display:none">
                    </label>
                    <button type="submit" name="remove_avatar" value="1" class="btn btn-secondary btn-sm">Remove</button>
                </div>
            </div>
            <input type="hidden" name="profile_picture" id="profile-picture-input" value="">
        </form>
    </div>

    <div class="card">
        <div class="card-title">Edit profile</div>
        <form method="post">
            <?= csrfField() ?>
            <input type="hidden" name="_action" value="profile">
            <div class="form-group">
                <label>Full name</label>
                <input type="text" name="full_name" class="form-control" value="<?= escapeHtml($admin['full_name'] ?? '') ?>" required>
            </div>
            <div class="form-group">
                <label>Email</label>
                <input type="email" name="email" class="form-control" value="<?= escapeHtml($admin['email'] ?? '') ?>" required>
            </div>
            <button type="submit" class="btn btn-primary">Save profile</button>
        </form>
    </div>
</div>

<div class="card">
    <div class="card-title">Change password</div>
    <form method="post" style="max-width: 400px;">
        <?= csrfField() ?>
        <input type="hidden" name="_action" value="password">
        <div class="form-group">
            <label>Current password</label>
            <input type="password" name="current_password" class="form-control" required>
        </div>
        <div class="form-group">
            <label>New password</label>
            <input type="password" name="new_password" class="form-control" required minlength="6">
        </div>
        <div class="form-group">
            <label>Confirm new password</label>
            <input type="password" name="confirm_password" class="form-control" required minlength="6">
        </div>
        <button type="submit" class="btn btn-primary">Change password</button>
    </form>
</div>

<script>
document.getElementById('avatar-input')?.addEventListener('change', function(e) {
    const f = e.target.files[0];
    if (!f || !f.type.startsWith('image/')) return;
    const r = new FileReader();
    r.onload = function() {
        const d = r.result;
        if (d.length > 500 * 1024) { alert('Image too large (max 500KB)'); return; }
        document.getElementById('profile-picture-input').value = d;
        document.querySelector('.avatar-preview').innerHTML = '<img src="' + d + '" alt="">';
        document.getElementById('avatar-form').submit();
    };
    r.readAsDataURL(f);
});
</script>

<?php require __DIR__ . '/includes/footer.php'; ?>

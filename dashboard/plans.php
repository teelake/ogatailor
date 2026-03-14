<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
requireAdmin();

$message = '';
$messageType = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $planCode = strtolower(trim((string)($_POST['plan_code'] ?? '')));
    if (in_array($planCode, ['starter', 'growth', 'pro'], true)) {
        $customerLimit = $_POST['customer_limit'] ?? '';
        $customerLimit = trim($customerLimit) === '' ? null : (int)$customerLimit;
        $canSync = isset($_POST['can_sync']);
        $canExport = isset($_POST['can_export']);
        $canMultiDevice = isset($_POST['can_multi_device']);
        $canAdvancedReminders = isset($_POST['can_advanced_reminders']);

        if ($customerLimit !== null && ($customerLimit < 1 || $customerLimit > 500000)) {
            $message = 'Customer limit must be between 1 and 500000 or empty for unlimited.';
            $messageType = 'error';
        } else {
            $stmt = $pdo->prepare(
                'UPDATE plan_settings SET
                    customer_limit = :customer_limit,
                    can_sync = :can_sync,
                    can_export = :can_export,
                    can_multi_device = :can_multi_device,
                    can_advanced_reminders = :can_advanced_reminders,
                    updated_at = NOW()
                 WHERE plan_code = :plan_code'
            );
            $stmt->execute([
                ':plan_code' => $planCode,
                ':customer_limit' => $customerLimit,
                ':can_sync' => $canSync ? 1 : 0,
                ':can_export' => $canExport ? 1 : 0,
                ':can_multi_device' => $canMultiDevice ? 1 : 0,
                ':can_advanced_reminders' => $canAdvancedReminders ? 1 : 0,
            ]);
            $message = 'Plan settings saved.';
            $messageType = 'success';
        }
    }
}

$plans = $pdo->query(
    'SELECT plan_code, customer_limit, can_sync, can_export, can_multi_device, can_advanced_reminders, updated_at
     FROM plan_settings
     ORDER BY FIELD(plan_code, \'starter\', \'growth\', \'pro\')'
)->fetchAll();

$pageTitle = 'Plans';
require __DIR__ . '/includes/header.php';
?>

<header class="topbar">
    <h2>Plan Configuration</h2>
</header>

<?php if ($message): ?>
<p class="message <?= $messageType ?>"><?= escapeHtml($message) ?></p>
<?php endif; ?>

<div class="plans-grid">
    <?php foreach ($plans as $plan): ?>
    <article class="plan-card">
        <h3><?= escapeHtml(ucfirst($plan['plan_code'])) ?></h3>
        <form method="post">
            <input type="hidden" name="plan_code" value="<?= escapeHtml($plan['plan_code']) ?>">
            <div class="plan-form">
                <label>
                    Customer limit
                    <input type="number" name="customer_limit" min="1" placeholder="Unlimited (blank)"
                        value="<?= $plan['customer_limit'] !== null ? (int)$plan['customer_limit'] : '' ?>">
                </label>
                <label>
                    <input type="checkbox" name="can_sync" <?= (int)$plan['can_sync'] ? 'checked' : '' ?>>
                    Cloud sync
                </label>
                <label>
                    <input type="checkbox" name="can_export" <?= (int)$plan['can_export'] ? 'checked' : '' ?>>
                    Export
                </label>
                <label>
                    <input type="checkbox" name="can_multi_device" <?= (int)$plan['can_multi_device'] ? 'checked' : '' ?>>
                    Multi-device
                </label>
                <label>
                    <input type="checkbox" name="can_advanced_reminders" <?= (int)$plan['can_advanced_reminders'] ? 'checked' : '' ?>>
                    Advanced reminders
                </label>
                <button type="submit" class="btn-save">Save</button>
            </div>
        </form>
    </article>
    <?php endforeach; ?>
</div>

<?php require __DIR__ . '/includes/footer.php'; ?>

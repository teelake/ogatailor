<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
requireAdmin();

$message = '';
$messageType = '';
$tab = $_GET['tab'] ?? 'plans';

$getSetting = function (string $key) use ($pdo): ?string {
    $stmt = $pdo->prepare('SELECT setting_value FROM platform_settings WHERE setting_key = :key');
    $stmt->execute([':key' => $key]);
    $row = $stmt->fetch();
    return $row ? $row['setting_value'] : null;
};

$setSetting = function (string $key, string $value) use ($pdo): void {
    $pdo->prepare(
        'INSERT INTO platform_settings (setting_key, setting_value, updated_at)
         VALUES (:key, :val, NOW())
         ON DUPLICATE KEY UPDATE setting_value = :val, updated_at = NOW()'
    )->execute([':key' => $key, ':val' => $value]);
};

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['_action'] ?? '';

    if ($action === 'plans') {
        $planCode = strtolower(trim((string)($_POST['plan_code'] ?? '')));
        if (in_array($planCode, ['starter', 'growth', 'pro'], true)) {
            $limit = trim((string)($_POST['customer_limit'] ?? ''));
            $customerLimit = $limit === '' ? null : (int)$limit;
            $canSync = isset($_POST['can_sync']);
            $canExport = isset($_POST['can_export']);
            $canMultiDevice = isset($_POST['can_multi_device']);
            $canAdvancedReminders = isset($_POST['can_advanced_reminders']);

            $pdo->prepare(
                'UPDATE plan_settings SET customer_limit = :limit, can_sync = :sync, can_export = :export,
                 can_multi_device = :multi, can_advanced_reminders = :reminders, updated_at = NOW()
                 WHERE plan_code = :code'
            )->execute([
                ':limit' => $customerLimit,
                ':sync' => $canSync ? 1 : 0,
                ':export' => $canExport ? 1 : 0,
                ':multi' => $canMultiDevice ? 1 : 0,
                ':reminders' => $canAdvancedReminders ? 1 : 0,
                ':code' => $planCode,
            ]);
            $message = 'Plan settings saved.';
            $messageType = 'success';
        }
    } elseif ($action === 'invoice') {
        $setSetting('invoice_default_currency', trim((string)($_POST['currency'] ?? 'NGN')));
        $setSetting('invoice_default_vat_rate', trim((string)($_POST['vat_rate'] ?? '7.5')));
        $setSetting('invoice_default_payment_terms', trim((string)($_POST['payment_terms'] ?? '')));
        $setSetting('logo_max_size_kb', (string)($_POST['logo_max_kb'] ?? '500'));
        $setSetting('logo_min_dimension', (string)($_POST['logo_min_dim'] ?? '64'));
        $setSetting('logo_max_dimension', (string)($_POST['logo_max_dim'] ?? '512'));
        $message = 'Invoice defaults saved.';
        $messageType = 'success';
    } elseif ($action === 'reminders') {
        $setSetting('reminder_digest_enabled_default', isset($_POST['digest_default']) ? '1' : '0');
        $setSetting('reminder_days_before_due', (string)($_POST['days_before_due'] ?? '3'));
        $message = 'Reminder settings saved.';
        $messageType = 'success';
    }
}

$plans = $pdo->query(
    'SELECT plan_code, customer_limit, can_sync, can_export, can_multi_device, can_advanced_reminders
     FROM plan_settings ORDER BY FIELD(plan_code, \'starter\', \'growth\', \'pro\')'
)->fetchAll();

$pageTitle = 'Configuration';
require __DIR__ . '/includes/header.php';
?>

<div class="page-header">
    <h1>Configuration</h1>
</div>

<?php if ($message): ?>
<div class="alert alert-<?= $messageType ?>"><?= escapeHtml($message) ?></div>
<?php endif; ?>

<div class="tabs">
    <a href="?tab=plans" class="tab <?= $tab === 'plans' ? 'active' : '' ?>">Plans</a>
    <a href="?tab=invoice" class="tab <?= $tab === 'invoice' ? 'active' : '' ?>">Invoice defaults</a>
    <a href="?tab=reminders" class="tab <?= $tab === 'reminders' ? 'active' : '' ?>">Reminders</a>
</div>

<?php if ($tab === 'plans'): ?>
<div class="grid-3">
    <?php foreach ($plans as $plan): ?>
    <div class="card">
        <div class="card-title"><?= escapeHtml(ucfirst($plan['plan_code'])) ?></div>
        <form method="post">
            <input type="hidden" name="_action" value="plans">
            <input type="hidden" name="plan_code" value="<?= escapeHtml($plan['plan_code']) ?>">
            <div class="form-group">
                <label>Customer limit</label>
                <input type="number" name="customer_limit" class="form-control" min="1" placeholder="Unlimited"
                    value="<?= $plan['customer_limit'] !== null ? (int)$plan['customer_limit'] : '' ?>">
            </div>
            <div class="form-check">
                <input type="checkbox" name="can_sync" id="sync_<?= $plan['plan_code'] ?>" <?= (int)$plan['can_sync'] ? 'checked' : '' ?>>
                <label for="sync_<?= $plan['plan_code'] ?>">Cloud sync</label>
            </div>
            <div class="form-check">
                <input type="checkbox" name="can_export" id="export_<?= $plan['plan_code'] ?>" <?= (int)$plan['can_export'] ? 'checked' : '' ?>>
                <label for="export_<?= $plan['plan_code'] ?>">Export</label>
            </div>
            <div class="form-check">
                <input type="checkbox" name="can_multi_device" id="multi_<?= $plan['plan_code'] ?>" <?= (int)$plan['can_multi_device'] ? 'checked' : '' ?>>
                <label for="multi_<?= $plan['plan_code'] ?>">Multi-device</label>
            </div>
            <div class="form-check">
                <input type="checkbox" name="can_advanced_reminders" id="rem_<?= $plan['plan_code'] ?>" <?= (int)$plan['can_advanced_reminders'] ? 'checked' : '' ?>>
                <label for="rem_<?= $plan['plan_code'] ?>">Advanced reminders</label>
            </div>
            <button type="submit" class="btn btn-primary btn-sm">Save</button>
        </form>
    </div>
    <?php endforeach; ?>
</div>

<?php elseif ($tab === 'invoice'): ?>
<div class="card" style="max-width: 500px;">
    <div class="card-title">Invoice defaults</div>
    <p class="muted" style="margin-bottom: 20px;">Default values for new business profiles. Tailors can override these.</p>
    <form method="post">
        <input type="hidden" name="_action" value="invoice">
        <div class="form-group">
            <label>Default currency</label>
            <input type="text" name="currency" class="form-control" value="<?= escapeHtml($getSetting('invoice_default_currency') ?? 'NGN') ?>" placeholder="NGN">
        </div>
        <div class="form-group">
            <label>Default VAT rate (%)</label>
            <input type="number" name="vat_rate" class="form-control" step="0.01" min="0" max="100"
                value="<?= escapeHtml($getSetting('invoice_default_vat_rate') ?? '7.5') ?>">
        </div>
        <div class="form-group">
            <label>Default payment terms</label>
            <input type="text" name="payment_terms" class="form-control"
                value="<?= escapeHtml($getSetting('invoice_default_payment_terms') ?? '') ?>" placeholder="Payment due within 7 days">
        </div>
        <div class="card-title" style="margin-top: 24px;">Logo validation</div>
        <div class="form-row">
            <div class="form-group">
                <label>Max size (KB)</label>
                <input type="number" name="logo_max_kb" class="form-control" min="100" max="2000"
                    value="<?= escapeHtml($getSetting('logo_max_size_kb') ?? '500') ?>">
            </div>
            <div class="form-group">
                <label>Min dimension (px)</label>
                <input type="number" name="logo_min_dim" class="form-control" min="32" max="256"
                    value="<?= escapeHtml($getSetting('logo_min_dimension') ?? '64') ?>">
            </div>
            <div class="form-group">
                <label>Max dimension (px)</label>
                <input type="number" name="logo_max_dim" class="form-control" min="128" max="1024"
                    value="<?= escapeHtml($getSetting('logo_max_dimension') ?? '512') ?>">
            </div>
        </div>
        <button type="submit" class="btn btn-primary">Save</button>
    </form>
</div>

<?php elseif ($tab === 'reminders'): ?>
<div class="card" style="max-width: 500px;">
    <div class="card-title">Reminder settings</div>
    <form method="post">
        <input type="hidden" name="_action" value="reminders">
        <div class="form-check">
            <input type="checkbox" name="digest_default" id="digest_default" <?= $getSetting('reminder_digest_enabled_default') === '1' ? 'checked' : '' ?>>
            <label for="digest_default">Enable daily digest by default for Growth/Pro</label>
        </div>
        <div class="form-group">
            <label>Default days before due for reminders</label>
            <input type="number" name="days_before_due" class="form-control" min="1" max="30"
                value="<?= escapeHtml($getSetting('reminder_days_before_due') ?? '3') ?>">
        </div>
        <button type="submit" class="btn btn-primary">Save</button>
    </form>
</div>
<?php endif; ?>

<?php require __DIR__ . '/includes/footer.php'; ?>

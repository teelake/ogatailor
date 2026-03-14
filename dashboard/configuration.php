<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
requireAdmin();

$message = '';
$messageType = '';
$tab = $_GET['tab'] ?? 'plans';
$validTabs = ['plans', 'invoice', 'reminders', 'watermark', 'integrations', 'platform'];
$tab = in_array($tab, $validTabs, true) ? $tab : 'plans';

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
    } elseif ($action === 'watermark') {
        $setSetting('watermark_type', in_array($_POST['watermark_type'] ?? '', ['logo', 'url', 'both'], true) ? $_POST['watermark_type'] : 'both');
        $setSetting('watermark_logo_url', trim((string)($_POST['watermark_logo_url'] ?? '')));
        $setSetting('watermark_website_url', trim((string)($_POST['watermark_website_url'] ?? 'https://ogatailor.app')));
        $plans = array_intersect((array)($_POST['watermark_plans'] ?? []), ['starter', 'growth', 'pro']);
        $setSetting('watermark_plans', implode(',', $plans));
        $message = 'Watermark settings saved.';
        $messageType = 'success';
    } elseif ($action === 'integrations') {
        $setSetting('paystack_test_mode', isset($_POST['paystack_test_mode']) ? '1' : '0');
        $secret = trim((string)($_POST['paystack_secret_key'] ?? ''));
        if ($secret !== '' && $secret !== '••••••••••••') {
            $setSetting('paystack_secret_key', $secret);
        }
        $public = trim((string)($_POST['paystack_public_key'] ?? ''));
        if ($public !== '' && $public !== '••••••••••••') {
            $setSetting('paystack_public_key', $public);
        }
        $message = 'API settings saved.';
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
    <a href="?tab=watermark" class="tab <?= $tab === 'watermark' ? 'active' : '' ?>">Watermark</a>
    <a href="?tab=integrations" class="tab <?= $tab === 'integrations' ? 'active' : '' ?>">Integrations</a>
    <a href="?tab=platform" class="tab <?= $tab === 'platform' ? 'active' : '' ?>">Platform</a>
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

<?php elseif ($tab === 'watermark'): ?>
<?php
$watermarkType = $getSetting('watermark_type') ?? 'both';
$watermarkPlans = array_filter(explode(',', $getSetting('watermark_plans') ?? 'starter'));
?>
<div class="card" style="max-width: 560px;">
    <div class="card-title">Invoice watermark</div>
    <p class="muted" style="margin-bottom: 20px;">Watermarks appear on invoices for users on selected plans (e.g. unpaid or lower tiers). Choose logo, URL, or both.</p>
    <form method="post">
        <input type="hidden" name="_action" value="watermark">
        <div class="form-group">
            <label>Watermark type</label>
            <select name="watermark_type" class="form-control">
                <option value="logo" <?= $watermarkType === 'logo' ? 'selected' : '' ?>>Logo only</option>
                <option value="url" <?= $watermarkType === 'url' ? 'selected' : '' ?>>URL only</option>
                <option value="both" <?= $watermarkType === 'both' ? 'selected' : '' ?>>Logo and URL</option>
            </select>
        </div>
        <div class="form-group">
            <label>Logo URL (Oga Tailor logo)</label>
            <input type="url" name="watermark_logo_url" class="form-control"
                value="<?= escapeHtml($getSetting('watermark_logo_url') ?? '') ?>"
                placeholder="https://ogatailor.app/logo.png">
        </div>
        <div class="form-group">
            <label>Website URL</label>
            <input type="url" name="watermark_website_url" class="form-control"
                value="<?= escapeHtml($getSetting('watermark_website_url') ?? 'https://ogatailor.app') ?>"
                placeholder="https://ogatailor.app">
        </div>
        <div class="form-group">
            <label>Plans that get watermark</label>
            <p class="muted" style="font-size: 12px; margin-bottom: 10px;">Select plans where invoices will show the watermark. Leave unselected for no watermark.</p>
            <div class="form-check">
                <input type="checkbox" name="watermark_plans[]" id="wm_starter" value="starter" <?= in_array('starter', $watermarkPlans, true) ? 'checked' : '' ?>>
                <label for="wm_starter">Starter</label>
            </div>
            <div class="form-check">
                <input type="checkbox" name="watermark_plans[]" id="wm_growth" value="growth" <?= in_array('growth', $watermarkPlans, true) ? 'checked' : '' ?>>
                <label for="wm_growth">Growth</label>
            </div>
            <div class="form-check">
                <input type="checkbox" name="watermark_plans[]" id="wm_pro" value="pro" <?= in_array('pro', $watermarkPlans, true) ? 'checked' : '' ?>>
                <label for="wm_pro">Pro</label>
            </div>
        </div>
        <button type="submit" class="btn btn-primary">Save</button>
    </form>
</div>

<?php elseif ($tab === 'integrations'): ?>
<?php
$paystackSecret = $getSetting('paystack_secret_key');
$paystackPublic = $getSetting('paystack_public_key');
$paystackTestMode = $getSetting('paystack_test_mode') === '1';
$smsProvider = $getSetting('sms_provider');
$smsKey = $getSetting('sms_api_key');
$emailProvider = $getSetting('email_provider');
$emailKey = $getSetting('email_api_key');
$maskSecret = fn(?string $s) => $s ? '••••••••••••' . substr($s, -4) : '';
?>
<div class="card" style="max-width: 560px;">
    <div class="card-title">Integrations</div>
    <p class="muted" style="margin-bottom: 20px;">Third-party APIs used platform-wide. Keys are stored securely.</p>

    <form method="post">
        <input type="hidden" name="_action" value="integrations">

        <div class="card-title" style="margin-top: 0; font-size: 15px;">Payments — Paystack</div>
        <p class="muted" style="margin-bottom: 12px; font-size: 13px;"><a href="https://dashboard.paystack.com/#/settings/developer" target="_blank" rel="noopener">Paystack Dashboard → API Keys</a></p>
        <div class="form-check">
            <input type="checkbox" name="paystack_test_mode" id="paystack_test_mode" <?= $paystackTestMode ? 'checked' : '' ?>>
            <label for="paystack_test_mode">Use test keys</label>
        </div>
        <div class="form-group">
            <label>Secret key</label>
            <input type="password" name="paystack_secret_key" class="form-control" autocomplete="new-password"
                placeholder="<?= $paystackSecret ? $maskSecret($paystackSecret) : 'sk_live_xxxx or sk_test_xxxx' ?>" value="">
            <?php if ($paystackSecret): ?><span class="muted" style="font-size: 12px;">Leave blank to keep current</span><?php endif; ?>
        </div>
        <div class="form-group">
            <label>Public key</label>
            <input type="password" name="paystack_public_key" class="form-control" autocomplete="new-password"
                placeholder="<?= $paystackPublic ? $maskSecret($paystackPublic) : 'pk_live_xxxx or pk_test_xxxx' ?>" value="">
            <?php if ($paystackPublic): ?><span class="muted" style="font-size: 12px;">Leave blank to keep current</span><?php endif; ?>
        </div>

        <div class="card-title" style="margin-top: 24px; font-size: 15px;">SMS</div>
        <div class="form-group">
            <label>Provider (e.g. Termii, Twilio)</label>
            <input type="text" name="sms_provider" class="form-control" value="<?= escapeHtml($smsProvider ?? '') ?>" placeholder="Termii">
        </div>
        <div class="form-group">
            <label>API key</label>
            <input type="password" name="sms_api_key" class="form-control" autocomplete="new-password"
                placeholder="<?= $smsKey ? $maskSecret($smsKey) : '' ?>" value="">
            <?php if ($smsKey): ?><span class="muted" style="font-size: 12px;">Leave blank to keep current</span><?php endif; ?>
        </div>

        <div class="card-title" style="margin-top: 24px; font-size: 15px;">Email</div>
        <div class="form-group">
            <label>Provider (e.g. SendGrid, Mailgun)</label>
            <input type="text" name="email_provider" class="form-control" value="<?= escapeHtml($emailProvider ?? '') ?>" placeholder="SendGrid">
        </div>
        <div class="form-group">
            <label>API key</label>
            <input type="password" name="email_api_key" class="form-control" autocomplete="new-password"
                placeholder="<?= $emailKey ? $maskSecret($emailKey) : '' ?>" value="">
            <?php if ($emailKey): ?><span class="muted" style="font-size: 12px;">Leave blank to keep current</span><?php endif; ?>
        </div>

        <button type="submit" class="btn btn-primary" style="margin-top: 16px;">Save</button>
    </form>
</div>

<?php elseif ($tab === 'platform'): ?>
<div class="card" style="max-width: 560px;">
    <div class="card-title">Platform settings</div>
    <p class="muted" style="margin-bottom: 20px;">General platform-wide configuration.</p>
    <form method="post">
        <input type="hidden" name="_action" value="platform">
        <div class="form-group">
            <label>Support email</label>
            <input type="email" name="support_email" class="form-control"
                value="<?= escapeHtml($getSetting('platform_support_email') ?? '') ?>" placeholder="support@ogatailor.app">
        </div>
        <div class="form-group">
            <label>Support phone</label>
            <input type="text" name="support_phone" class="form-control"
                value="<?= escapeHtml($getSetting('platform_support_phone') ?? '') ?>" placeholder="+234...">
        </div>
        <button type="submit" class="btn btn-primary">Save</button>
    </form>
</div>
<?php endif; ?>

<?php require __DIR__ . '/includes/footer.php'; ?>

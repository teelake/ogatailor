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
         ON DUPLICATE KEY UPDATE setting_value = :val2, updated_at = NOW()'
    )->execute([':key' => $key, ':val' => $value, ':val2' => $value]);
};

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    requireCsrf();
    $action = $_POST['_action'] ?? '';

    if ($action === 'plans') {
        $planCode = strtolower(trim((string)($_POST['plan_code'] ?? '')));
        if (in_array($planCode, ['starter', 'growth', 'pro'], true)) {
            $limit = trim((string)($_POST['customer_limit'] ?? ''));
            $customerLimit = $limit === '' ? null : (int)$limit;
            $invoiceLimit = trim((string)($_POST['invoices_per_month'] ?? ''));
            $invoicesPerMonth = $invoiceLimit === '' ? null : (int)$invoiceLimit;
            if (in_array($planCode, ['growth', 'pro'], true)) {
                $priceNgn = trim((string)($_POST['plan_price_ngn'] ?? ''));
                $setSetting('plan_price_' . $planCode, $priceNgn !== '' ? (string)max(0, (int)$priceNgn) : ($planCode === 'growth' ? '5000' : '10000'));
            }
            $canSync = isset($_POST['can_sync']);
            $canExport = isset($_POST['can_export']);
            $canMultiDevice = isset($_POST['can_multi_device']);
            $canAdvancedReminders = isset($_POST['can_advanced_reminders']);

            $pdo->prepare(
                'UPDATE plan_settings SET customer_limit = :limit, invoices_per_month = :invoices,
                 can_sync = :sync, can_export = :export, can_multi_device = :multi,
                 can_advanced_reminders = :reminders, updated_at = NOW()
                 WHERE plan_code = :code'
            )->execute([
                ':limit' => $customerLimit,
                ':invoices' => $invoicesPerMonth,
                ':sync' => $canSync ? 1 : 0,
                ':export' => $canExport ? 1 : 0,
                ':multi' => $canMultiDevice ? 1 : 0,
                ':reminders' => $canAdvancedReminders ? 1 : 0,
                ':code' => $planCode,
            ]);
            $watermarkInvoices = isset($_POST['watermark_invoices']);
            $current = array_filter(explode(',', $getSetting('watermark_plans') ?? ''));
            if ($watermarkInvoices) {
                $current = array_unique(array_merge($current, [$planCode]));
            } else {
                $current = array_values(array_diff($current, [$planCode]));
            }
            $setSetting('watermark_plans', implode(',', array_intersect($current, ['starter', 'growth', 'pro'])));
            adminAuditLog($pdo, 'config_plans', 'plan_settings', $planCode, []);
            $message = 'Plan settings saved.';
            $messageType = 'success';
        }
    } elseif ($action === 'invoice') {
        $setSetting('invoice_default_currency', trim((string)($_POST['currency'] ?? 'NGN')));
        $setSetting('invoice_default_vat_rate', trim((string)($_POST['vat_rate'] ?? '7.5')));
        $currencies = [];
        foreach ((array)($_POST['currencies'] ?? []) as $c) {
            if (is_array($c) && !empty(trim((string)($c['code'] ?? '')))) {
                $currencies[] = [
                    'code' => strtoupper(trim((string)$c['code'])),
                    'symbol' => trim((string)($c['symbol'] ?? $c['code'])),
                    'name' => trim((string)($c['name'] ?? $c['code'])),
                ];
            }
        }
        if (!empty($currencies)) {
            $setSetting('platform_currencies', json_encode($currencies, JSON_UNESCAPED_UNICODE));
        }
        $setSetting('invoice_default_payment_terms', trim((string)($_POST['payment_terms'] ?? '')));
        $setSetting('logo_max_size_kb', (string)($_POST['logo_max_kb'] ?? '500'));
        $setSetting('logo_min_dimension', (string)($_POST['logo_min_dim'] ?? '64'));
        $setSetting('logo_max_dimension', (string)($_POST['logo_max_dim'] ?? '512'));
        adminAuditLog($pdo, 'config_invoice', null, null, []);
        $message = 'Invoice defaults saved.';
        $messageType = 'success';
    } elseif ($action === 'reminders') {
        $setSetting('reminder_digest_enabled_default', isset($_POST['digest_default']) ? '1' : '0');
        $setSetting('reminder_days_before_due', (string)($_POST['days_before_due'] ?? '3'));
        adminAuditLog($pdo, 'config_reminders', null, null, []);
        $message = 'Reminder settings saved.';
        $messageType = 'success';
    } elseif ($action === 'watermark') {
        $setSetting('watermark_type', in_array($_POST['watermark_type'] ?? '', ['logo', 'url', 'both'], true) ? $_POST['watermark_type'] : 'both');
        $setSetting('watermark_logo_url', trim((string)($_POST['watermark_logo_url'] ?? '')));
        $setSetting('watermark_website_url', trim((string)($_POST['watermark_website_url'] ?? 'https://ogatailor.app')));
        $plans = array_intersect((array)($_POST['watermark_plans'] ?? []), ['starter', 'growth', 'pro']);
        $setSetting('watermark_plans', implode(',', $plans));
        adminAuditLog($pdo, 'config_watermark', null, null, []);
        $message = 'Watermark settings saved.';
        $messageType = 'success';
    } elseif ($action === 'integrations') {
        $setSetting('paystack_test_mode', isset($_POST['paystack_test_mode']) ? '1' : '0');
        $secret = trim((string)($_POST['paystack_secret_key'] ?? ''));
        if ($secret !== '' && strpos($secret, '••••') === false) {
            $setSetting('paystack_secret_key', $secret);
        }
        $public = trim((string)($_POST['paystack_public_key'] ?? ''));
        if ($public !== '' && strpos($public, '••••') === false) {
            $setSetting('paystack_public_key', $public);
        }
        if (isset($_POST['clear_paystack_secret'])) {
            $setSetting('paystack_secret_key', '');
        }
        if (isset($_POST['clear_paystack_public'])) {
            $setSetting('paystack_public_key', '');
        }
        $setSetting('sms_provider', trim((string)($_POST['sms_provider'] ?? '')));
        $smsKey = trim((string)($_POST['sms_api_key'] ?? ''));
        if ($smsKey !== '' && strpos($smsKey, '••••') === false) {
            $setSetting('sms_api_key', $smsKey);
        }
        $setSetting('email_provider', trim((string)($_POST['email_provider'] ?? '')));
        $emailKey = trim((string)($_POST['email_api_key'] ?? ''));
        if ($emailKey !== '' && strpos($emailKey, '••••') === false) {
            $setSetting('email_api_key', $emailKey);
        }
        adminAuditLog($pdo, 'config_integrations', null, null, []);
        $message = 'API settings saved.';
        $messageType = 'success';
    } elseif ($action === 'platform') {
        $setSetting('platform_url', trim((string)($_POST['platform_url'] ?? 'https://ogatailor.app')));
        $setSetting('platform_support_email', trim((string)($_POST['support_email'] ?? '')));
        $setSetting('platform_support_phone', trim((string)($_POST['support_phone'] ?? '')));
        $logoData = trim((string)($_POST['platform_logo_data'] ?? ''));
        $logoUrl = trim((string)($_POST['platform_logo_url'] ?? ''));
        if (isset($_POST['clear_platform_logo'])) {
            $setSetting('platform_logo_url', '');
        } elseif ($logoData !== '' && str_starts_with($logoData, 'data:image/') && strlen($logoData) <= 500 * 1024) {
            $setSetting('platform_logo_url', $logoData);
        } elseif ($logoUrl !== '' && (str_starts_with($logoUrl, 'http://') || str_starts_with($logoUrl, 'https://'))) {
            $setSetting('platform_logo_url', $logoUrl);
        }
        adminAuditLog($pdo, 'config_platform', null, null, []);
        $message = 'Platform settings saved.';
        $messageType = 'success';
    }
}

$plans = $pdo->query(
    'SELECT plan_code, customer_limit, invoices_per_month, can_sync, can_export, can_multi_device, can_advanced_reminders
     FROM plan_settings ORDER BY FIELD(plan_code, \'starter\', \'growth\', \'pro\')'
)->fetchAll();
$planPrices = [];
$ppStmt = $pdo->query("SELECT setting_key, setting_value FROM platform_settings WHERE setting_key IN ('plan_price_growth', 'plan_price_pro')");
while ($row = $ppStmt->fetch()) {
    $planPrices[$row['setting_key']] = $row['setting_value'];
}
$watermarkPlans = array_filter(explode(',', $getSetting('watermark_plans') ?? ''));

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
<p class="muted" style="margin-bottom: 16px;">All mobile app plan features. Customer limit, sync, export, multi-device, reminders, and invoice watermark.</p>
<div class="grid-3">
    <?php foreach ($plans as $plan): ?>
    <?php $hasWatermark = in_array($plan['plan_code'], $watermarkPlans, true); ?>
    <div class="card">
        <div class="card-title"><?= escapeHtml(ucfirst($plan['plan_code'])) ?></div>
        <form method="post">
            <?= csrfField() ?>
            <input type="hidden" name="_action" value="plans">
            <input type="hidden" name="plan_code" value="<?= escapeHtml($plan['plan_code']) ?>">
            <div class="form-group">
                <label>Customer limit</label>
                <input type="number" name="customer_limit" class="form-control" min="1" placeholder="Unlimited"
                    value="<?= $plan['customer_limit'] !== null ? (int)$plan['customer_limit'] : '' ?>">
            </div>
            <div class="form-group">
                <label>Invoices per month</label>
                <input type="number" name="invoices_per_month" class="form-control" min="1" placeholder="Unlimited"
                    value="<?= isset($plan['invoices_per_month']) && $plan['invoices_per_month'] !== null ? (int)$plan['invoices_per_month'] : '' ?>">
                <span class="muted" style="font-size: 12px;">Soft limit. Leave blank for unlimited.</span>
            </div>
            <?php if (in_array($plan['plan_code'], ['growth', 'pro'], true)): ?>
            <div class="form-group">
                <label>Price (NGN/month)</label>
                <input type="number" name="plan_price_ngn" class="form-control" min="0" placeholder="<?= $plan['plan_code'] === 'growth' ? '5000' : '10000' ?>"
                    value="<?= (int)($planPrices['plan_price_' . $plan['plan_code']] ?? ($plan['plan_code'] === 'growth' ? 5000 : 10000)) ?>">
            </div>
            <?php endif; ?>
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
            <div class="form-check">
                <input type="checkbox" name="watermark_invoices" id="watermark_<?= $plan['plan_code'] ?>" <?= $hasWatermark ? 'checked' : '' ?>>
                <label for="watermark_<?= $plan['plan_code'] ?>">Watermark invoices</label>
            </div>
            <button type="submit" class="btn btn-primary btn-sm">Save</button>
        </form>
    </div>
    <?php endforeach; ?>
</div>

<?php elseif ($tab === 'invoice'): ?>
<?php
$currenciesJson = $getSetting('platform_currencies') ?? '';
$currenciesList = [];
if ($currenciesJson !== '') {
    $dec = json_decode($currenciesJson, true);
    if (is_array($dec)) $currenciesList = $dec;
}
if (empty($currenciesList)) {
    $currenciesList = [
        ['code' => 'NGN', 'symbol' => '₦', 'name' => 'Nigerian Naira'],
        ['code' => 'USD', 'symbol' => '$', 'name' => 'US Dollar'],
        ['code' => 'GBP', 'symbol' => '£', 'name' => 'British Pound'],
    ];
}
?>
<div class="card" style="max-width: 640px;">
    <div class="card-title">Invoice defaults</div>
    <p class="muted" style="margin-bottom: 20px;">Default values for new business profiles. Tailors can override these.</p>
    <form method="post">
        <?= csrfField() ?>
        <input type="hidden" name="_action" value="invoice">
        <div class="form-group">
            <label>Default currency</label>
            <select name="currency" class="form-control">
                <?php foreach ($currenciesList as $c): ?>
                <option value="<?= escapeHtml($c['code'] ?? '') ?>" <?= ($getSetting('invoice_default_currency') ?? 'NGN') === ($c['code'] ?? '') ? 'selected' : '' ?>>
                    <?= escapeHtml(($c['code'] ?? '') . ' (' . ($c['symbol'] ?? '') . ') - ' . ($c['name'] ?? '')) ?>
                </option>
                <?php endforeach; ?>
            </select>
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
        <div class="card-title" style="margin-top: 24px;">Platform currencies</div>
        <p class="muted" style="margin-bottom: 12px; font-size: 13px;">Currencies available in the mobile app invoice setup. Add, edit, or remove as needed.</p>
        <div id="currencies-list">
            <?php foreach ($currenciesList as $i => $c): ?>
            <div class="form-row currency-row" style="margin-bottom: 12px; align-items: flex-end;">
                <div class="form-group" style="flex: 0 0 100px;">
                    <label>Code</label>
                    <input type="text" name="currencies[<?= $i ?>][code]" class="form-control" value="<?= escapeHtml($c['code'] ?? '') ?>" placeholder="NGN" maxlength="6">
                </div>
                <div class="form-group" style="flex: 0 0 80px;">
                    <label>Symbol</label>
                    <input type="text" name="currencies[<?= $i ?>][symbol]" class="form-control" value="<?= escapeHtml($c['symbol'] ?? '') ?>" placeholder="₦" maxlength="4">
                </div>
                <div class="form-group" style="flex: 1; min-width: 140px;">
                    <label>Name</label>
                    <input type="text" name="currencies[<?= $i ?>][name]" class="form-control" value="<?= escapeHtml($c['name'] ?? '') ?>" placeholder="Nigerian Naira">
                </div>
                <div class="form-group" style="flex: 0 0 auto;">
                    <button type="button" class="btn btn-secondary btn-sm remove-currency" title="Remove">×</button>
                </div>
            </div>
            <?php endforeach; ?>
        </div>
        <button type="button" id="add-currency" class="btn btn-secondary btn-sm" style="margin-bottom: 20px;">+ Add currency</button>
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
<script>
(function() {
    const list = document.getElementById('currencies-list');
    const addBtn = document.getElementById('add-currency');
    if (!list || !addBtn) return;
    let nextIdx = list.querySelectorAll('.currency-row').length;
    addBtn.addEventListener('click', function() {
        const row = document.createElement('div');
        row.className = 'form-row currency-row';
        row.style.cssText = 'margin-bottom: 12px; align-items: flex-end;';
        row.innerHTML = '<div class="form-group" style="flex: 0 0 100px;"><label>Code</label><input type="text" name="currencies[' + nextIdx + '][code]" class="form-control" placeholder="NGN" maxlength="6"></div>' +
            '<div class="form-group" style="flex: 0 0 80px;"><label>Symbol</label><input type="text" name="currencies[' + nextIdx + '][symbol]" class="form-control" placeholder="₦" maxlength="4"></div>' +
            '<div class="form-group" style="flex: 1; min-width: 140px;"><label>Name</label><input type="text" name="currencies[' + nextIdx + '][name]" class="form-control" placeholder="Currency name"></div>' +
            '<div class="form-group" style="flex: 0 0 auto;"><button type="button" class="btn btn-secondary btn-sm remove-currency" title="Remove">×</button></div>';
        list.appendChild(row);
        nextIdx++;
        row.querySelector('.remove-currency').addEventListener('click', function() { row.remove(); });
    });
    list.querySelectorAll('.remove-currency').forEach(function(btn) {
        btn.addEventListener('click', function() { btn.closest('.currency-row').remove(); });
    });
})();
</script>

<?php elseif ($tab === 'reminders'): ?>
<div class="card" style="max-width: 500px;">
    <div class="card-title">Reminder settings</div>
    <form method="post">
        <?= csrfField() ?>
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
$base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
$base = $base ?: '/';
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
        <?= csrfField() ?>
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
            <?php if ($paystackSecret): ?>
            <div class="form-check">
                <input type="checkbox" name="clear_paystack_secret" id="clear_secret" value="1">
                <label for="clear_secret">Clear key</label>
            </div>
            <?php else: ?><span class="muted" style="font-size: 12px;">Leave blank to keep current</span><?php endif; ?>
        </div>
        <div class="form-group">
            <label>Public key</label>
            <input type="password" name="paystack_public_key" class="form-control" autocomplete="new-password"
                placeholder="<?= $paystackPublic ? $maskSecret($paystackPublic) : 'pk_live_xxxx or pk_test_xxxx' ?>" value="">
            <?php if ($paystackPublic): ?>
            <div class="form-check">
                <input type="checkbox" name="clear_paystack_public" id="clear_public" value="1">
                <label for="clear_public">Clear key</label>
            </div>
            <?php else: ?><span class="muted" style="font-size: 12px;">Leave blank to keep current</span><?php endif; ?>
        </div>
        <?php if ($paystackSecret): ?>
        <div class="form-group">
            <button type="button" id="test-paystack" class="btn btn-secondary">Test connection</button>
            <span id="test-result" class="muted" style="margin-left: 8px;"></span>
        </div>
        <script>
        document.getElementById('test-paystack')?.addEventListener('click', async function() {
            const btn = this;
            const span = document.getElementById('test-result');
            btn.disabled = true;
            span.textContent = 'Testing...';
            try {
                const r = await fetch('<?= $base ?>/test-paystack');
                const d = await r.json();
                span.textContent = d.ok ? '✓ ' + (d.message || 'OK') : '✗ ' + (d.error || 'Failed');
                span.style.color = d.ok ? 'var(--accent)' : 'var(--danger)';
            } catch (e) {
                span.textContent = '✗ Error';
                span.style.color = 'var(--danger)';
            }
            btn.disabled = false;
        });
        </script>
        <?php endif; ?>

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
<?php
$platformUrl = $getSetting('platform_url') ?? 'https://ogatailor.app';
$platformLogo = $getSetting('platform_logo_url');
?>
<div class="card" style="max-width: 560px;">
    <div class="card-title">Platform settings</div>
    <p class="muted" style="margin-bottom: 20px;">Branding and URLs used by the mobile app and platform.</p>
    <form method="post">
        <?= csrfField() ?>
        <input type="hidden" name="_action" value="platform">
        <div class="form-group">
            <label>Platform URL</label>
            <input type="url" name="platform_url" class="form-control"
                value="<?= escapeHtml($platformUrl) ?>" placeholder="https://ogatailor.app">
            <span class="muted" style="font-size: 12px;">Base URL for API and web. Used by mobile app.</span>
        </div>
        <div class="form-group">
            <label>Platform logo</label>
            <p class="muted" style="font-size: 12px; margin-bottom: 8px;">Logo shown in mobile app (URL or upload, max 500KB)</p>
            <?php if ($platformLogo): ?>
            <div class="avatar-preview" style="width: 80px; height: 80px; margin-bottom: 12px;">
                <?php if (str_starts_with($platformLogo, 'data:')): ?>
                <img src="<?= escapeHtml($platformLogo) ?>" alt="Logo">
                <?php else: ?>
                <img src="<?= escapeHtml($platformLogo) ?>" alt="Logo" onerror="this.parentElement.innerHTML='Invalid URL'">
                <?php endif; ?>
            </div>
            <div class="form-check">
                <input type="checkbox" name="clear_platform_logo" id="clear_platform_logo" value="1">
                <label for="clear_platform_logo">Remove logo</label>
            </div>
            <?php endif; ?>
            <input type="url" name="platform_logo_url" id="platform-logo-url" class="form-control" style="margin-top: 8px;"
                value="<?= (!empty($platformLogo) && (str_starts_with($platformLogo, 'http://') || str_starts_with($platformLogo, 'https://'))) ? escapeHtml($platformLogo) : '' ?>"
                placeholder="https://example.com/logo.png">
            <span class="muted" style="font-size: 12px;">Or upload:</span>
            <label class="btn btn-secondary btn-sm" style="margin-top: 8px;">
                Upload image
                <input type="file" accept="image/*" id="platform-logo-input" style="display:none">
            </label>
            <input type="hidden" name="platform_logo_data" id="platform-logo-data" value="">
        </div>
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
<script>
(function() {
    const urlInput = document.getElementById('platform-logo-url');
    const dataInput = document.getElementById('platform-logo-data');
    const fileInput = document.getElementById('platform-logo-input');
    if (fileInput && dataInput) {
        fileInput.addEventListener('change', function(e) {
            const f = e.target.files[0];
            if (!f || !f.type.startsWith('image/')) return;
            const r = new FileReader();
            r.onload = function() {
                const d = r.result;
                if (d.length > 500 * 1024) { alert('Image too large (max 500KB)'); return; }
                dataInput.value = d;
                if (urlInput) urlInput.value = '';
            };
            r.readAsDataURL(f);
        });
    }
    if (urlInput && dataInput) {
        urlInput.addEventListener('input', function() { dataInput.value = ''; });
    }
})();
</script>
<?php endif; ?>

<?php require __DIR__ . '/includes/footer.php'; ?>

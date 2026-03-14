<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
requireAdmin();

$view = $_GET['view'] ?? 'overview';
$validViews = ['overview', 'tailors', 'customers', 'orders', 'payments', 'subscriptions'];
$view = in_array($view, $validViews, true) ? $view : 'overview';

$methodFilter = $_GET['method'] ?? 'all';
$methodFilter = in_array($methodFilter, ['all', 'cash', 'transfer', 'pos', 'card', 'other'], true) ? $methodFilter : 'all';

$period = $_GET['period'] ?? '30';
$dateFrom = trim((string)($_GET['date_from'] ?? ''));
$dateTo = trim((string)($_GET['date_to'] ?? ''));
$customRange = $dateFrom !== '' && $dateTo !== '' && preg_match('/^\d{4}-\d{2}-\d{2}$/', $dateFrom) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $dateTo) && $dateFrom <= $dateTo;
if ($customRange) {
    $since = $dateFrom;
    $until = $dateTo;
    $periodLabel = date('M j', strtotime($dateFrom)) . ' – ' . date('M j', strtotime($dateTo));
} else {
    $period = in_array($period, ['7', '30', '90', 'all'], true) ? $period : '30';
    $days = $period === 'all' ? null : (int)$period;
    $since = $days ? date('Y-m-d', strtotime("-{$days} days")) : null;
    $until = null;
    $periodLabel = $period === 'all' ? 'All time' : "Last {$period} days";
}

$planFilter = $_GET['plan'] ?? 'all';
$planFilter = in_array($planFilter, ['all', 'starter', 'growth', 'pro'], true) ? $planFilter : 'all';

$search = trim((string)($_GET['q'] ?? ''));
$tailorId = trim((string)($_GET['tailor_id'] ?? ''));
$customerId = trim((string)($_GET['customer_id'] ?? ''));

$page = max(1, (int)($_GET['page'] ?? 1));
$perPage = max(10, min(100, (int)($_GET['per'] ?? 20)));
$offset = ($page - 1) * $perPage;

$export = isset($_GET['export']) && $_GET['export'] === 'csv';

$baseParams = ['view' => $view, 'period' => $period, 'plan' => $planFilter, 'q' => $search, 'method' => $methodFilter];
if ($customRange) {
    $baseParams['date_from'] = $dateFrom;
    $baseParams['date_to'] = $dateTo;
}
if ($tailorId) $baseParams['tailor_id'] = $tailorId;
if ($customerId) $baseParams['customer_id'] = $customerId;

$planWhere = $planFilter !== 'all' ? ' AND u.plan_code = :plan' : '';
$planParam = $planFilter !== 'all' ? [':plan' => $planFilter] : [];
$sinceWhere = $since ? ($customRange ? ' AND u.created_at >= :since AND u.created_at <= :until' : ' AND u.created_at >= :since') : '';
$sinceParam = $since ? ($customRange ? [':since' => $since, ':until' => $until . ' 23:59:59'] : [':since' => $since]) : [];
$searchWhere = $search !== '' ? ' AND (u.full_name LIKE :q1 OR u.email LIKE :q1 OR u.business_name LIKE :q1)' : '';
$searchParam = $search !== '' ? [':q1' => '%' . $search . '%'] : [];

$params = array_merge($planParam, $sinceParam, $searchParam);

// Overview stats (platform-wide)
$stmt = $pdo->prepare('SELECT COUNT(*) FROM users u WHERE u.is_guest = 0' . $planWhere . $sinceWhere . $searchWhere);
$stmt->execute($params);
$totalTailors = (int)$stmt->fetchColumn();

$custWhere = $since ? ($customRange ? ' WHERE c.created_at >= :since AND c.created_at <= :until' : ' WHERE c.created_at >= :since') : '';
$custParams = $since ? ($customRange ? [':since' => $since, ':until' => $until . ' 23:59:59'] : [':since' => $since]) : [];
$stmt = $pdo->prepare('SELECT COUNT(*) FROM customers c' . $custWhere);
$stmt->execute($custParams);
$totalCustomers = (int)$stmt->fetchColumn();

$ordWhere = $since ? ($customRange ? ' WHERE o.created_at >= :since AND o.created_at <= :until' : ' WHERE o.created_at >= :since') : '';
$ordParams = $since ? ($customRange ? [':since' => $since, ':until' => $until . ' 23:59:59'] : [':since' => $since]) : [];
$stmt = $pdo->prepare('SELECT COUNT(*) FROM orders o' . $ordWhere);
$stmt->execute($ordParams);
$totalOrders = (int)$stmt->fetchColumn();

$payWhere = $since ? ($customRange ? ' WHERE paid_at >= :since AND paid_at <= :until' : ' WHERE paid_at >= :since') : '';
$payParams = $since ? ($customRange ? [':since' => $since, ':until' => $until . ' 23:59:59'] : [':since' => $since]) : [];
$stmt = $pdo->prepare($since ? 'SELECT COALESCE(SUM(amount), 0) FROM payments' . $payWhere : 'SELECT COALESCE(SUM(amount), 0) FROM payments');
$stmt->execute($payParams);
$totalRevenue = (float)$stmt->fetchColumn();

$usersByPlan = $pdo->query('SELECT plan_code, COUNT(*) AS total FROM users WHERE is_guest = 0 GROUP BY plan_code')->fetchAll();
$orderStatuses = $pdo->query('SELECT status, COUNT(*) AS total FROM orders GROUP BY status')->fetchAll();

// Revenue by day (last 14 days) for chart
$revenueByDay = [];
$revStmt = $pdo->prepare(
    'SELECT DATE(paid_at) AS d, COALESCE(SUM(amount), 0) AS amt FROM payments
     WHERE paid_at >= DATE_SUB(CURDATE(), INTERVAL 14 DAY)
     GROUP BY DATE(paid_at) ORDER BY d'
);
$revStmt->execute();
foreach ($revStmt->fetchAll(PDO::FETCH_KEY_PAIR) as $d => $amt) {
    $revenueByDay[$d] = (float)$amt;
}

// Tailors list (paginated)
$tailors = [];
$tailorsTotal = 0;
if ($view === 'tailors') {
    $sql = 'SELECT u.id, u.full_name, u.email, u.business_name, u.plan_code, u.created_at,
            (SELECT COUNT(*) FROM customers c WHERE c.owner_user_id = u.id) AS cust_count,
            (SELECT COUNT(*) FROM orders o WHERE o.owner_user_id = u.id) AS order_count
            FROM users u WHERE u.is_guest = 0' . $planWhere . $searchWhere . ' ORDER BY u.created_at DESC';
    $countSql = 'SELECT COUNT(*) FROM users u WHERE u.is_guest = 0' . $planWhere . $searchWhere;
    $stmt = $pdo->prepare($countSql);
    $stmt->execute($params);
    $tailorsTotal = (int)$stmt->fetchColumn();
    $limit = $export ? '' : ' LIMIT ' . (int)$perPage . ' OFFSET ' . (int)$offset;
    $stmt = $pdo->prepare($sql . $limit);
    $stmt->execute($params);
    $tailors = $stmt->fetchAll();
    if ($export) {
        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="tailors-' . date('Y-m-d') . '.csv"');
        $out = fopen('php://output', 'w');
        fputcsv($out, ['Name', 'Email', 'Business', 'Plan', 'Customers', 'Orders', 'Joined']);
        foreach ($tailors as $t) {
            fputcsv($out, [$t['full_name'], $t['email'] ?? '', $t['business_name'] ?? '', $t['plan_code'], $t['cust_count'], $t['order_count'], $t['created_at']]);
        }
        fclose($out);
        exit;
    }
}

// Customers list (filter by tailor)
$customers = [];
$customersTotal = 0;
if ($view === 'customers') {
    $custWhere = $tailorId ? 'c.owner_user_id = :tid' : '1=1';
    $custParams = $tailorId ? [':tid' => $tailorId] : [];
    if ($search) {
        $custWhere .= ' AND (c.full_name LIKE :q1 OR c.phone_number LIKE :q1)';
        $custParams[':q1'] = '%' . $search . '%';
    }
    $custSql = "SELECT c.id, c.owner_user_id, c.full_name, c.phone_number, c.created_at, u.full_name AS tailor_name,
                (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.id) AS order_count
                FROM customers c INNER JOIN users u ON u.id = c.owner_user_id WHERE u.is_guest = 0 AND {$custWhere}";
    $countSql = "SELECT COUNT(*) FROM customers c INNER JOIN users u ON u.id = c.owner_user_id WHERE u.is_guest = 0 AND {$custWhere}";
    $stmt = $pdo->prepare($countSql);
    $stmt->execute($custParams);
    $customersTotal = (int)$stmt->fetchColumn();
    $stmt = $pdo->prepare($custSql . ' ORDER BY c.created_at DESC LIMIT ' . (int)$perPage . ' OFFSET ' . (int)$offset);
    $stmt->execute($custParams);
    $customers = $stmt->fetchAll();
    if ($export && $customersTotal > 0) {
        $stmt = $pdo->prepare($custSql . ' ORDER BY c.created_at DESC');
        $stmt->execute($custParams);
        $exportRows = $stmt->fetchAll();
        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="customers-' . date('Y-m-d') . '.csv"');
        $out = fopen('php://output', 'w');
        fputcsv($out, ['Customer', 'Phone', 'Tailor', 'Orders', 'Added']);
        foreach ($exportRows as $c) {
            fputcsv($out, [$c['full_name'], $c['phone_number'] ?? '', $c['tailor_name'] ?? '', $c['order_count'], $c['created_at']]);
        }
        fclose($out);
        exit;
    }
}

// Orders list
$orders = [];
$ordersTotal = 0;
if ($view === 'orders') {
    $ordWhere = '1=1';
    $ordParams = [];
    if ($tailorId) {
        $ordWhere .= ' AND o.owner_user_id = :tid';
        $ordParams[':tid'] = $tailorId;
    }
    if ($customerId) {
        $ordWhere .= ' AND o.customer_id = :cid';
        $ordParams[':cid'] = $customerId;
    }
    if ($search) {
        $ordWhere .= ' AND (o.title LIKE :q1 OR c.full_name LIKE :q1)';
        $ordParams[':q1'] = '%' . $search . '%';
    }
    $ordSql = "SELECT o.id, o.title, o.status, o.amount_total, o.due_date, o.created_at,
               u.full_name AS tailor_name, c.full_name AS customer_name
               FROM orders o INNER JOIN users u ON u.id = o.owner_user_id
               INNER JOIN customers c ON c.id = o.customer_id WHERE {$ordWhere}";
    $countSql = "SELECT COUNT(*) FROM orders o INNER JOIN customers c ON c.id = o.customer_id WHERE {$ordWhere}";
    $stmt = $pdo->prepare($countSql);
    $stmt->execute($ordParams);
    $ordersTotal = (int)$stmt->fetchColumn();
    $stmt = $pdo->prepare($ordSql . ' ORDER BY o.created_at DESC LIMIT ' . (int)$perPage . ' OFFSET ' . (int)$offset);
    $stmt->execute($ordParams);
    $orders = $stmt->fetchAll();
    if ($export && $ordersTotal > 0) {
        $stmt = $pdo->prepare($ordSql . ' ORDER BY o.created_at DESC');
        $stmt->execute($ordParams);
        $exportRows = $stmt->fetchAll();
        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="orders-' . date('Y-m-d') . '.csv"');
        $out = fopen('php://output', 'w');
        fputcsv($out, ['Order', 'Tailor', 'Customer', 'Amount', 'Status', 'Due', 'Created']);
        foreach ($exportRows as $o) {
            fputcsv($out, [$o['title'], $o['tailor_name'], $o['customer_name'], $o['amount_total'], $o['status'], $o['due_date'] ?? '', $o['created_at']]);
        }
        fclose($out);
        exit;
    }
}

// Payments list
$payments = [];
$paymentsTotal = 0;
$paymentsSum = 0.0;
if ($view === 'payments') {
    $payWhere = '1=1';
    $payParams = [];
    if ($tailorId) {
        $payWhere .= ' AND p.owner_user_id = :tid';
        $payParams[':tid'] = $tailorId;
    }
    if ($since) {
        $payWhere .= $customRange ? ' AND p.paid_at >= :since AND p.paid_at <= :until' : ' AND p.paid_at >= :since';
        $payParams[':since'] = $since;
        if ($customRange) $payParams[':until'] = $until . ' 23:59:59';
    }
    if ($methodFilter !== 'all') {
        $payWhere .= ' AND p.method = :method';
        $payParams[':method'] = $methodFilter;
    }
    $paySql = "SELECT p.id, p.amount, p.method, p.reference_code, p.paid_at, u.full_name AS tailor_name, i.invoice_number
               FROM payments p INNER JOIN users u ON u.id = p.owner_user_id
               INNER JOIN invoices i ON i.id = p.invoice_id WHERE {$payWhere}";
    $countSql = "SELECT COUNT(*), COALESCE(SUM(p.amount), 0) FROM payments p WHERE {$payWhere}";
    $stmt = $pdo->prepare($countSql);
    $stmt->execute($payParams);
    $row = $stmt->fetch(PDO::FETCH_NUM);
    $paymentsTotal = (int)$row[0];
    $paymentsSum = (float)$row[1];
    $stmt = $pdo->prepare($paySql . ' ORDER BY p.paid_at DESC LIMIT ' . (int)$perPage . ' OFFSET ' . (int)$offset);
    $stmt->execute($payParams);
    $payments = $stmt->fetchAll();
    if ($export && $paymentsTotal > 0) {
        $stmt = $pdo->prepare($paySql . ' ORDER BY p.paid_at DESC');
        $stmt->execute($payParams);
        $exportRows = $stmt->fetchAll();
        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="payments-' . date('Y-m-d') . '.csv"');
        $out = fopen('php://output', 'w');
        fputcsv($out, ['Tailor', 'Amount', 'Method', 'Reference', 'Invoice', 'Paid at']);
        foreach ($exportRows as $p) {
            fputcsv($out, [$p['tailor_name'] ?? '', $p['amount'], $p['method'], $p['reference_code'] ?? '', $p['invoice_number'] ?? '', $p['paid_at']]);
        }
        fclose($out);
        exit;
    }
}

// Subscriptions list (tailors by plan with expiry)
$subscriptions = [];
$subscriptionsTotal = 0;
if ($view === 'subscriptions') {
    $subWhere = 'u.is_guest = 0';
    $subParams = [];
    if ($planFilter !== 'all') {
        $subWhere .= ' AND u.plan_code = :plan';
        $subParams[':plan'] = $planFilter;
    }
    $subSql = "SELECT u.id, u.full_name, u.email, u.plan_code, u.plan_expires_at, u.created_at,
               (SELECT COUNT(*) FROM customers c WHERE c.owner_user_id = u.id) AS cust_count
               FROM users u WHERE {$subWhere} ORDER BY u.full_name";
    $countSql = "SELECT COUNT(*) FROM users u WHERE {$subWhere}";
    $stmt = $pdo->prepare($countSql);
    $stmt->execute($subParams);
    $subscriptionsTotal = (int)$stmt->fetchColumn();
    $stmt = $pdo->prepare($subSql . ' LIMIT ' . (int)$perPage . ' OFFSET ' . (int)$offset);
    $stmt->execute($subParams);
    $subscriptions = $stmt->fetchAll();
    if ($export && $subscriptionsTotal > 0) {
        $stmt = $pdo->prepare($subSql);
        $stmt->execute($subParams);
        $exportRows = $stmt->fetchAll();
        header('Content-Type: text/csv; charset=utf-8');
        header('Content-Disposition: attachment; filename="subscriptions-' . date('Y-m-d') . '.csv"');
        $out = fopen('php://output', 'w');
        fputcsv($out, ['Tailor', 'Email', 'Plan', 'Expires', 'Customers', 'Joined']);
        foreach ($exportRows as $s) {
            fputcsv($out, [$s['full_name'], $s['email'] ?? '', $s['plan_code'], $s['plan_expires_at'] ?? '', $s['cust_count'], $s['created_at']]);
        }
        fclose($out);
        exit;
    }
}

// Pagination
$totalRows = match ($view) {
    'tailors' => $tailorsTotal,
    'customers' => $customersTotal,
    'orders' => $ordersTotal,
    'payments' => $paymentsTotal,
    'subscriptions' => $subscriptionsTotal,
    default => 0,
};
$totalPages = $totalRows > 0 ? (int)ceil($totalRows / $perPage) : 1;

// Tailor dropdown for customers/orders filter
$tailorsForFilter = $pdo->query('SELECT id, full_name FROM users WHERE is_guest = 0 ORDER BY full_name')->fetchAll();

$pageTitle = 'Reports';
require __DIR__ . '/includes/header.php';
?>

<div class="page-header reports-header">
    <h1>Platform Reports</h1>
    <div class="reports-actions">
        <?php if ($view !== 'overview'): ?>
        <a href="?<?= http_build_query(array_merge($baseParams, ['export' => 'csv'])) ?>" class="btn btn-secondary btn-sm">
            Export CSV
        </a>
        <?php endif; ?>
    </div>
</div>

<div class="reports-filters card">
    <form method="get" class="reports-filter-form">
        <?php if ($tailorId): ?><input type="hidden" name="tailor_id" value="<?= escapeHtml($tailorId) ?>"><?php endif; ?>
        <?php if ($customerId): ?><input type="hidden" name="customer_id" value="<?= escapeHtml($customerId) ?>"><?php endif; ?>
        <div class="filter-row">
            <div class="filter-group">
                <label>View</label>
                <select name="view" onchange="this.form.submit()" class="form-control">
                    <option value="overview" <?= $view === 'overview' ? 'selected' : '' ?>>Overview</option>
                    <option value="tailors" <?= $view === 'tailors' ? 'selected' : '' ?>>Tailors</option>
                    <option value="customers" <?= $view === 'customers' ? 'selected' : '' ?>>Customers</option>
                    <option value="orders" <?= $view === 'orders' ? 'selected' : '' ?>>Orders</option>
                    <option value="payments" <?= $view === 'payments' ? 'selected' : '' ?>>Payments</option>
                    <option value="subscriptions" <?= $view === 'subscriptions' ? 'selected' : '' ?>>Subscriptions</option>
                </select>
            </div>
            <div class="filter-group">
                <label>Period</label>
                <select name="period" onchange="this.form.submit()" class="form-control">
                    <option value="7" <?= !$customRange && $period === '7' ? 'selected' : '' ?>>Last 7 days</option>
                    <option value="30" <?= !$customRange && $period === '30' ? 'selected' : '' ?>>Last 30 days</option>
                    <option value="90" <?= !$customRange && $period === '90' ? 'selected' : '' ?>>Last 90 days</option>
                    <option value="all" <?= !$customRange && $period === 'all' ? 'selected' : '' ?>>All time</option>
                </select>
            </div>
            <div class="filter-group">
                <label>From</label>
                <input type="date" name="date_from" class="form-control" value="<?= escapeHtml($dateFrom) ?>">
            </div>
            <div class="filter-group">
                <label>To</label>
                <input type="date" name="date_to" class="form-control" value="<?= escapeHtml($dateTo) ?>">
            </div>
            <div class="filter-group">
                <label>Plan</label>
                <select name="plan" onchange="this.form.submit()" class="form-control">
                    <option value="all" <?= $planFilter === 'all' ? 'selected' : '' ?>>All plans</option>
                    <option value="starter" <?= $planFilter === 'starter' ? 'selected' : '' ?>>Starter</option>
                    <option value="growth" <?= $planFilter === 'growth' ? 'selected' : '' ?>>Growth</option>
                    <option value="pro" <?= $planFilter === 'pro' ? 'selected' : '' ?>>Pro</option>
                </select>
            </div>
            <?php if (in_array($view, ['customers', 'orders', 'payments'])): ?>
            <div class="filter-group">
                <label>Tailor</label>
                <select name="tailor_id" onchange="this.form.submit()" class="form-control">
                    <option value="">All tailors</option>
                    <?php foreach ($tailorsForFilter as $tf): ?>
                    <option value="<?= escapeHtml($tf['id']) ?>" <?= $tailorId === $tf['id'] ? 'selected' : '' ?>><?= escapeHtml($tf['full_name']) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>
            <?php endif; ?>
            <?php if ($view === 'payments'): ?>
            <div class="filter-group">
                <label>Method</label>
                <select name="method" onchange="this.form.submit()" class="form-control">
                    <option value="all" <?= $methodFilter === 'all' ? 'selected' : '' ?>>All methods</option>
                    <option value="cash" <?= $methodFilter === 'cash' ? 'selected' : '' ?>>Cash</option>
                    <option value="transfer" <?= $methodFilter === 'transfer' ? 'selected' : '' ?>>Transfer</option>
                    <option value="pos" <?= $methodFilter === 'pos' ? 'selected' : '' ?>>POS</option>
                    <option value="card" <?= $methodFilter === 'card' ? 'selected' : '' ?>>Card</option>
                    <option value="other" <?= $methodFilter === 'other' ? 'selected' : '' ?>>Other</option>
                </select>
            </div>
            <?php endif; ?>
            <div class="filter-group filter-search">
                <label>Search</label>
                <input type="text" name="q" class="form-control" value="<?= escapeHtml($search) ?>" placeholder="Search...">
            </div>
            <?php if (in_array($view, ['tailors', 'customers', 'orders', 'payments', 'subscriptions'])): ?>
            <div class="filter-group">
                <label>Per page</label>
                <select name="per" onchange="this.form.submit()" class="form-control">
                    <option value="10" <?= $perPage === 10 ? 'selected' : '' ?>>10</option>
                    <option value="20" <?= $perPage === 20 ? 'selected' : '' ?>>20</option>
                    <option value="50" <?= $perPage === 50 ? 'selected' : '' ?>>50</option>
                    <option value="100" <?= $perPage === 100 ? 'selected' : '' ?>>100</option>
                </select>
            </div>
            <?php endif; ?>
            <div class="filter-group filter-submit">
                <label>&nbsp;</label>
                <button type="submit" class="btn btn-primary">Apply</button>
            </div>
        </div>
    </form>
</div>

<?php if ($view === 'overview'): ?>
<div class="analytics-cards">
    <div class="analytics-card">
        <div class="analytics-icon analytics-icon-users">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
        </div>
        <div class="analytics-content">
            <span class="analytics-value"><?= number_format($totalTailors) ?></span>
            <span class="analytics-label">Tailors</span>
        </div>
    </div>
    <div class="analytics-card">
        <div class="analytics-icon analytics-icon-customers">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
        </div>
        <div class="analytics-content">
            <span class="analytics-value"><?= number_format($totalCustomers) ?></span>
            <span class="analytics-label">Customers</span>
        </div>
    </div>
    <div class="analytics-card">
        <div class="analytics-icon analytics-icon-orders">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>
        </div>
        <div class="analytics-content">
            <span class="analytics-value"><?= number_format($totalOrders) ?></span>
            <span class="analytics-label">Orders</span>
        </div>
    </div>
    <div class="analytics-card">
        <div class="analytics-icon analytics-icon-revenue">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
        </div>
        <div class="analytics-content">
            <span class="analytics-value">₦<?= number_format($totalRevenue, 0) ?></span>
            <span class="analytics-label">Revenue</span>
        </div>
    </div>
</div>

<div class="grid-2">
    <div class="card">
        <div class="card-title">Revenue (last 14 days)</div>
        <div class="activity-chart">
            <?php
            $maxRev = !empty($revenueByDay) ? max($revenueByDay) : 1;
            for ($i = 13; $i >= 0; $i--):
                $d = date('Y-m-d', strtotime("-{$i} days"));
                $amt = $revenueByDay[$d] ?? 0;
                $h = $maxRev > 0 ? round(($amt / $maxRev) * 100) : 0;
            ?>
            <div class="activity-bar" title="<?= date('M j', strtotime($d)) ?>: ₦<?= number_format($amt, 0) ?>">
                <span class="activity-fill" style="height:<?= max($h, 2) ?>%"></span>
            </div>
            <?php endfor; ?>
        </div>
        <div class="activity-labels">
            <?php for ($i = 13; $i >= 0; $i -= 3): ?>
            <span><?= date('M j', strtotime("-{$i} days")) ?></span>
            <?php endfor; ?>
        </div>
    </div>
    <div class="card">
        <div class="card-title">Tailors by plan</div>
        <?php
        $planColors = ['starter' => '#3b82f6', 'growth' => '#10b981', 'pro' => '#8b5cf6'];
        $maxPlan = !empty($usersByPlan) ? max(array_column($usersByPlan, 'total')) : 1;
        foreach ($usersByPlan as $row):
            $pct = $maxPlan > 0 ? round((int)$row['total'] / $maxPlan * 100) : 0;
            $color = $planColors[$row['plan_code']] ?? '#6b7280';
        ?>
        <div class="bar">
            <span><?= escapeHtml(ucfirst($row['plan_code'])) ?></span>
            <span class="bar-fill-wrap"><span class="bar-fill" style="width:<?= $pct ?>%; background:<?= $color ?>"></span></span>
            <span><?= (int)$row['total'] ?></span>
        </div>
        <?php endforeach; ?>
        <?php if (empty($usersByPlan)): ?>
        <p class="muted">No data</p>
        <?php endif; ?>
    </div>
</div>
<div class="grid-2">
    <div class="card">
        <div class="card-title">Order status</div>
        <?php
        $statusColors = ['pending' => '#f59e0b', 'in_progress' => '#3b82f6', 'ready' => '#10b981', 'delivered' => '#8b5cf6', 'cancelled' => '#6b7280'];
        $maxStatus = !empty($orderStatuses) ? max(array_column($orderStatuses, 'total')) : 1;
        foreach ($orderStatuses as $row):
            $pct = $maxStatus > 0 ? round((int)$row['total'] / $maxStatus * 100) : 0;
            $color = $statusColors[$row['status']] ?? '#6b7280';
        ?>
        <div class="bar">
            <span><?= escapeHtml(ucfirst(str_replace('_', ' ', $row['status']))) ?></span>
            <span class="bar-fill-wrap"><span class="bar-fill" style="width:<?= $pct ?>%; background:<?= $color ?>"></span></span>
            <span><?= (int)$row['total'] ?></span>
        </div>
        <?php endforeach; ?>
    </div>
</div>

<?php elseif ($view === 'tailors'): ?>
<div class="card">
    <div class="card-title">Tailors (<?= number_format($tailorsTotal) ?>)</div>
    <div class="table-wrap">
        <table class="data-table">
            <thead>
                <tr>
                    <th>Tailor</th>
                    <th>Plan</th>
                    <th>Customers</th>
                    <th>Orders</th>
                    <th>Joined</th>
                    <th></th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($tailors as $t): ?>
                <tr>
                    <td>
                        <strong><?= escapeHtml($t['full_name']) ?></strong>
                        <?php if (!empty($t['email'])): ?><br><span class="muted" style="font-size:12px;"><?= escapeHtml($t['email']) ?></span><?php endif; ?>
                    </td>
                    <td><span class="pill pill-muted"><?= escapeHtml(ucfirst($t['plan_code'])) ?></span></td>
                    <td><?= (int)$t['cust_count'] ?></td>
                    <td><?= (int)$t['order_count'] ?></td>
                    <td><?= date('M j, Y', strtotime($t['created_at'])) ?></td>
                    <td>
                        <a href="?view=customers&tailor_id=<?= urlencode($t['id']) ?>&plan=<?= escapeHtml($planFilter) ?>" class="btn btn-sm btn-secondary">Customers</a>
                        <a href="?view=orders&tailor_id=<?= urlencode($t['id']) ?>&plan=<?= escapeHtml($planFilter) ?>" class="btn btn-sm btn-secondary">Orders</a>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <?php if (empty($tailors)): ?>
    <p class="muted" style="padding: 24px;">No tailors match the filters.</p>
    <?php else: ?>
    <?php require __DIR__ . '/includes/pagination.php'; ?>
    <?php endif; ?>
</div>

<?php elseif ($view === 'customers'): ?>
<div class="card">
    <div class="card-title">Customers <?= $tailorId ? 'under selected tailor' : '' ?> (<?= number_format($customersTotal) ?>)</div>
    <?php if (!$tailorId): ?>
    <p class="muted" style="padding: 16px;">Select a tailor above to view their customers, or leave as "All tailors" for platform-wide list.</p>
    <?php endif; ?>
    <div class="table-wrap">
        <table class="data-table">
            <thead>
                <tr>
                    <th>Customer</th>
                    <th>Phone</th>
                    <?php if (!$tailorId): ?><th>Tailor</th><?php endif; ?>
                    <th>Orders</th>
                    <th>Added</th>
                    <th></th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($customers as $c): ?>
                <tr>
                    <td><strong><?= escapeHtml($c['full_name']) ?></strong></td>
                    <td><?= escapeHtml($c['phone_number'] ?? '-') ?></td>
                    <?php if (!$tailorId): ?><td><?= escapeHtml($c['tailor_name'] ?? '-') ?></td><?php endif; ?>
                    <td><?= (int)$c['order_count'] ?></td>
                    <td><?= date('M j, Y', strtotime($c['created_at'])) ?></td>
                    <td>
                        <a href="?view=orders&tailor_id=<?= urlencode($c['owner_user_id']) ?>&customer_id=<?= urlencode($c['id']) ?>&plan=<?= escapeHtml($planFilter) ?>" class="btn btn-sm btn-secondary">Orders</a>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <?php if (empty($customers) && $tailorId): ?>
    <p class="muted" style="padding: 24px;">No customers for this tailor.</p>
    <?php elseif (empty($customers)): ?>
    <p class="muted" style="padding: 24px;">No customers match the filters.</p>
    <?php else: ?>
    <?php require __DIR__ . '/includes/pagination.php'; ?>
    <?php endif; ?>
</div>

<?php elseif ($view === 'orders'): ?>
<div class="card">
    <div class="card-title">Orders <?= $customerId ? 'from selected customer' : '' ?> (<?= number_format($ordersTotal) ?>)</div>
    <div class="table-wrap">
        <table class="data-table">
            <thead>
                <tr>
                    <th>Order</th>
                    <th>Tailor</th>
                    <th>Customer</th>
                    <th>Amount</th>
                    <th>Status</th>
                    <th>Due</th>
                    <th>Created</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($orders as $o): ?>
                <tr>
                    <td><strong><?= escapeHtml($o['title']) ?></strong></td>
                    <td><?= escapeHtml($o['tailor_name'] ?? '-') ?></td>
                    <td><?= escapeHtml($o['customer_name'] ?? '-') ?></td>
                    <td>₦<?= number_format((float)$o['amount_total'], 0) ?></td>
                    <td><span class="pill pill-<?= $o['status'] === 'delivered' ? 'success' : ($o['status'] === 'cancelled' ? 'warning' : 'muted') ?>"><?= escapeHtml(ucfirst(str_replace('_', ' ', $o['status']))) ?></span></td>
                    <td><?= $o['due_date'] ? date('M j, Y', strtotime($o['due_date'])) : '-' ?></td>
                    <td><?= date('M j, Y', strtotime($o['created_at'])) ?></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <?php if (empty($orders)): ?>
    <p class="muted" style="padding: 24px;">No orders match the filters.</p>
    <?php else: ?>
    <?php require __DIR__ . '/includes/pagination.php'; ?>
    <?php endif; ?>
</div>

<?php elseif ($view === 'payments'): ?>
<div class="card">
    <div class="card-title">Payments (<?= number_format($paymentsTotal) ?>) — Total: ₦<?= number_format($paymentsSum, 0) ?></div>
    <div class="table-wrap">
        <table class="data-table">
            <thead>
                <tr>
                    <th>Tailor</th>
                    <th>Amount</th>
                    <th>Method</th>
                    <th>Reference</th>
                    <th>Invoice</th>
                    <th>Paid at</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($payments as $p): ?>
                <tr>
                    <td><?= escapeHtml($p['tailor_name'] ?? '-') ?></td>
                    <td><strong>₦<?= number_format((float)$p['amount'], 0) ?></strong></td>
                    <td><span class="pill pill-muted"><?= escapeHtml(ucfirst($p['method'])) ?></span></td>
                    <td><?= escapeHtml($p['reference_code'] ?? '-') ?></td>
                    <td><?= escapeHtml($p['invoice_number'] ?? '-') ?></td>
                    <td><?= date('M j, Y H:i', strtotime($p['paid_at'])) ?></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <?php if (empty($payments)): ?>
    <p class="muted" style="padding: 24px;">No payments match the filters.</p>
    <?php else: ?>
    <?php require __DIR__ . '/includes/pagination.php'; ?>
    <?php endif; ?>
</div>

<?php elseif ($view === 'subscriptions'): ?>
<div class="card">
    <div class="card-title">Subscriptions — Tailors by plan (<?= number_format($subscriptionsTotal) ?>)</div>
    <div class="table-wrap">
        <table class="data-table">
            <thead>
                <tr>
                    <th>Tailor</th>
                    <th>Plan</th>
                    <th>Expires</th>
                    <th>Customers</th>
                    <th>Joined</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($subscriptions as $s): ?>
                <tr>
                    <td>
                        <strong><?= escapeHtml($s['full_name']) ?></strong>
                        <?php if (!empty($s['email'])): ?><br><span class="muted" style="font-size:12px;"><?= escapeHtml($s['email']) ?></span><?php endif; ?>
                    </td>
                    <td><span class="pill pill-muted"><?= escapeHtml(ucfirst($s['plan_code'])) ?></span></td>
                    <td><?= $s['plan_expires_at'] ? date('M j, Y', strtotime($s['plan_expires_at'])) : '<span class="muted">—</span>' ?></td>
                    <td><?= (int)$s['cust_count'] ?></td>
                    <td><?= date('M j, Y', strtotime($s['created_at'])) ?></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <?php if (empty($subscriptions)): ?>
    <p class="muted" style="padding: 24px;">No subscriptions match the filters.</p>
    <?php else: ?>
    <?php require __DIR__ . '/includes/pagination.php'; ?>
    <?php endif; ?>
</div>
<?php endif; ?>

<?php require __DIR__ . '/includes/footer.php'; ?>

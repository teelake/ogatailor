<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
requireAdmin();

$period = $_GET['period'] ?? '30';
$days = in_array($period, ['7', '30', '90', 'all'], true) ? $period : '30';
$since = $days === 'all' ? null : date('Y-m-d', strtotime('-' . (int)$days . ' days'));
$prevSince = $days === 'all' ? null : date('Y-m-d', strtotime('-' . ((int)$days * 2) . ' days'));
$prevUntil = $since; // previous period ends where current starts

$upcomingLimit = max(1, min(30, (int)($_GET['upcoming_limit'] ?? 8)));

function countWhere(PDO $pdo, string $table, string $dateCol, ?string $since, string $extraWhere = ''): int {
    $where = $extraWhere;
    if ($since !== null) {
        $where .= ($where ? ' AND ' : '') . "{$dateCol} >= :since";
    }
    $sql = 'SELECT COUNT(*) FROM ' . $table . ($where ? ' WHERE ' . $where : '');
    $stmt = $since ? $pdo->prepare($sql) : $pdo->query($sql);
    if ($since) $stmt->execute([':since' => $since]);
    return (int)$stmt->fetchColumn();
}

// Current period totals
$usersTotal = $days === 'all' ? (int)$pdo->query('SELECT COUNT(*) FROM users WHERE is_guest = 0')->fetchColumn() : countWhere($pdo, 'users', 'created_at', $since, 'is_guest = 0');
$customersTotal = $days === 'all' ? (int)$pdo->query('SELECT COUNT(*) FROM customers')->fetchColumn() : countWhere($pdo, 'customers', 'created_at', $since);
$ordersTotal = $days === 'all' ? (int)$pdo->query('SELECT COUNT(*) FROM orders')->fetchColumn() : countWhere($pdo, 'orders', 'created_at', $since);
$invoicesTotal = $days === 'all' ? (int)$pdo->query('SELECT COUNT(*) FROM invoices')->fetchColumn() : countWhere($pdo, 'invoices', 'created_at', $since);

$revenueStmt = $pdo->prepare($since
    ? 'SELECT COALESCE(SUM(amount), 0) FROM payments WHERE paid_at >= :since'
    : 'SELECT COALESCE(SUM(amount), 0) FROM payments');
if ($since) $revenueStmt->execute([':since' => $since]);
else $revenueStmt->execute();
$revenueTotal = (float)$revenueStmt->fetchColumn();

$invoicedStmt = $pdo->prepare($since
    ? 'SELECT COALESCE(SUM(total_amount), 0) FROM invoices WHERE created_at >= :since AND status != \'draft\''
    : 'SELECT COALESCE(SUM(total_amount), 0) FROM invoices WHERE status != \'draft\'');
if ($since) $invoicedStmt->execute([':since' => $since]);
else $invoicedStmt->execute();
$invoicedTotal = (float)$invoicedStmt->fetchColumn();

// Previous period for growth (same-length period before current)
$usersPrev = 0;
$customersPrev = 0;
$ordersPrev = 0;
if ($prevSince && $prevUntil) {
    $stmt = $pdo->prepare('SELECT COUNT(*) FROM users WHERE is_guest = 0 AND created_at >= :since AND created_at < :until');
    $stmt->execute([':since' => $prevSince, ':until' => $prevUntil]);
    $usersPrev = (int)$stmt->fetchColumn();
    $stmt = $pdo->prepare('SELECT COUNT(*) FROM customers WHERE created_at >= :since AND created_at < :until');
    $stmt->execute([':since' => $prevSince, ':until' => $prevUntil]);
    $customersPrev = (int)$stmt->fetchColumn();
    $stmt = $pdo->prepare('SELECT COUNT(*) FROM orders WHERE created_at >= :since AND created_at < :until');
    $stmt->execute([':since' => $prevSince, ':until' => $prevUntil]);
    $ordersPrev = (int)$stmt->fetchColumn();
    $stmt = $pdo->prepare('SELECT COALESCE(SUM(amount), 0) FROM payments WHERE paid_at >= :since AND paid_at < :until');
    $stmt->execute([':since' => $prevSince, ':until' => $prevUntil]);
    $revenuePrev = (float)$stmt->fetchColumn();
} else {
    $revenuePrev = 0.0;
}

$growth = function ($curr, $prev) {
    if ($prev <= 0) return $curr > 0 ? 100 : 0;
    return round((($curr - $prev) / $prev) * 100);
};

// All-time totals for overview
$userCountAll = (int)$pdo->query('SELECT COUNT(*) FROM users WHERE is_guest = 0')->fetchColumn();
$customerCountAll = (int)$pdo->query('SELECT COUNT(*) FROM customers')->fetchColumn();
$orderCountAll = (int)$pdo->query('SELECT COUNT(*) FROM orders')->fetchColumn();
$invoiceCountAll = (int)$pdo->query('SELECT COUNT(*) FROM invoices')->fetchColumn();
$revenueAll = (float)$pdo->query('SELECT COALESCE(SUM(amount), 0) FROM payments')->fetchColumn();

$orderStatuses = $pdo->query('SELECT status, COUNT(*) AS total FROM orders GROUP BY status')->fetchAll();
$usersByPlan = $pdo->query('SELECT plan_code, COUNT(*) AS total FROM users WHERE is_guest = 0 GROUP BY plan_code')->fetchAll();

// Activity over time (last 14 days)
$activityStmt = $pdo->prepare(
    'SELECT DATE(created_at) AS d, COUNT(*) AS cnt FROM orders
     WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 14 DAY)
     GROUP BY DATE(created_at) ORDER BY d'
);
$activityStmt->execute();
$activityByDay = $activityStmt->fetchAll(PDO::FETCH_KEY_PAIR);

// Top tailors by customers
$topTailors = $pdo->query(
    'SELECT u.id, u.full_name, u.email, u.plan_code,
            (SELECT COUNT(*) FROM customers c WHERE c.owner_user_id = u.id) AS cust_count,
            (SELECT COUNT(*) FROM orders o WHERE o.owner_user_id = u.id) AS order_count
     FROM users u WHERE u.is_guest = 0
     ORDER BY cust_count DESC LIMIT 10'
)->fetchAll();

$upcomingStmt = $pdo->prepare(
    'SELECT o.id, o.title, o.amount_total, c.full_name AS customer_name, o.due_date, o.status
     FROM orders o INNER JOIN customers c ON c.id = o.customer_id
     WHERE o.due_date IS NOT NULL AND o.status NOT IN (\'delivered\', \'cancelled\')
     ORDER BY o.due_date ASC LIMIT :limit_rows'
);
$upcomingStmt->bindValue(':limit_rows', $upcomingLimit, PDO::PARAM_INT);
$upcomingStmt->execute();
$upcomingOrders = $upcomingStmt->fetchAll();

$periodLabel = $days === 'all' ? 'All time' : "Last {$days} days";
$base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
$base = $base ?: '/';
$pageTitle = 'Platform Dashboard';
require __DIR__ . '/includes/header.php';
?>

<div class="page-header">
    <h1>Platform Dashboard</h1>
    <form method="get" class="inline-form">
        <select name="period" onchange="this.form.submit()">
            <option value="7" <?= $period === '7' ? 'selected' : '' ?>>Last 7 days</option>
            <option value="30" <?= $period === '30' ? 'selected' : '' ?>>Last 30 days</option>
            <option value="90" <?= $period === '90' ? 'selected' : '' ?>>Last 90 days</option>
            <option value="all" <?= $period === 'all' ? 'selected' : '' ?>>All time</option>
        </select>
    </form>
</div>

<div class="dashboard-hero analytics-cards">
    <div class="analytics-card">
        <div class="analytics-icon analytics-icon-users">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
        </div>
        <div class="analytics-content">
            <span class="analytics-value"><?= number_format($userCountAll) ?></span>
            <span class="analytics-label">Total tailors</span>
        </div>
    </div>
    <div class="analytics-card">
        <div class="analytics-icon analytics-icon-customers">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
        </div>
        <div class="analytics-content">
            <span class="analytics-value"><?= number_format($customerCountAll) ?></span>
            <span class="analytics-label">Total customers</span>
        </div>
    </div>
    <div class="analytics-card">
        <div class="analytics-icon analytics-icon-orders">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>
        </div>
        <div class="analytics-content">
            <span class="analytics-value"><?= number_format($orderCountAll) ?></span>
            <span class="analytics-label">Total orders</span>
        </div>
    </div>
    <div class="analytics-card">
        <div class="analytics-icon analytics-icon-revenue">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
        </div>
        <div class="analytics-content">
            <span class="analytics-value">₦<?= number_format($revenueAll, 2) ?></span>
            <span class="analytics-label">Total revenue</span>
        </div>
    </div>
</div>

<div class="card" style="margin-bottom: 24px;">
    <div class="card-title"><?= escapeHtml($periodLabel) ?> — Key metrics</div>
    <div class="stats-grid stats-grid-icons">
        <div class="stat-card">
            <div class="stat-icon stat-icon-users"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg></div>
            <span class="stat-label">New tailors</span>
            <span class="stat-value"><?= $usersTotal ?></span>
            <?php if ($prevSince && $usersPrev > 0): ?>
            <span class="stat-delta <?= $growth($usersTotal, $usersPrev) >= 0 ? 'positive' : 'negative' ?>">
                <?= $growth($usersTotal, $usersPrev) >= 0 ? '+' : '' ?><?= $growth($usersTotal, $usersPrev) ?>% vs prev
            </span>
            <?php endif; ?>
        </div>
        <div class="stat-card">
            <div class="stat-icon stat-icon-customers"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg></div>
            <span class="stat-label">New customers</span>
            <span class="stat-value"><?= $customersTotal ?></span>
            <?php if ($prevSince && $customersPrev > 0): ?>
            <span class="stat-delta <?= $growth($customersTotal, $customersPrev) >= 0 ? 'positive' : 'negative' ?>">
                <?= $growth($customersTotal, $customersPrev) >= 0 ? '+' : '' ?><?= $growth($customersTotal, $customersPrev) ?>% vs prev
            </span>
            <?php endif; ?>
        </div>
        <div class="stat-card">
            <div class="stat-icon stat-icon-orders"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg></div>
            <span class="stat-label">New orders</span>
            <span class="stat-value"><?= $ordersTotal ?></span>
            <?php if ($prevSince && $ordersPrev > 0): ?>
            <span class="stat-delta <?= $growth($ordersTotal, $ordersPrev) >= 0 ? 'positive' : 'negative' ?>">
                <?= $growth($ordersTotal, $ordersPrev) >= 0 ? '+' : '' ?><?= $growth($ordersTotal, $ordersPrev) ?>% vs prev
            </span>
            <?php endif; ?>
        </div>
        <div class="stat-card">
            <div class="stat-icon stat-icon-invoices"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg></div>
            <span class="stat-label">Invoices</span>
            <span class="stat-value"><?= $invoicesTotal ?></span>
        </div>
        <div class="stat-card">
            <div class="stat-icon stat-icon-revenue"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg></div>
            <span class="stat-label">Revenue</span>
            <span class="stat-value">₦<?= number_format($revenueTotal, 2) ?></span>
            <?php if ($prevSince && $revenuePrev > 0): ?>
            <span class="stat-delta <?= $growth($revenueTotal, $revenuePrev) >= 0 ? 'positive' : 'negative' ?>">
                <?= $growth($revenueTotal, $revenuePrev) >= 0 ? '+' : '' ?><?= $growth($revenueTotal, $revenuePrev) ?>% vs prev
            </span>
            <?php endif; ?>
        </div>
    </div>
</div>

<div class="grid-2">
    <div class="card">
        <div class="card-title">Order status (all time)</div>
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
        <?php if (empty($orderStatuses)): ?>
        <p class="muted">No orders yet</p>
        <?php endif; ?>
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
        <div class="card-title">Orders per day (last 14 days)</div>
        <div class="activity-chart">
            <?php
            $maxAct = !empty($activityByDay) ? max($activityByDay) : 1;
            for ($i = 13; $i >= 0; $i--):
                $d = date('Y-m-d', strtotime("-{$i} days"));
                $cnt = (int)($activityByDay[$d] ?? 0);
                $h = $maxAct > 0 ? round(($cnt / $maxAct) * 100) : 0;
            ?>
            <div class="activity-bar" title="<?= date('M j', strtotime($d)) ?>: <?= $cnt ?> orders">
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
        <div class="card-title">Upcoming due orders</div>
        <form method="get" class="inline-form" style="margin-bottom:12px;">
            <input type="hidden" name="period" value="<?= escapeHtml($period) ?>">
            <select name="upcoming_limit" onchange="this.form.submit()">
                <option value="8" <?= $upcomingLimit === 8 ? 'selected' : '' ?>>8</option>
                <option value="12" <?= $upcomingLimit === 12 ? 'selected' : '' ?>>12</option>
                <option value="20" <?= $upcomingLimit === 20 ? 'selected' : '' ?>>20</option>
            </select>
        </form>
        <ul class="upcoming-list">
            <?php foreach ($upcomingOrders as $o): ?>
            <li>
                <strong><?= escapeHtml($o['title'] ?? 'Order') ?></strong> — <?= escapeHtml($o['customer_name'] ?? '-') ?>
                <span class="pill pill-success"><?= escapeHtml($o['status'] ?? 'pending') ?></span>
                <?php if (!empty($o['amount_total'])): ?><span class="muted">₦<?= number_format((float)$o['amount_total'], 2) ?></span><?php endif; ?>
                (due <?= $o['due_date'] ? date('M j, Y', strtotime($o['due_date'])) : '-' ?>)
            </li>
            <?php endforeach; ?>
        </ul>
        <?php if (empty($upcomingOrders)): ?>
        <p class="muted">No upcoming due orders</p>
        <?php endif; ?>
    </div>
</div>

<div class="card">
    <div class="card-title">Top tailors by customers</div>
    <div class="table-wrap">
        <table class="data-table">
            <thead>
                <tr>
                    <th>Tailor</th>
                    <th>Plan</th>
                    <th>Customers</th>
                    <th>Orders</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($topTailors as $t): ?>
                <tr>
                    <td>
                        <strong><?= escapeHtml($t['full_name']) ?></strong>
                        <?php if (!empty($t['email'])): ?><br><span class="muted" style="font-size:12px;"><?= escapeHtml($t['email']) ?></span><?php endif; ?>
                        <br><a href="<?= $base ?>/reports?view=customers&tailor_id=<?= urlencode((string)($t['id'] ?? '')) ?>" class="muted" style="font-size:12px;">View in Reports →</a>
                    </td>
                    <td><span class="pill pill-muted"><?= escapeHtml(ucfirst($t['plan_code'])) ?></span></td>
                    <td><?= (int)$t['cust_count'] ?></td>
                    <td><?= (int)$t['order_count'] ?></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<?php require __DIR__ . '/includes/footer.php'; ?>

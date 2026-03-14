<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
requireAdmin();

$period = $_GET['period'] ?? '30';
$days = in_array($period, ['7', '30', '90'], true) ? (int)$period : 30;
$since = date('Y-m-d', strtotime("-{$days} days"));

$userStats = $pdo->prepare(
    'SELECT plan_code, COUNT(*) AS total FROM users WHERE is_guest = 0 AND created_at >= :since GROUP BY plan_code'
);
$userStats->execute([':since' => $since]);
$usersByPlan = $userStats->fetchAll();

$stmt = $pdo->prepare('SELECT COUNT(*) FROM users WHERE is_guest = 0 AND created_at >= :since');
$stmt->execute([':since' => $since]);
$newUsers = (int)$stmt->fetchColumn();

$stmt = $pdo->prepare('SELECT COUNT(*) FROM customers WHERE created_at >= :since');
$stmt->execute([':since' => $since]);
$newCustomers = (int)$stmt->fetchColumn();

$stmt = $pdo->prepare('SELECT COUNT(*) FROM orders WHERE created_at >= :since');
$stmt->execute([':since' => $since]);
$newOrders = (int)$stmt->fetchColumn();

$orderStatuses = $pdo->query(
    'SELECT status, COUNT(*) AS total FROM orders GROUP BY status'
)->fetchAll();

$stmt = $pdo->prepare(
    'SELECT u.id, u.full_name, u.email, u.plan_code, u.created_at
     FROM users u WHERE u.is_guest = 0 ORDER BY u.created_at DESC LIMIT 10'
);
$stmt->execute();
$recentUsers = $stmt->fetchAll();

$pageTitle = 'Reports';
require __DIR__ . '/includes/header.php';
?>

<div class="page-header">
    <h1>Reports</h1>
    <form method="get" class="inline-form">
        <select name="period" onchange="this.form.submit()">
            <option value="7" <?= $period === '7' ? 'selected' : '' ?>>Last 7 days</option>
            <option value="30" <?= $period === '30' ? 'selected' : '' ?>>Last 30 days</option>
            <option value="90" <?= $period === '90' ? 'selected' : '' ?>>Last 90 days</option>
        </select>
    </form>
</div>

<div class="stats-grid">
    <div class="stat-card">
        <span class="stat-label">New users (<?= $days ?>d)</span>
        <span class="stat-value"><?= $newUsers ?></span>
    </div>
    <div class="stat-card">
        <span class="stat-label">New customers (<?= $days ?>d)</span>
        <span class="stat-value"><?= $newCustomers ?></span>
    </div>
    <div class="stat-card">
        <span class="stat-label">New orders (<?= $days ?>d)</span>
        <span class="stat-value"><?= $newOrders ?></span>
    </div>
</div>

<div class="grid-2">
    <div class="card">
        <div class="card-title">Users by plan</div>
        <?php
        $maxPlan = !empty($usersByPlan) ? max(array_column($usersByPlan, 'total')) : 1;
        foreach ($usersByPlan as $row):
            $pct = $maxPlan > 0 ? round((int)$row['total'] / $maxPlan * 100) : 0;
        ?>
        <div class="bar">
            <span><?= escapeHtml(ucfirst($row['plan_code'])) ?></span>
            <span class="bar-fill-wrap"><span class="bar-fill" style="width:<?= $pct ?>%"></span></span>
            <span><?= (int)$row['total'] ?></span>
        </div>
        <?php endforeach; ?>
        <?php if (empty($usersByPlan)): ?>
        <p class="muted">No data</p>
        <?php endif; ?>
    </div>

    <div class="card">
        <div class="card-title">Order status breakdown</div>
        <?php
        $maxStatus = !empty($orderStatuses) ? max(array_column($orderStatuses, 'total')) : 1;
        foreach ($orderStatuses as $row):
            $pct = $maxStatus > 0 ? round((int)$row['total'] / $maxStatus * 100) : 0;
        ?>
        <div class="bar">
            <span><?= escapeHtml(ucfirst(str_replace('_', ' ', $row['status']))) ?></span>
            <span class="bar-fill-wrap"><span class="bar-fill" style="width:<?= $pct ?>%"></span></span>
            <span><?= (int)$row['total'] ?></span>
        </div>
        <?php endforeach; ?>
    </div>
</div>

<div class="card">
    <div class="card-title">Recent users</div>
    <div class="table-wrap">
        <table class="data-table">
            <thead>
                <tr>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Plan</th>
                    <th>Joined</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($recentUsers as $u): ?>
                <tr>
                    <td><?= escapeHtml($u['full_name']) ?></td>
                    <td><?= escapeHtml($u['email'] ?? '-') ?></td>
                    <td><span class="pill pill-muted"><?= escapeHtml(ucfirst($u['plan_code'])) ?></span></td>
                    <td><?= date('M j, Y', strtotime($u['created_at'])) ?></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</div>

<?php require __DIR__ . '/includes/footer.php'; ?>

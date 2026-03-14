<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
requireAdmin();

$upcomingLimit = max(1, min(30, (int)($_GET['upcoming_limit'] ?? 8)));

$userCount = (int)$pdo->query('SELECT COUNT(*) FROM users WHERE is_guest = 0')->fetchColumn();
$customerCount = (int)$pdo->query('SELECT COUNT(*) FROM customers')->fetchColumn();
$measurementCount = (int)$pdo->query('SELECT COUNT(*) FROM measurements')->fetchColumn();
$orderCount = (int)$pdo->query('SELECT COUNT(*) FROM orders')->fetchColumn();

$orderStatuses = $pdo->query(
    'SELECT status, COUNT(*) AS total FROM orders GROUP BY status'
)->fetchAll();

$upcomingStmt = $pdo->prepare(
    'SELECT o.id, o.title, c.full_name AS customer_name, o.due_date, o.status
     FROM orders o
     INNER JOIN customers c ON c.id = o.customer_id
     WHERE o.due_date IS NOT NULL
       AND o.status NOT IN (\'delivered\', \'cancelled\')
     ORDER BY o.due_date ASC
     LIMIT :limit_rows'
);
$upcomingStmt->bindValue(':limit_rows', $upcomingLimit, PDO::PARAM_INT);
$upcomingStmt->execute();
$upcomingOrders = $upcomingStmt->fetchAll();

$pageTitle = 'Overview';
require __DIR__ . '/includes/header.php';
?>

<header class="topbar">
    <h2>Overview</h2>
</header>

<div class="stats-grid">
    <article class="stat-card">
        <span class="stat-label">Users</span>
        <span class="stat-value"><?= $userCount ?></span>
    </article>
    <article class="stat-card">
        <span class="stat-label">Customers</span>
        <span class="stat-value"><?= $customerCount ?></span>
    </article>
    <article class="stat-card">
        <span class="stat-label">Measurements</span>
        <span class="stat-value"><?= $measurementCount ?></span>
    </article>
    <article class="stat-card">
        <span class="stat-label">Orders</span>
        <span class="stat-value"><?= $orderCount ?></span>
    </article>
</div>

<div class="cards-grid">
    <article class="card">
        <h3>Order Status Breakdown</h3>
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
        <?php if (empty($orderStatuses)): ?>
        <p class="muted">No orders yet</p>
        <?php endif; ?>
    </article>
    <article class="card">
        <div class="card-header">
            <h3>Upcoming Due Orders</h3>
            <form method="get" class="inline-form">
                <select name="upcoming_limit" onchange="this.form.submit()">
                    <option value="8" <?= $upcomingLimit === 8 ? 'selected' : '' ?>>8</option>
                    <option value="12" <?= $upcomingLimit === 12 ? 'selected' : '' ?>>12</option>
                    <option value="20" <?= $upcomingLimit === 20 ? 'selected' : '' ?>>20</option>
                </select>
            </form>
        </div>
        <ul class="upcoming-list">
            <?php foreach ($upcomingOrders as $o): ?>
            <li>
                <strong><?= escapeHtml($o['title'] ?? 'Order') ?></strong> — <?= escapeHtml($o['customer_name'] ?? '-') ?>
                <span class="pill"><?= escapeHtml($o['status'] ?? 'pending') ?></span>
                (due <?= $o['due_date'] ? date('M j, Y', strtotime($o['due_date'])) : '-' ?>)
            </li>
            <?php endforeach; ?>
        </ul>
        <?php if (empty($upcomingOrders)): ?>
        <p class="muted">No upcoming due orders</p>
        <?php endif; ?>
    </article>
</div>

<?php require __DIR__ . '/includes/footer.php'; ?>

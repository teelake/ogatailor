<?php

declare(strict_types=1);

require_once __DIR__ . '/config.php';
requireAdmin();

$page = max(1, (int)($_GET['page'] ?? 1));
$perPage = max(10, min(100, (int)($_GET['per'] ?? 50)));
$offset = ($page - 1) * $perPage;

$stmt = $pdo->prepare(
    'SELECT l.id, l.action, l.entity_type, l.entity_id, l.details, l.created_at, a.full_name AS admin_name
     FROM admin_audit_log l
     LEFT JOIN admin_users a ON a.id = l.admin_user_id
     ORDER BY l.created_at DESC
     LIMIT ' . (int)$perPage . ' OFFSET ' . (int)$offset
);
$stmt->execute();
$logs = $stmt->fetchAll();

$total = (int)$pdo->query('SELECT COUNT(*) FROM admin_audit_log')->fetchColumn();
$totalPages = $total > 0 ? (int)ceil($total / $perPage) : 1;
$baseParams = ['page' => 1, 'per' => $perPage];
$base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
$base = $base ?: '/';

$breadcrumbs = '<a href="' . $base . '/">Overview</a> <span>›</span> Audit log';
$pageTitle = 'Audit log';
require __DIR__ . '/includes/header.php';
?>

<div class="page-header">
    <h1>Audit log</h1>
</div>

<div class="card">
    <div class="card-title">Recent actions (<?= number_format($total) ?> total)</div>
    <div class="table-wrap">
        <table class="data-table">
            <thead>
                <tr>
                    <th>When</th>
                    <th>Admin</th>
                    <th>Action</th>
                    <th>Details</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($logs as $log): ?>
                <tr>
                    <td><?= date('M j, Y H:i', strtotime($log['created_at'])) ?></td>
                    <td><?= escapeHtml($log['admin_name'] ?? 'System') ?></td>
                    <td><span class="pill pill-muted"><?= escapeHtml(str_replace('_', ' ', $log['action'])) ?></span></td>
                    <td><?php
                    $d = $log['details'] ? json_decode($log['details'], true) : null;
                    if ($d && is_array($d)) {
                        echo escapeHtml(implode(', ', array_map(fn($k, $v) => "{$k}: {$v}", array_keys($d), $d)));
                    } else {
                        echo $log['entity_type'] ? escapeHtml($log['entity_type'] . ' ' . ($log['entity_id'] ?? '')) : '—';
                    }
                    ?></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <?php if (empty($logs)): ?>
    <p class="muted" style="padding: 24px;">No audit entries yet.</p>
    <?php else: ?>
    <div class="pagination">
        <span class="pagination-info"><?= number_format($total) ?> total · Page <?= $page ?> of <?= $totalPages ?></span>
        <div class="pagination-links">
            <?php if ($page > 1): ?>
            <a href="?<?= http_build_query(array_merge($baseParams, ['page' => $page - 1])) ?>" class="btn btn-sm btn-secondary">Prev</a>
            <?php endif; ?>
            <?php if ($page < $totalPages): ?>
            <a href="?<?= http_build_query(array_merge($baseParams, ['page' => $page + 1])) ?>" class="btn btn-sm btn-secondary">Next</a>
            <?php endif; ?>
        </div>
    </div>
    <?php endif; ?>
</div>

<?php require __DIR__ . '/includes/footer.php'; ?>

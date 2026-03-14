<?php
$pagParams = array_merge($baseParams, ['per' => $perPage]);
$pagParams['page'] = 1;
$baseUrl = '?' . http_build_query($pagParams);
?>
<div class="pagination">
    <span class="pagination-info"><?= number_format($totalRows) ?> total · Page <?= $page ?> of <?= $totalPages ?></span>
    <div class="pagination-links">
        <?php if ($page > 1): ?>
        <a href="<?= $baseUrl ?>" class="btn btn-sm btn-secondary">First</a>
        <a href="?<?= http_build_query(array_merge($pagParams, ['page' => $page - 1])) ?>" class="btn btn-sm btn-secondary">Prev</a>
        <?php endif; ?>
        <?php
        $start = max(1, $page - 2);
        $end = min($totalPages, $page + 2);
        for ($i = $start; $i <= $end; $i++):
        ?>
        <a href="?<?= http_build_query(array_merge($pagParams, ['page' => $i])) ?>" class="btn btn-sm <?= $i === $page ? 'btn-primary' : 'btn-secondary' ?>"><?= $i ?></a>
        <?php endfor; ?>
        <?php if ($page < $totalPages): ?>
        <a href="?<?= http_build_query(array_merge($pagParams, ['page' => $page + 1])) ?>" class="btn btn-sm btn-secondary">Next</a>
        <a href="?<?= http_build_query(array_merge($pagParams, ['page' => $totalPages])) ?>" class="btn btn-sm btn-secondary">Last</a>
        <?php endif; ?>
    </div>
</div>

<?php
$admin = adminUser();
$base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
$base = $base ?: '/';
$path = trim(parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH), '/');
$segments = $path ? explode('/', $path) : [];
$last = end($segments);
$currentPage = ($last === false || $last === '' || $last === 'dashboard') ? 'index' : preg_replace('/\.php$/', '', $last);
$navItems = [
    'Overview' => ['', '◉'],
    'Reports' => ['reports', '▣'],
    'Configuration' => ['configuration', '◇'],
    'Admins' => ['admins', '◎'],
    'Profile' => ['profile', '●'],
];
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Oga Tailor Admin<?= isset($pageTitle) ? ' - ' . escapeHtml($pageTitle) : '' ?></title>
    <link rel="icon" type="image/svg+xml" href="<?= $base ?>/favicon.svg">
    <link rel="stylesheet" href="<?= $base ?>/style.css">
</head>
<body>
<div class="app">
    <aside class="sidebar">
        <div class="sidebar-brand">Oga Tailor</div>
        <nav class="sidebar-nav">
            <div class="nav-section">Main</div>
            <?php foreach ($navItems as $label => [$url, $icon]): ?>
            <a href="<?= $base . ($url ? '/' . $url : '') ?>" class="nav-item <?= $currentPage === ($url ?: 'index') ? 'active' : '' ?>">
                <span class="icon"><?= $icon ?></span>
                <?= escapeHtml($label) ?>
            </a>
            <?php endforeach; ?>
        </nav>
        <div class="sidebar-footer">
            <div class="admin-profile">
                <?php if (!empty($admin['profile_picture'])): ?>
                <div class="admin-avatar"><img src="<?= escapeHtml($admin['profile_picture']) ?>" alt=""></div>
                <?php else: ?>
                <div class="admin-avatar"><?= strtoupper(substr($admin['full_name'] ?? 'A', 0, 1)) ?></div>
                <?php endif; ?>
                <div class="admin-info">
                    <div class="admin-name"><?= escapeHtml($admin['full_name'] ?? '') ?></div>
                    <div class="admin-email"><?= escapeHtml($admin['email'] ?? '') ?></div>
                </div>
            </div>
            <a href="<?= $base ?>/logout" class="btn-logout">Sign out</a>
        </div>
    </aside>
    <main class="main-content">
    <?php if (!empty($breadcrumbs)): ?>
    <nav class="breadcrumbs"><?= $breadcrumbs ?></nav>
    <?php endif; ?>

<?php
$admin = adminUser();
$base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
$base = $base ?: '/';
$current = basename($_SERVER['SCRIPT_NAME'] ?? 'index.php');
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Oga Tailor Admin<?= isset($pageTitle) ? ' - ' . escapeHtml($pageTitle) : '' ?></title>
    <link rel="stylesheet" href="<?= $base ?>/style.css">
</head>
<body>
    <div class="app">
        <aside class="sidebar">
            <div class="sidebar-brand">Oga Tailor</div>
            <nav class="sidebar-nav">
                <a href="index.php" class="nav-item <?= $current === 'index.php' ? 'active' : '' ?>">Overview</a>
                <a href="plans.php" class="nav-item <?= $current === 'plans.php' ? 'active' : '' ?>">Plans</a>
            </nav>
            <div class="sidebar-footer">
                <span class="admin-email"><?= escapeHtml($admin['email'] ?? '') ?></span>
                <a href="logout.php" class="btn-logout">Sign out</a>
            </div>
        </aside>
        <main class="main-content">

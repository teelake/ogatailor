<?php
http_response_code(404);
$base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? ''), '/');
$base = $base ?: '/';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>404 - Oga Tailor Admin</title>
    <link rel="stylesheet" href="<?= $base ?>/style.css">
    <style>
        .error-404 { text-align: center; padding: 80px 24px; }
        .error-404 h1 { font-size: 72px; color: var(--text-dim); margin-bottom: 16px; }
        .error-404 p { color: var(--text-muted); margin-bottom: 24px; }
    </style>
</head>
<body class="login-page">
    <div class="error-404">
        <h1>404</h1>
        <p>Page not found</p>
        <a href="<?= $base ?>/" class="btn btn-primary">Go to dashboard</a>
    </div>
</body>
</html>

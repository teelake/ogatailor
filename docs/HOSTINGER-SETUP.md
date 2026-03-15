# Hostinger Deployment Troubleshooting

## "Server is currently unavailable. Please try again."

This message appears when the API returns **HTTP 5xx** (500, 502, 503). Common causes on Hostinger:

### 1. Database credentials (most common)

The error `Access denied for user 'root'@'127.0.0.1' (using password: NO)` means `.env` is missing or has wrong values.

**Fix:**
1. In hPanel → **Databases** → **MySQL Databases**, note your database name, username, and password.
2. Create or edit `backend/.env` on the server:

```env
APP_ENV=production
APP_DEBUG=false
APP_BASE_PATH=oga-tailor

DB_HOST=localhost
DB_PORT=3306
DB_NAME=u232647434_oga_tailor
DB_USER=u232647434_oga_user
DB_PASS=your_actual_password
AUTH_TOKEN_TTL_DAYS=30
```

Replace with your actual Hostinger MySQL credentials. Hostinger typically uses `localhost` (not 127.0.0.1) and usernames like `uXXXXXX_dbuser`.

### 2. PDO MySQL extension

If you see `could not find driver`:
1. hPanel → **Advanced** → **PHP Configuration**
2. Enable **pdo_mysql** extension
3. Use PHP 8.0 or 8.1

### 3. Verify the API

**Health check (no database required):**
```
https://webspace.ng/oga-tailor/
```
or
```
https://webspace.ng/oga-tailor/api/health
```
Should return: `{"status":"ok","service":"oga-tailor-api"}`

**Debug request (see how paths are parsed):**
```
https://webspace.ng/oga-tailor/api/debug/request
```

### 4. Check error logs

- **Hostinger:** hPanel → **Files** → **Error Logs**
- **App logs:** `backend/storage/logs/php-error.log`
- **Dashboard logs:** Same as above (dashboard uses backend)

### 5. File structure on server

Ensure your Hostinger `public_html` (or domain folder) has:

```
oga-tailor/
├── .htaccess
├── index.php
├── backend/
│   ├── .env          ← Must exist with correct DB credentials
│   ├── bootstrap.php
│   ├── public/
│   │   └── index.php
│   └── storage/
│       └── logs/     ← Writable
├── dashboard/
│   ├── config.php
│   └── ...
```

### 6. .htaccess for subdirectory

If the app is at `webspace.ng/oga-tailor/`, the root `.htaccess` should have `RewriteBase /oga-tailor/`. This is already set.

### 7. APP_BASE_PATH

If the API base URL is `https://webspace.ng/oga-tailor`, set in `backend/.env`:
```
APP_BASE_PATH=oga-tailor
```

This helps the backend strip the subpath correctly from request URIs.

### 8. Plan upgrade (Paystack) – "Could not start payment"

For plan upgrades to work, you need:

1. **Paystack secret key** – Dashboard → Configuration → API settings → enter your Paystack **Secret Key** (starts with `sk_live_` or `sk_test_`).

2. **APP_URL** in `backend/.env` – Must match your site URL:
   ```
   APP_URL=https://webspace.ng/oga-tailor
   ```
   (No trailing slash.) Paystack uses this for the callback URL.

3. **User email** – The user must have an email in their profile (Profile → Edit → Email). Paystack requires it for payment.

4. **Plan prices** – Dashboard → Configuration → Plan prices. Set Growth and Pro prices.

If you see "Payment is not configured yet" – the Paystack secret key is missing in the dashboard.

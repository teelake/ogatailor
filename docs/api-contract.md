# API Contract (MVP v1)

Base URL: `https://your-domain.com/api`

## Authentication

- Protected endpoints require: `Authorization: Bearer <token>`
- Obtain token from:
  - `POST /api/auth/guest-start`
  - `POST /api/auth/register`
  - `POST /api/auth/login`

## Health

- `GET /health`

## Config (public)

- `GET /api/config`
  - returns platform branding for mobile app:
    - `platform_url` (string) – base URL for API/web
    - `platform_logo_url` (string|null) – logo URL or base64 data URI

## Auth (Guest-First)

- `POST /api/auth/guest-start`
  - body:
    - `device_id` (string, required)
    - `device_name` (string, optional)
  - returns guest `user_id` + `token`
- `POST /api/auth/register`
  - body:
    - `full_name` (string, required)
    - `phone_number` (string, required, numeric, exactly 11 digits)
    - `email` (string, required)
    - `password` (string, required)
    - `business_name` (string, optional) – brand/business name
    - `guest_user_id` (string UUID, optional for guest upgrade)
  - if `guest_user_id` is provided, guest data owner is upgraded in place
- `POST /api/auth/login`
  - body:
    - `email`
    - `password`
- `GET /api/auth/profile` (protected)
- `PATCH /api/auth/profile` (protected)
  - body:
    - `full_name`
    - `email`
    - `phone_number` (required, numeric, exactly 11 digits)
    - `business_name` (string, optional)
- `POST /api/auth/change-password` (protected)
  - body:
    - `current_password`
    - `new_password`
- `POST /api/auth/logout` (protected)
  - revokes current bearer token session
- `POST /api/auth/logout-all` (protected)
  - revokes all sessions for the current account
- `POST /api/auth/forgot-password`
  - body:
    - `email`
- `POST /api/auth/reset-password`
  - body:
    - `email`
    - `reset_code`
    - `new_password`

## Customers

- `POST /api/customers`
  - body:
    - `full_name` (string) – stored with first letter of each word capitalized
    - `gender` (`male|female|other`)
    - `phone_number` (string, optional)
    - `notes` (string, optional)
  - returns 409 if a customer with the same name exists (duplicates blocked):
    - `error`: `"duplicate_name"`
    - `message`: human-readable message
    - `existing_customer_id`: UUID of the existing customer
- `GET /api/customers`
  - query params (optional):
    - `limit` (default 50, max 200)
    - `offset` (default 0)
    - `q` (search by name/phone)
    - `starts_with` (single letter `a-z`, filters by customer name prefix)
  - response includes:
    - `meta.total`
    - `meta.limit`
    - `meta.offset`
    - `meta.has_more`
- `PATCH /api/customers`
  - body:
    - `customer_id`
    - `full_name` – stored with first letter of each word capitalized
    - `gender`
    - `phone_number` (optional)
    - `notes` (optional)
    - `client_last_modified_at` (optional; ISO datetime for conflict detection)
  - returns 409 if another customer has the same name (duplicates blocked)
- `POST /api/customers/archive`
  - body:
    - `customer_id`
    - `archived` (boolean)
- `DELETE /api/customers`
  - body:
    - `customer_id`

## Measurements

- `POST /api/measurements`
  - body:
    - `customer_id` (string UUID)
    - `taken_at` (ISO datetime)
    - `payload` (object JSON)
- `GET /api/measurements?customer_id={uuid}`
- `PATCH /api/measurements`
  - body:
    - `measurement_id`
    - `taken_at`
    - `payload` (object)
    - `client_last_modified_at` (optional; ISO datetime for conflict detection)

## Orders (Phase 2.2)

- `POST /api/orders`
  - body:
    - `customer_id`
    - `title`
    - `status` (`pending|in_progress|ready|delivered|cancelled`)
    - `amount_total`
    - `due_date` (optional)
    - `notes` (optional)
- `GET /api/orders`
- `PATCH /api/orders/status`
  - body:
    - `order_id`
    - `status`
    - `client_last_modified_at` (optional; ISO datetime for conflict detection)
- `PATCH /api/orders/due-date`
  - body:
    - `order_id`
    - `due_date` (nullable)
    - `client_last_modified_at` (optional; ISO datetime for conflict detection)

## Business Profile (Invoice Setup)

- `GET /api/business-profile` (protected)
  - returns 404 if invoice setup not completed
- `PATCH /api/business-profile` (protected)
  - body:
    - `business_name` (string, required)
    - `business_phone` (string, optional)
    - `business_email` (string, optional)
    - `business_address` (string, optional)
    - `cac_registered` (boolean)
    - `cac_registration_type` (`company`|`business`, required if cac_registered)
    - `cac_number` (string, BN/RC prefix + digits, required if cac_registered)
    - `vat_enabled` (boolean)
    - `default_vat_rate` (number, 0–100 when vat_enabled)
    - `currency` (string, default NGN)
    - `payment_terms` (string, optional)
    - `logo_data` (string, optional) – base64-encoded logo. PNG/JPEG/WEBP, max 500KB, 64–512px. Null to remove.

## Invoices

- `POST /api/invoices/generate` (protected)
  - body: `order_id` (required)
  - requires business profile (invoice setup) completed
  - returns 200 if invoice already exists for order
  - returns 403 if plan invoice limit reached (e.g. `error`: "Invoice limit reached (25/month). Upgrade to Growth or Pro for more.")
- `GET /api/invoices/by-order?order_id={uuid}` (protected)
  - returns full invoice data for PDF/image generation

## Reminders (Daily Digest)

- `POST /api/reminders/daily-digest/subscribe` (protected, Growth/Pro only)
- `POST /api/reminders/daily-digest/unsubscribe` (protected)
- `GET /api/reminders/daily-digest/status` (protected)
- `GET /api/reminders/send-digests?secret={CRON_SECRET}` (cron; no auth)
  - Sends daily email digest to subscribed users. Schedule via cron (e.g. 8:00 AM daily).

## Plan Summary

- `GET /api/plan/summary` (protected)
  - returns: `plan_code`, `plan_expires_at`, `customer_count`, `customer_limit`, `invoices_used_this_month`, `invoices_per_month`, `features` (can_sync, can_export, etc.)

## Diagnostics and Export

- `GET /api/diagnostics` (protected)
- `GET /api/export/measurements` (Growth/Pro only)
  - query params (all optional):
    - `customer_id`
    - `start_date` (`YYYY-MM-DD`)
    - `end_date` (`YYYY-MM-DD`)
- `GET /api/admin/dashboard` (protected)
  - query params:
    - `upcoming_limit` (optional, 1-30, default 8)
- `GET /api/admin/plans` (protected)
  - returns current plan feature configuration
- `PATCH /api/admin/plans` (protected)
  - body:
    - `plan_code` (`starter|growth|pro`, required)
    - `customer_limit` (int or null)
    - `invoices_per_month` (int or null) – soft limit per month; null = unlimited
    - `can_sync` (bool)
    - `can_export` (bool)
    - `can_multi_device` (bool)
    - `can_advanced_reminders` (bool)

## Sync (Draft)

- `POST /api/sync/push`
  - uploads pending offline changes from device queue
- `GET /api/sync/pull?user_id={uuid}&since={cursor}`
  - pulls changed entities since cursor
  - Growth/Pro plan only

## Upcoming Endpoints (Phase 2+)

- Orders
  - `POST /api/orders`
  - `GET /api/orders?owner_user_id={uuid}`
- Invoices
  - `POST /api/invoices`
  - `GET /api/invoices?owner_user_id={uuid}`
- Payments
  - `POST /api/payments`
  - `GET /api/payments?owner_user_id={uuid}`
- Business Records
  - `POST /api/business-records`
  - `GET /api/business-records?owner_user_id={uuid}`

## Plan Rules

- Starter (free):
  - max 50 customers
  - no cloud backup or multi-device sync
  - guest mode allowed (offline-first onboarding)
- Growth:
  - max 500 customers
  - cloud backup + restore + export
- Pro:
  - unlimited customers
  - cloud backup + restore + multi-device + export

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

## Plan Summary

- `GET /api/plan/summary`

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

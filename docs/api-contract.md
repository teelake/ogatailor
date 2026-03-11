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
- `POST /api/auth/change-password` (protected)
  - body:
    - `current_password`
    - `new_password`
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
- `PATCH /api/customers`
  - body:
    - `customer_id`
    - `full_name` – stored with first letter of each word capitalized
    - `gender`
    - `phone_number` (optional)
    - `notes` (optional)
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

## Orders (Phase 2.2)

- `POST /api/orders`
  - body:
    - `owner_user_id`
    - `customer_id`
    - `title`
    - `status` (`pending|in_progress|ready|delivered|cancelled`)
    - `amount_total`
    - `due_date` (optional)
    - `notes` (optional)
- `GET /api/orders?owner_user_id={uuid}`
- `PATCH /api/orders/status`
  - body:
    - `owner_user_id`
    - `order_id`
    - `status`
- `PATCH /api/orders/due-date`
  - body:
    - `owner_user_id`
    - `order_id`
    - `due_date` (nullable)

## Plan Summary

- `GET /api/plan/summary`

## Diagnostics and Export

- `GET /api/diagnostics` (protected)
- `GET /api/export/measurements` (paid only)

## Sync (Draft)

- `POST /api/sync/push`
  - uploads pending offline changes from device queue
- `GET /api/sync/pull?user_id={uuid}&since={cursor}`
  - pulls changed entities since cursor
  - paid plan only

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

- Free plan:
  - max 100 customers
  - no cloud backup or multi-device sync
  - guest mode allowed (offline-first onboarding)
- Paid plan:
  - unlimited customers
  - cloud backup + restore + multi-device + export

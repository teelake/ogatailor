# API Contract (MVP v1)

Base URL: `https://your-domain.com/api`

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

## Customers

- `POST /api/customers`
  - body:
    - `owner_user_id` (string UUID)
    - `full_name` (string)
    - `phone_number` (string, optional)
- `GET /api/customers?owner_user_id={uuid}`

## Measurements

- `POST /api/measurements`
  - body:
    - `customer_id` (string UUID)
    - `taken_at` (ISO datetime)
    - `payload` (object JSON)
- `GET /api/measurements?customer_id={uuid}`

## Sync (Draft)

- `POST /api/sync/push`
  - uploads pending offline changes from device queue
- `GET /api/sync/pull?user_id={uuid}&since={cursor}`
  - pulls changed entities since cursor

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

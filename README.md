# Oga Tailor MVP

Offline-first customer measurement management for seamstresses, tailors, and fashion designers.

## Stack

- Mobile: Flutter (scaffold files added in `mobile/`)
- Backend API: PHP 8+ (OOP) + PDO
- Database: MySQL 8+

## Modules (Roadmap)

- Customers
- Measurements
- Orders
- Billing
- Payments
- Invoices
- Business records

## Pricing Model

- Free: offline mode, up to 100 customers
- Paid: cloud backup, restore to new phone, unlimited customers, export, multi-device

## Project Structure

- `backend/` - PHP API and domain code
- `database/` - SQL schema and seed scripts
- `docs/` - API and architecture notes
- `mobile/` - Flutter app codebase (theme + customers MVP screen)

## Quick Start (Backend)

1. Create MySQL database: `oga_tailor`
2. Run `database/schema.sql`
3. Configure `backend/.env`
4. Start PHP dev server from `backend/public`

## Notes

- IDs are UUID-based for offline sync and future scale.
- Phone numbers are not primary identifiers.
- Sync model is API-driven (`push` and `pull`) with server-side conflict checks.
- Auth model is guest-first (instant use), then upgrade to account for cloud features.
- **Sync timing**: Local data syncs to server on app launch and every 5 minutes while the app is open.
- **Measurements**: Gender-specific fields including Head/Cap (Fila), neck, shoulder, chest, waist, hip, sleeve, armhole, lengths, inseam, thigh, knee, plus female-specific bust, under bust, blouse/gown/skirt lengths.

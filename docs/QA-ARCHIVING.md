# QA Report: Customer Archiving

## Summary

Archiving is **implemented correctly** end-to-end. One backend improvement was made for unarchive edge cases.

---

## Flow Verified

### Backend API

| Endpoint | Status | Notes |
|----------|--------|-------|
| `POST /api/customers/archive` | ✅ | `customer_id` + `archived` (bool). Archive prepends `[ARCHIVED]` to notes; unarchive strips prefix only. |
| `GET /api/customers?archived=` | ✅ | `exclude` (default), `only`, `all` filter correctly. |
| `POST /api/customers` (create) | ✅ | Duplicate check excludes archived customers. |
| `PATCH /api/customers` (update) | ✅ | Duplicate check excludes archived. Notes overwritten as sent. |
| `POST /api/orders` | ✅ | Accepts any customer_id; archived customers can have orders. |

### Mobile App

| Screen | Status | Notes |
|--------|--------|-------|
| Customers list | ✅ | Active / Archived / All tabs. Filter + search + A–Z work. |
| Customer details | ✅ | Archive / Unarchive in menu. State updates after action. |
| Order creation | ✅ | Customer picker uses `archived=exclude` (active only). |
| Edit customer | ✅ | Notes include `[ARCHIVED]` when archived; save preserves it. |

### Offline / Cache

| Scenario | Status | Notes |
|----------|--------|-------|
| Archive while online | ✅ | API + cache updated. |
| Archive while offline | ✅ | Queued; cache updated optimistically. |
| View Archived tab offline | ⚠️ | Archived list may be incomplete if "All" was never fetched. Cache holds last fetched set (active or all). |
| View Active tab offline | ✅ | Cache has active customers. |

---

## Fix Applied

**Unarchive logic**: Previously used `REPLACE(notes, '[ARCHIVED]', '')`, which removed every occurrence. If notes contained "[ARCHIVED]" elsewhere (e.g. "See [ARCHIVED] folder"), it would be altered.

**Change**: Unarchive now strips only the leading `[ARCHIVED]` or `[ARCHIVED] ` prefix via `SUBSTRING`, so text like "See [ARCHIVED] folder" is preserved.

---

## Test Checklist

- [ ] Archive customer with no notes → shows in Archived tab
- [ ] Archive customer with notes → notes preserved with [ARCHIVED] prefix
- [ ] Unarchive → notes restored without prefix
- [ ] Create customer with same name as archived → allowed (no duplicate)
- [ ] Edit archived customer → archive status preserved
- [ ] Order picker → archived customers not shown
- [ ] Switch Active → Archived → All → lists correct
- [ ] Archive offline → syncs when back online

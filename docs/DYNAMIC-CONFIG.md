# Dynamic vs Static Configuration

## Now Dynamic (from backend/database)

| Item | Source | Where configured |
|------|--------|------------------|
| **Plan details** | `plan_settings` + `platform_settings` (prices) | Dashboard → Configuration → Plans |
| **Currencies** | `platform_settings.platform_currencies` (JSON) | Dashboard → Configuration → Invoice defaults |
| **Invoice defaults** | `platform_settings` | Dashboard → Configuration → Invoice defaults |
| **Logo constraints** | `platform_settings` | Dashboard → Configuration → Invoice defaults |
| **Platform URL, logo, support** | `platform_settings` | Dashboard → Configuration → Platform |
| **Paystack keys** | `platform_settings` | Dashboard → Configuration → Integrations |

## Still Static (by design)

| Item | Reason |
|------|--------|
| Gender options (male, female, other) | Standard enum, rarely changes |
| Order statuses (pending, in_progress, etc.) | Core workflow, defined in schema |
| A–Z filter for customers | UI convenience, not config |
| Logo validation MIME types | Security, fixed set |
| Reminder day offsets (14, 7, 3, 1, 0) | Plan-based, from plan_settings |

## Currencies

Admin can manage the list of currencies in **Dashboard → Configuration → Invoice defaults**:

- **Code** (e.g. NGN, USD)
- **Symbol** (e.g. ₦, $)
- **Name** (e.g. Nigerian Naira)

The mobile app fetches this list from `/api/config` and uses it for the invoice setup currency dropdown and for displaying currency symbols in invoice preview/PDF.

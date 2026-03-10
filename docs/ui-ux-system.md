# UI/UX System (Mobile MVP)

## Design Goals

- Premium but practical
- Fast entry for tailors during busy work
- High readability for customer and measurement records
- Low cognitive load in low-network environments

## Color Tokens

- Primary: `#0F766E`
- Primary Dark: `#115E59`
- Premium Accent: `#D4A017`
- Background: `#F8FAFC`
- Surface: `#FFFFFF`
- Text Primary: `#0F172A`
- Text Secondary: `#475569`
- Border: `#E2E8F0`
- Success: `#16A34A`
- Warning: `#F59E0B`
- Error: `#DC2626`

## Typography

- Page title: 24 / bold
- Section title: 18 / semibold
- Item title: 16 / semibold
- Body: 14 / regular
- Helper text: 12 / regular

## Spacing Scale

- `4, 8, 12, 16, 20, 24, 32`

## Core Components

- AppBar with plan badge
- Search input with filter action
- Customer card tile
- Primary filled button for create/save
- Empty state with one clear CTA

## UX Rules

- Do not block offline flows behind network checks.
- Save locally first; sync in background.
- Never overwrite historical measurements; append snapshots.
- Keep destructive actions behind explicit confirmation.
- Show sync status at top level without interrupting core tasks.

# SpendLog — Quotation Prompt

Copy everything below the line into ChatGPT, Claude, Gemini or any other
assistant to have it draft a price quotation for SpendLog. Fill the
`[brackets]` first. The work breakdown was written from the modules that exist
in the code, so every line item maps to something real that can be delivered
and demonstrated.

Pair this with `proposal-prompt.md`: the proposal explains *what and why*, the
quotation states *how much and on what terms*.

---

## Prompt

You are helping me prepare a formal **price quotation** for building and
delivering **SpendLog**, a personal expense tracking system with a Laravel
backend, a web admin panel, and a Flutter app for Android, iOS, Linux, macOS,
Windows and web. Use only the facts and figures I give below. Never invent a
price, rate, date or duration; where I have not given one, keep the
`[placeholder]` visible so I can fill it.

### Parties and terms

- Supplier: `[your name or company]`, `[address]`, `[email / phone]`, `[tax ID if any]`
- Client: `[client name]`, `[address]`, `[contact person]`
- Quotation number: `[SL-YYYY-NNN]`
- Date: `[date]`
- Valid until: `[date, e.g. 30 days from issue]`
- Currency: `[USD / KHR]`
- Pricing model: `[fixed price per module / hourly at [rate] per hour / day rate at [rate]]`
- Payment terms: `[e.g. 40% on signing, 30% on staging demo, 30% on delivery]`
- Payment method: `[bank transfer / ABA / Wing / other]`
- Tax: `[VAT 10% included / excluded / not applicable]`
- Delivery: `[e.g. source code in a private Git repository, deployed to client's server, app store builds]`
- Warranty: `[e.g. 30 days of bug fixes after acceptance at no charge]`
- Support after warranty: `[monthly retainer at [amount] / hourly at [rate] / none]`

### What is being quoted

SpendLog is already designed and largely built. This quotation covers
`[choose one: the full build from scratch / delivery, customisation and
deployment of the existing system / a licence to the existing system plus
setup]`. State this clearly in the introduction so the client knows whether
they are paying for new development or for an existing product.

### Work breakdown (line items)

Each module below exists in the codebase. Quote each as its own line with
`[hours]` and a subtotal, or as a fixed `[price]`, using the pricing model
above. Group them under the headings shown.

**A. Backend and API (Laravel 13, PHP 8.3)**

| # | Item | What it includes | Effort |
|---|------|------------------|--------|
| A1 | Project setup and authentication | Laravel install, database, Sanctum token auth with per-token abilities, roles and permissions (user, admin, super-admin), login, register, forgot and reset password, Google sign-in on web | `[hours]` |
| A2 | Categories | Admin-managed categories with colour and icon, ownership policies, CRUD endpoints | `[hours]` |
| A3 | Expenses | CRUD with ownership checks, search, category and date-range filters, pagination, USD and KHR with admin-set exchange rate | `[hours]` |
| A4 | Budgets | Overall and per-category monthly budgets, upsert per user/category/month, spent-versus-budget summary | `[hours]` |
| A5 | Dashboard endpoint | Today's total, month total and remaining, category breakdown, recent expenses | `[hours]` |
| A6 | Reports and export | Period stats, time series, category breakdown; PDF, Excel and CSV export | `[hours]` |
| A7 | Workouts module | Exercise types, workouts with sets (reps, weight kg/lb, cardio duration), monthly summary, muscle split, personal records | `[hours]` |
| A8 | Admin endpoints | User management, app settings (exchange rate, default weight unit), FAQ management | `[hours]` |
| A9 | Profile endpoints | Update name, username, email; change password | `[hours]` |
| A10 | Automated tests and audit fixes | Regression tests for the reproduced bugs, policy and ability tests | `[hours]` |

**B. Web application and admin panel (Vue 3, Inertia, shadcn-vue)**

| # | Item | What it includes | Effort |
|---|------|------------------|--------|
| B1 | Auth pages and layout | Login, register, password reset, responsive shell with admin badge | `[hours]` |
| B2 | Expenses, categories, budgets pages | Daily-grouped list, quick-add modal, colour and icon picker, budget progress bars | `[hours]` |
| B3 | Dashboard page | Totals, category bars, budget progress, recent list | `[hours]` |
| B4 | Admin pages | Users, settings, FAQ, view all users' expenses with per-user filter | `[hours]` |
| B5 | Polish | Empty states, loading skeletons, toasts, mobile check at 390 px | `[hours]` |

**C. Cross-platform app (Flutter, Dart)**

| # | Item | What it includes | Effort |
|---|------|------------------|--------|
| C1 | App foundation | Riverpod state, go_router five-tab shell, Dio client with token interceptor and auto sign-out, secure token storage, light/dark/system theme | `[hours]` |
| C2 | Auth screens | Splash with session restore, sign in, forgot password, reset password | `[hours]` |
| C3 | Dashboard | Month stepper, this-month and today cards, trend chart (week/month/year/all), category breakdown, recent expenses | `[hours]` |
| C4 | Expenses | Search, category and date filters, infinite scroll, add/edit bottom sheet, long-press delete, USD/KHR toggle | `[hours]` |
| C5 | Budgets | Overall card, per-category rows with progress, set-budget sheet with currency toggle | `[hours]` |
| C6 | Reports | Period picker, stats, chart, breakdown, export to PDF/Excel/CSV via system share sheet | `[hours]` |
| C7 | Profile and settings | Grouped settings list, edit profile and change password sheets, appearance picker, sign out | `[hours]` |
| C8 | Categories and workouts screens | Category management, workout log with set editor and monthly summary | `[hours]` |
| C9 | Admin screens | Users list and form, app settings, FAQ editor | `[hours]` |
| C10 | Glassmorphism design system | Gradient ground, translucent panes, frosted nav bar and sheets, pill controls, shared widgets | `[hours]` |
| C11 | Platform builds | Android APK/AAB, iOS build, Linux, macOS and Windows desktop targets, web build | `[hours]` |

**D. Deployment and handover**

| # | Item | What it includes | Effort |
|---|------|------------------|--------|
| D1 | Server deployment | `[client's VPS / shared host]`, database, HTTPS, environment config, backups | `[hours]` |
| D2 | App store publishing | Google Play and Apple App Store listings and submission (store fees excluded) | `[hours]` |
| D3 | Documentation | API reference (exists as `docs/API.md`), admin guide, user guide | `[hours]` |
| D4 | Training and handover | `[N]` sessions with the client team, source code transfer | `[hours]` |

**E. Optional items (quote separately, not in the base total)**

| # | Item | Effort |
|---|------|--------|
| E1 | Offline queue with sync | `[hours]` |
| E2 | Recurring expenses and reminders | `[hours]` |
| E3 | Receipt photo attachment and OCR | `[hours]` |
| E4 | Shared households (several users on one budget) | `[hours]` |
| E5 | Bank or e-wallet import (ABA, Wing, Bakong) subject to API availability | `[hours]` |
| E6 | Push notifications for budget limits | `[hours]` |
| E7 | Khmer localisation | `[hours]` |
| E8 | Home-screen quick-add widgets | `[hours]` |

### Third-party and recurring costs (pass-through, not supplier fees)

- Server hosting: `[provider, amount per month]`
- Domain and SSL: `[amount per year]`
- Apple Developer Program: `[USD 99 per year]`
- Google Play developer registration: `[USD 25 one-time]`
- Email delivery service for password resets: `[provider, amount]`

### Assumptions and exclusions

- The client provides server access, domain, app store accounts and branding
  assets (logo, colours) within `[N]` days of signing.
- Content such as FAQ text and default categories is supplied by the client.
- Changes to scope after signing are quoted separately as change requests.
- Store review delays by Apple or Google are outside the supplier's control.
- `[Add any others.]`

### What I want you to produce

Write a complete quotation document with these sections, in this order:

1. Header: supplier and client details, quotation number, date, validity.
2. Introduction: one short paragraph stating what is being quoted and whether
   it is new development or delivery of an existing system.
3. Scope summary: three or four bullets.
4. Itemised pricing: reproduce the tables in sections A to D with columns for
   item, description, effort, rate and subtotal. Show a subtotal per group.
5. Optional items (section E) in a separate table, clearly marked as not
   included in the total.
6. Third-party and recurring costs as a separate list.
7. Totals: subtotal, tax line, grand total. Use placeholders if any figure is
   missing; do not calculate with invented numbers.
8. Payment schedule tied to milestones.
9. Delivery timeline with `[dates]` placeholders per milestone.
10. Assumptions and exclusions.
11. Warranty and support.
12. Acceptance: signature lines for both parties with name, title and date.

Rules:

- Keep every `[placeholder]` visible where I have not supplied a value.
- Do not add features that are not in the tables above.
- Use plain, professional language; no marketing adjectives.
- Output in Markdown with tables, ready to paste into Word or Google Docs.

---

## After you get the draft

- Fill the effort or price for every line. If you quote hourly, multiply and
  check the subtotals yourself; do not trust the assistant's arithmetic.
- Delete rows the client is not buying, for example the Workouts module or the
  desktop targets.
- Attach the proposal from `proposal-prompt.md` as the companion document.

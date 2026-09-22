# SpendLog features

What the product does, by area. Written against the API routes, the permission
set and all three clients, so it describes what is built rather than what is
planned.

SpendLog is one Laravel API with four faces: this Flutter app, an Expo /
React Native app, an Inertia/Vue web app, and the JSON API itself. Unless a
line says otherwise, a feature is on all of them.

> The same list is kept in the API repo, at `spendlog/docs/FEATURES.md`.
> Edit both, or neither.

## Auth

1. Register, login, logout — token-based, tokens named per device
2. Forgot and reset password, including a six-digit code path
3. Profile: name, username, email, phone, avatar upload
4. Roles — `super_admin`, `admin`, `user`
5. 40 granular permissions, with per-user overrides on top of the role
6. Token abilities, so a client can be read-only whatever the user may do

## Dashboard

1. Today's spend
2. The month against its budget, month-steppable
3. Category breakdown with each category's share
4. Income for the month, and balance — income less spent
5. Savings card, plan and all-time balance
6. Recent expenses

## Expenses

1. Add, edit, delete
2. Search by text
3. Filter by category and by date range
4. Searchable category picker
5. Inline "new category" while adding a one-off row

## Income

1. Add, edit, delete
2. Monthly summary split by source, largest first
3. Source picker that also takes a name it has never seen

## Income sources

1. A managed catalogue — add, rename, remove
2. A rename optionally rewrites the income filed under the old name
3. Names typed into an income or a savings deposit join the catalogue
4. Usage count and total against each name

## Categories

1. Add, edit, delete — admin only
2. A colour and an icon per category
3. In-use protection: a category an expense or budget points at cannot go

## Budgets

1. A budget per category per month
2. An overall monthly budget beside them
3. Spent, remaining and percent against each
4. Status — `ok`, `warning`, `over`

## Savings

1. A savings plan per month
2. A deposit and withdrawal ledger
3. Headroom: a withdrawal spends the plan's unfilled part before it touches
   the deposits, so $100 put against a $150 plan and $80 taken back out
   leaves $70
4. An all-time balance that carries between months
5. Overdraw protection — never more out than is held, checked under a lock
6. A history tab: the activity log, filtered to savings

## Borrowing

1. Debts, with a lender and a lender type
2. A repayment ledger per debt
3. Open / paid / all filtering
4. Still-owed summary, broken down by lender type

## Recurring

1. Rules that write expenses *and* income
2. Daily, weekly, monthly, yearly
3. Runs on create, so today's row appears at once
4. Activate and deactivate
5. Rows outlive the rule that wrote them

## Reports

1. Week, month, year and all-time
2. Spending trend chart
3. Category breakdown
4. Export to PDF, XLSX and CSV — the whole report, or the rows alone

## Activity log

1. Every create, change and delete, written from model events
2. Field-level diffs, before to after, with foreign keys read as names
3. Filter by subject
4. Your own by default; everyone's for admins

## Admin

1. User management — create, edit, deactivate, avatars
2. Branding — logo and favicon
3. Theme colours
4. Exchange rate and the default currency amounts start in
5. FAQ management, and CMS pages at `/p/{slug}` (web)

## Across the app

1. Dual currency — enter in USD or riel, always stored in USD, converted
   server-side at the account's rate
2. English and Khmer throughout, English strings as the keys
3. Dark mode
4. Pull-to-refresh
5. An offline banner (native)

## Not in this app yet

Everything above is in the Flutter app except these, whose endpoints are
already live:

- **Help** — the FAQs for end users, from `GET /faqs`. On web and native.
- **CMS pages** — `/p/{slug}`. On web.

Email verification is also enforced on the web only; no mobile client
surfaces it.

# SpendLog — Proposal Prompt

Copy everything below the line into ChatGPT, Claude, Gemini or any other
assistant to have it draft a project proposal for SpendLog. Fill the
`[brackets]` first. The facts section was written from the actual code, so the
proposal it produces will describe what SpendLog really does rather than a
guess.

---

## Prompt

You are a technical writer helping me produce a project proposal for
**SpendLog**, a personal expense tracking application. Use only the facts
given below. Where the proposal needs something not listed here (dates, costs,
names), use the placeholders I give and do not invent figures.

### Who the proposal is for

- Audience: `[e.g. university final-year project committee / a client / an investor / internal stakeholders]`
- Author: `[your name]`, `[your role or programme]`
- Purpose of the proposal: `[e.g. approval to proceed / funding request / graded coursework]`
- Length and tone: `[e.g. 6–8 pages, formal academic / 2 pages, business-casual]`
- Language: `[English / Khmer / both]`

### 1. What SpendLog is

SpendLog is a self-hosted personal finance app for logging daily spending,
setting monthly budgets, and seeing where money goes. It targets everyday users
in Cambodia first: amounts can be entered in **US dollars or Khmer riel**, with
an admin-set exchange rate (default 4,100 KHR per USD) used for conversion.

It ships as **one Laravel API with four faces**:

- A **web app** (Laravel + Vue with Inertia) that also serves as the admin
  panel.
- A **cross-platform app** built with Flutter that runs on **Android, iOS,
  Linux, macOS, Windows and the web** from a single codebase.
- An **Expo / React Native** app.
- The **JSON API** itself.

Every client speaks to the same JSON API, so every feature exists once on the
server and is reused everywhere.

### 2. Features (as built)

**For every user**

- **Auth**: register, log in and out with per-device tokens; forgot and reset
  password, including a six-digit code path.
- **Expenses**: add, edit and delete items with a price, date and category.
  Search by text, filter by category and date range, a searchable category
  picker, and an inline "new category" while adding a one-off row.
- **Income**: add, edit and delete; a monthly summary split by source, largest
  first; a source picker that also accepts a name it has never seen.
- **Income sources**: a managed catalogue — add, rename, remove. A rename can
  rewrite the income filed under the old name. Usage count and total against
  each name.
- **Categories**: a colour and an icon per category, created by an admin.
  In-use protection: a category an expense or budget points at cannot go.
- **Budgets**: a budget per category per month plus an overall monthly budget,
  with spent, remaining and percent against each, and an `ok` / `warning` /
  `over` status.
- **Savings**: a monthly plan with a deposit and withdrawal ledger. A
  withdrawal spends the plan's unfilled headroom before touching deposits, an
  all-time balance carries between months, and overdraw is blocked under a lock.
- **Borrowing**: debts with a lender and lender type, a repayment ledger per
  debt, open/paid/all filtering, and a still-owed summary by lender type.
- **Recurring**: rules that write both expenses and income, daily through
  yearly, which run on create so today's row appears at once. Rows outlive the
  rule that wrote them.
- **Dashboard**: today's spend, the month against its budget with a month
  stepper, a category breakdown with each category's share, income and balance
  for the month, a savings card, and recent expenses.
- **Reports**: week, month, year and all-time, with a spending trend chart and
  a category breakdown. Export to **PDF, XLSX or CSV** — the whole report or
  the rows alone — and hand the file to the system share sheet.
- **Activity log**: every create, change and delete, written from model events,
  with field-level diffs and foreign keys read as names. Filter by subject.
- **Profile**: name, username, email, phone and avatar upload; change password;
  light, dark or system theme.

**For admins**

- Manage users (create, edit, deactivate, assign role, avatars).
- Manage categories for everyone.
- See everyone's activity log, not just your own.
- Branding: logo, favicon and theme colours.
- Edit app settings such as the KHR/USD exchange rate and the default currency
  amounts start in.
- Maintain a public FAQ, and CMS pages at `/p/{slug}` (web).

### 3. Architecture and technology

**Backend**

- PHP 8.3, **Laravel 13**, MySQL/MariaDB (any Laravel-supported database).
- REST API under `/api/v1`, authenticated with **Laravel Sanctum** bearer
  tokens. Each token carries **abilities** (for example `expenses:read`,
  `expenses:write`, `users:write`) so a client can be issued a least-privilege
  token.
- Roles and permissions with **spatie/laravel-permission** (user, admin,
  super-admin).
- Policies enforce ownership: a user can only read or change their own rows;
  admins can act across users.
- Filtering and sorting through **spatie/laravel-query-builder**; PDF export
  with **dompdf**; spreadsheet export with **maatwebsite/excel**.
- Money is stored as decimal and transmitted as strings to avoid floating-point
  drift.
- All resources are addressed by **UUID**, never by numeric ID.
- Web front end: Vue 3 + Inertia + shadcn-vue components.

**Mobile / desktop client (Flutter)**

- Dart (SDK `^3.13.0`), Flutter 3.47.3 stable, single codebase for six
  platforms.
- **provider** for state management, with `ChangeNotifier`,
  `ChangeNotifierProvider` and `ChangeNotifierProxyProvider` composed once in
  `lib/providers/app_providers.dart`, so a single write (for example saving an
  expense) refreshes the dashboard, expenses list and budgets together.
- **go_router** with a `StatefulShellRoute`: four tabs (Home, Expenses,
  Reports, Menu), each keeping its own navigation stack. Add and edit flows are
  full pages that hide the nav bar and pin their action to the footer.
- **Dio** HTTP client with an interceptor that attaches the token and signs the
  user out automatically when the server rejects it.
- Tokens are kept in the platform's secure storage (Keychain, Keystore, libsecret,
  Windows Credential Manager).
- Layered code: `models` (immutable, parsed from JSON), `repositories` (all API
  calls in one place), `providers`, `screens`, shared `widgets`.

**Design**

- A "glassmorphism" visual system: one gradient ground with soft colour blobs,
  translucent panes with a light edge for cards and inputs, real backdrop blur
  on the floating navigation bar and bottom sheets, pill-shaped controls, and a
  single brand green for anything actionable. Full light and dark themes.
- Inter typeface via Google Fonts.

**Quality**

- The backend has an audit document where each bug was reproduced, fixed and
  locked with a regression test (examples: a category budget silently becoming
  an overall budget; token abilities disagreeing with the permission model).
- The Flutter client passes static analysis with zero warnings.

### 4. Database entities

users, categories, expenses, budgets, personal_access_tokens, app_settings,
faqs, pages, plus the permission tables — and the tables behind income, income
sources, savings, borrowing, recurring rules and the activity log.
`[Confirm the exact table names in the API repo before citing them.]`

Key relationships: a user has many expenses and budgets; an expense belongs to
one category; a budget belongs to a user and optionally a category (null means
the overall budget); a debt has many repayments; a savings plan has many
deposit and withdrawal entries; a recurring rule writes expense and income rows
that outlive the rule itself.

### 5. Problem statement to build on

`[Edit or replace.]` Most people in Cambodia manage money in two currencies and
track it, if at all, in chat apps or notebooks. Mainstream finance apps assume a
single currency, need a bank connection, and are not self-hostable. SpendLog is
a small, fast tool that works offline-first in spirit (quick entry, no bank
link), handles USD and KHR side by side, and can be hosted by a family, a small
business or a school on their own server.

### 6. Roadmap ideas (mark as future work, not delivered)

- Offline queue with sync when back online — an offline banner exists today,
  a queue does not.
- **Help**: the end-user FAQs from `GET /faqs`. The endpoint is live; the
  Flutter app does not surface it yet.
- **CMS pages** at `/p/{slug}`: live on the web, absent from the Flutter app.
- Email verification on the mobile clients — enforced on the web only today.
- Receipt photo attachment and OCR.
- Shared households (multiple users on one budget).
- Bank/e-wallet import (ABA, Wing, Bakong) if APIs allow.
- Push notifications when a budget nears its limit.
- Widgets for quick entry on the home screen.

### 7. What I want you to produce

Write the proposal with these sections, in this order. Keep each section
focused; use short paragraphs and bullet lists where they help.

1. Title page: project name, author, audience, date `[date]`.
2. Executive summary (one paragraph).
3. Problem statement and motivation.
4. Objectives (measurable where possible).
5. Scope: what is included, what is explicitly out of scope.
6. Proposed solution: features, grouped as in section 2.
7. System architecture: describe the backend, the API, the clients and how
   they relate. Include a simple text or Mermaid diagram.
8. Technology stack with a one-line justification for each major choice.
9. Data model: list the entities and relationships from section 4.
10. Security and privacy: token abilities, ownership policies, secure storage,
    UUIDs, password reset.
11. Methodology and timeline: `[e.g. iterative, N weeks]`, phases and
    milestones. Use `[dates]` placeholders.
12. Resources and budget: `[hours / cost / hosting]` placeholders only.
13. Risks and mitigations.
14. Evaluation: how success will be measured (e.g. task completion time for
    adding an expense, crash-free rate, test coverage).
15. Future work, drawn from section 6.
16. Conclusion.
17. References: Flutter, Laravel, provider, go_router, Sanctum official
    documentation.

Rules:

- Do not claim features that are not in section 2.
- Do not invent numbers, dates or costs; leave the placeholders visible.
- Where a technical term first appears, explain it in a short clause.
- Output in Markdown with headings, ready to paste into a document editor.

---

## After you get the draft

- Replace every remaining `[placeholder]`.
- Read section 6 of the draft against section 2 above and cut anything that
  slipped in that SpendLog does not do.
- Add screenshots of the dashboard, expenses list, budgets and reports screens
  if the audience will see the document rather than hear it.

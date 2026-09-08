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

It ships as **one backend and two clients**:

- A **web app** (Laravel + Vue with Inertia) that also serves as the admin
  panel.
- A **cross-platform app** built with Flutter that runs on **Android, iOS,
  Linux, macOS, Windows and the web** from a single codebase.

Both clients speak to the same JSON API, so every feature exists once on the
server and is reused everywhere.

### 2. Features (as built)

**For every user**

- Sign in with email or username and password; forgot-password and reset flows;
  Google sign-in on the web.
- **Expenses**: add, edit and delete items with a price, date and category.
  Quick-add from a bottom sheet. Search by text, filter by category and date
  range, infinite-scroll list grouped by day, long-press to delete.
- **Categories**: colour and icon per category (10 colours, 16 icons). Admin
  creates the shared set; users pick from it.
- **Budgets**: an overall monthly budget and per-category budgets, with
  spent-versus-budget progress that turns amber near the limit and red when
  over. Month-by-month navigation.
- **Dashboard**: today's total, this month's total and amount left, a spending
  trend chart switchable between week, month, year and all-time, a breakdown by
  category, and the most recent expenses.
- **Reports**: totals and averages for a chosen period, a time-series chart,
  and a category breakdown. Export as **PDF, Excel or CSV** and hand the file to
  the system share sheet (save, send to Telegram, print).
- **Workouts** (a secondary module): log exercises with sets, reps, weight in
  kg or lb, or cardio duration; monthly summary with muscle-group split and
  personal records.
- **Profile**: edit name, username and email; change password; choose light,
  dark or system theme.

**For admins**

- Manage users (create, edit, delete, assign role).
- Manage categories for everyone.
- View all users' expenses with a per-user filter.
- Edit app settings such as the KHR/USD rate and default weight unit.
- Maintain a public FAQ (published or draft entries).

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

- Dart, Flutter 3.x, single codebase for six platforms.
- **Riverpod** for state management; every remote resource is a provider that
  screens watch, so a single write (for example saving an expense) invalidates
  the dashboard, expenses list and budgets together.
- **go_router** with a stateful shell: five tabs (Dashboard, Expenses, Budgets,
  Reports, Profile), each keeping its own navigation stack.
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
faqs, pages, exercise_types, workouts, workout_sets, plus the permission tables.

Key relationships: a user has many expenses and budgets; an expense belongs to
one category; a budget belongs to a user and optionally a category (null means
the overall budget); a workout has many sets, each referencing an exercise type.

### 5. Problem statement to build on

`[Edit or replace.]` Most people in Cambodia manage money in two currencies and
track it, if at all, in chat apps or notebooks. Mainstream finance apps assume a
single currency, need a bank connection, and are not self-hostable. SpendLog is
a small, fast tool that works offline-first in spirit (quick entry, no bank
link), handles USD and KHR side by side, and can be hosted by a family, a small
business or a school on their own server.

### 6. Roadmap ideas (mark as future work, not delivered)

- Offline queue with sync when back online.
- Recurring expenses and reminders.
- Receipt photo attachment and OCR.
- Shared households (multiple users on one budget).
- Bank/e-wallet import (ABA, Wing, Bakong) if APIs allow.
- Push notifications when a budget nears its limit.
- Localisation into Khmer.
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
7. System architecture: describe the backend, the API, the two clients and how
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
17. References: Flutter, Laravel, Riverpod, Sanctum official documentation.

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

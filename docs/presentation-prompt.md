# SpendLog — Presentation Prompt

Copy everything below the line into ChatGPT, Claude, Gemini, Gamma or any
other assistant to have it build a slide deck about the **SpendLog Flutter
app**. Fill the `[brackets]` first. The facts were read out of this repository
on 2026-09-29, so the deck it produces will describe what the app really is
rather than a guess.

Sibling prompts: `proposal-prompt.md`, `quotation-prompt.md`.

---

## Prompt

You are helping me build a **slide presentation** about **SpendLog**, the
Flutter client of a personal finance app. Use only the facts given below. Where
a slide needs something not listed here (dates, names, marks), use the
placeholders I give and do not invent figures.

### Who the deck is for

- Audience: `[e.g. university examiners / a client / a Flutter meetup]`
- Occasion: `[e.g. final-year project defence / sprint demo / pitch]`
- Length: `[e.g. 24 slides, 18 minutes]`
- Language: `[English / Khmer / both]`
- Built in: `[PowerPoint / Google Slides / Keynote / Gamma / Canva]`

**This is a team presentation. Six people present it.** Fill in the six names
and what each person owns — the deck must give every one of them a turn.

| # | Name | Role on the project | Presents |
| --- | --- | --- | --- |
| 1 | `[name]` | `[e.g. team lead / backend]` | Slides 1–4 |
| 2 | `[name]` | `[e.g. API and data model]` | Slides 5–8 |
| 3 | `[name]` | `[e.g. features / product]` | Slides 9–12 |
| 4 | `[name]` | `[e.g. architecture / state]` | Slides 13–16 |
| 5 | `[name]` | `[e.g. UI and localisation]` | Slides 17–20 |
| 6 | `[name]` | `[e.g. QA and testing]` | Slides 21–24 |

### 1. What SpendLog is

SpendLog is a self-hosted personal finance app for logging daily spending,
budgeting, and seeing where money goes. It targets everyday users in Cambodia
first, so amounts work in **US dollars and Khmer riel** side by side.

It is **one Laravel API with four faces**: this **Flutter** app, an **Expo /
React Native** app, an **Inertia + Vue** web app, and the **JSON API** itself.
Every feature exists once on the server and is reused everywhere.

**This deck is about the Flutter client only.** Mention the others once, for
context, then stay on Flutter.

### 2. Purpose — why the project exists

**The problem.** Most people in Cambodia manage money in two currencies at
once and track it, if at all, in a notebook or a chat app. Mainstream finance
apps assume one currency, expect a bank connection, and cannot be self-hosted.

**The purpose of the app.** Give one household a fast, private place to record
where money goes — in either currency, with no bank link, on whatever device
is to hand.

**The purpose of building it in Flutter.** Reach six platforms from one
codebase, so the same features ship everywhere without a team per platform.

**Objectives** — each of these is measurable, so use them again on the
evaluation slide:

1. Record an expense in **under ten seconds**, from cold open to saved.
2. Run on **six platforms** from a single codebase, with no per-platform fork.
3. Work fully in **English and Khmer**, including every form and error.
4. Accept **USD and KHR** interchangeably, without the user doing conversion.
5. Never let a money figure drift — amounts are decimal, never floating point.
6. Keep the auth token out of plain storage on every platform.
7. Hold static analysis at **zero warnings**.

### 3. Requirements

Present these as a requirements section. Keep the four groups separate.

**Build and tooling requirements**

| Requirement | Version | What it is for |
| --- | --- | --- |
| Flutter SDK | 3.47.3, stable | Builds and runs the app on all six targets |
| Dart SDK | `^3.13.0` (3.13.3 in use) | Language and analyzer |
| `flutter_lints` | ^6.0.0 | Enforces the lint set the code is held to |
| `flutter_test` | SDK | Widget and integration tests |

Per-platform toolchains are also needed to build: Android SDK + JDK for
Android, Xcode for iOS and macOS, GTK/CMake/`libsecret` for Linux, Visual
Studio C++ for Windows, and a Chromium browser for web.

**Target platforms** — one codebase, six platforms: **Android, iOS, Linux,
macOS, Windows, Web**.

**Dependency requirements** — for each, what it does and why it is here.

| Package | Version | What it does |
| --- | --- | --- |
| `dio` | ^5.11.0 | HTTP client. Carries every API call, and holds the interceptor that attaches the token and signs the user out when it is rejected |
| `provider` | ^6.1.2 | State management. Screens listen to `ChangeNotifier`s, so one write refreshes every view that shows it |
| `go_router` | ^17.5.0 | Declarative routing. Gives each nav tab its own navigation stack via a stateful shell |
| `flutter_secure_storage` | ^11.0.0 | Puts the auth token in the platform keystore — Keychain, Keystore, libsecret, Credential Manager |
| `google_fonts` | ^8.2.1 | Serves Inter for Latin text and Noto Sans Khmer for Khmer, which Inter cannot draw |
| `flutter_localizations` | SDK | Locale plumbing behind the English/Khmer switch |
| `path_provider` | ^2.1.6 | Finds the per-platform directory an export can be written to |
| `share_plus` | ^13.3.0 | Hands an exported PDF, XLSX or CSV to the system share sheet |
| `image_picker` | ^1.2.3 | Picks an avatar from the camera or gallery |
| `cupertino_icons` | ^1.0.8 | iOS-style icon set |

**Non-functional requirements**

- Bilingual **English and Khmer**, with 526 translated keys in
  `assets/lang/km.json`; English strings are the keys, the way the web does it.
- Auth tokens never touch plain storage — platform secure storage only.
- Light and dark themes, plus per-account colour and currency.
- Static analysis passes with zero warnings.
- Money is handled as strings/decimals, never floating point.

### 4. Features — what each area does

Functional requirements, as built. Use the verb, not just the noun.

| Area | What it does |
| --- | --- |
| **Auth** | Registers and signs in with per-device tokens; forgot and reset password, including a six-digit code path |
| **Dashboard** | Shows today's spend, the month against its budget with a month stepper, a category breakdown by share, income and balance, a savings card, and recent expenses |
| **Expenses** | Adds, edits and deletes rows; searches by text; filters by category and date range; offers a searchable category picker and an inline "new category" |
| **Income** | Adds, edits and deletes income; summarises the month by source, largest first; accepts a source name it has never seen |
| **Income sources** | Keeps a catalogue of names — add, rename, remove. A rename can rewrite the income filed under the old name. Tracks usage count and total |
| **Categories** | Holds a colour and icon per category, created by an admin. Refuses to delete one an expense or budget still points at |
| **Budgets** | Sets a budget per category per month plus an overall one, and reports spent, remaining and percent with an `ok` / `warning` / `over` status |
| **Savings** | Runs a monthly plan with a deposit and withdrawal ledger. A withdrawal spends the plan's unfilled headroom before touching deposits; the balance carries between months; overdraw is blocked under a lock |
| **Borrowing** | Tracks debts by lender and lender type, keeps a repayment ledger per debt, filters open/paid/all, and totals what is still owed by lender type |
| **Recurring** | Runs rules that write both expenses and income — daily to yearly — firing on create so today's row appears at once. Rows outlive the rule |
| **Reports** | Reports week, month, year and all-time with a trend chart and category breakdown, and exports to PDF, XLSX or CSV — the whole report or the rows alone |
| **Activity log** | Records every create, change and delete from model events, with field-level diffs and foreign keys read as names. Filters by subject |
| **Admin** | Manages users and categories, branding and theme colours, the exchange rate and default currency, and the FAQ |

### 5. Architecture

- **Layers**: `models` (immutable, parsed from JSON) → `repositories` (every
  API call in one place) → `providers` (state) → `screens` → shared `widgets`.
- **State**: `provider` with `ChangeNotifier`, `ChangeNotifierProvider` and
  `ChangeNotifierProxyProvider`, composed once in `lib/providers/app_providers.dart`.
  Notifiers include auth, locale, theme, branding and the dashboard's month and
  trend selections.
- **Routing**: `go_router` with a `StatefulShellRoute`, so each bottom-nav
  branch keeps its own navigation stack. Add/edit flows are full pages that
  hide the nav bar and pin their action to the footer.
- **Networking**: a single `dio` client with an interceptor that attaches the
  bearer token and signs the user out when the server rejects it.
- **Localisation**: a small JSON-backed `tr()` layer; supported locales are
  `en` and `km`.

### 6. Project facts (use for a "by the numbers" slide)

- **70** Dart files, **~20,390** lines under `lib/`
- **31** files in `lib/screens/`, **17** models, **7** providers, **2**
  repositories
- **4** widget/integration test files: smoke, provider wiring, back navigation,
  dashboard header
- **95** commits

### 7. Design system

A glassmorphism visual language: one gradient ground, translucent panes with a
light edge, real backdrop blur on the floating nav bar and tab controls,
pill-shaped controls, and a single brand green for anything actionable. Full
light and dark themes. **Inter** for Latin text, **Noto Sans Khmer** for Khmer,
both via `google_fonts`.

Notable UI detail worth one slide: the dashboard greeting is a
`SliverPersistentHeader` that collapses into a frosted bar as the cards scroll
under it — the avatar shrinks and the greeting line animates to zero height so
the name rises into the bar rather than leaving a gap.

### 8. What I want you to produce

A deck of **24 slides**, in this order, split evenly across the six
presenters — **four slides each**. Give each slide a **title**, **3–5 bullets
of at most 12 words each**, and a **speaker note** of 2–3 sentences.

Mark every slide with the presenter who owns it, as `Presenter 1` … 
`Presenter 6`, so the team can rehearse straight from the deck.

**Presenter 1 — framing**

1. Title — project name, the six team members, occasion, `[date]`
2. The team — the six names, each with the part of the project they owned
3. The problem — two currencies, notebooks and chat apps, no self-hosted option
4. Purpose — what the app is for, and what Flutter is for, from section 2

**Presenter 2 — scope and requirements**

5. Objectives — the seven measurable objectives in section 2
6. What SpendLog is — one API, four clients; this deck is the Flutter one
7. Requirements — build and tooling, with what each is for
8. Requirements — dependencies; name the package **and** what it does

**Presenter 3 — what it does**

9. Requirements — non-functional
10. Features, part 1 — Auth, Dashboard, Expenses, Income, Income sources
11. Features, part 2 — Categories, Budgets, Savings, Borrowing, Recurring
12. Features, part 3 — Reports, Activity log, Admin

**Presenter 4 — how it is built**

13. Architecture — the layer diagram (include a simple Mermaid or text diagram)
14. State management — why `provider`, and how one write refreshes many screens
15. Navigation — `go_router` stateful shell, form pages over sheets
16. Design system — glassmorphism, Inter/Noto Sans Khmer, light and dark

**Presenter 5 — craft and safety**

17. Localisation — English and Khmer, 526 keys
18. Security — secure storage, token interceptor, UUIDs
19. Quality — tests, zero-warning analysis
20. By the numbers — the metrics in section 6

**Presenter 6 — closing**

21. Evaluation — measure the deck's claims against the objectives in section 2
22. Roadmap — clearly marked as future work
23. Demo / screenshots — leave placeholders
24. Conclusion and questions

Rules:

- **Every bullet must say what the thing does, not just name it.** Write
  "`dio` — carries every API call and refreshes the token", never "`dio`".
- Every feature bullet starts with a verb: *records*, *filters*, *exports*.
- Do **not** claim features outside section 4, and do **not** call the state
  management Riverpod — this app uses `provider`.
- Do not invent numbers, dates or marks; leave `[placeholders]` visible.
- Bullets are for the slide, prose goes in the speaker note. Never write a
  paragraph on a slide.
- Explain each technical term the first time it appears, in a short clause.
- Output as Markdown, one `##` heading per slide, ready to paste into
  `[chosen tool]`.

---

## After you get the deck

- Replace every remaining `[placeholder]`.
- Drop in a real screenshot on the demo slide. A 1170×2532 render of the
  dashboard is at `~/Pictures/spendlog-dashboard.png`.
- Read the deck back against section 4 and cut anything SpendLog does not do.
- Check that every bullet survives the "so what does it do?" test. If a bullet
  is a bare noun, it is not finished.
- Rehearse against the clock: 24 slides is roughly 15–18 minutes, which is
  **four slides and about 2½–3 minutes each**. Time each presenter separately —
  a team deck overruns at the handovers, not in the middle of a section.
- Agree the six handover lines in advance ("…and `[name]` will take you through
  the architecture"). Write them into the speaker notes so nobody stalls.
- If you must lose time, merge slides 10–12 into one features table and cut
  slides 14 and 15. Re-balance afterwards so nobody is left with one slide.

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

- Audience: `[e.g. university examiners / a client / my team / a Flutter meetup]`
- Speaker: `[your name]`, `[your role or programme]`
- Occasion: `[e.g. final-year project defence / sprint demo / pitch]`
- Length: `[e.g. 12 slides, 10 minutes]`
- Language: `[English / Khmer / both]`
- Built in: `[PowerPoint / Google Slides / Keynote / Gamma / Canva]`

### 1. What SpendLog is

SpendLog is a self-hosted personal finance app for logging daily spending,
budgeting, and seeing where money goes. It targets everyday users in Cambodia
first, so amounts work in **US dollars and Khmer riel** side by side.

It is **one Laravel API with four faces**: this **Flutter** app, an **Expo /
React Native** app, an **Inertia + Vue** web app, and the **JSON API** itself.
Every feature exists once on the server and is reused everywhere.

**This deck is about the Flutter client only.** Mention the others once, for
context, then stay on Flutter.

### 2. Requirements

Present these as a requirements section. Keep the four groups separate.

**Build and tooling requirements**

| Requirement | Version |
| --- | --- |
| Flutter SDK | 3.47.3, stable channel |
| Dart SDK | `^3.13.0` (3.13.3 in use) |
| Linting | `flutter_lints` ^6.0.0 |
| Testing | `flutter_test` (SDK) |

Per-platform toolchains are also needed to build: Android SDK + JDK for
Android, Xcode for iOS and macOS, GTK/CMake/`libsecret` for Linux, Visual
Studio C++ for Windows, and a Chromium browser for web.

**Target platforms** — one codebase, six platforms: **Android, iOS, Linux,
macOS, Windows, Web**.

**Dependency requirements**

| Package | Version | Why it is there |
| --- | --- | --- |
| `dio` | ^5.11.0 | HTTP client for the JSON API |
| `provider` | ^6.1.2 | State management (`ChangeNotifier`) |
| `go_router` | ^17.5.0 | Declarative routing, stateful shell |
| `flutter_secure_storage` | ^11.0.0 | Keeps the auth token in the platform keystore |
| `google_fonts` | ^8.2.1 | Inter, and Noto Sans Khmer for Khmer |
| `flutter_localizations` | SDK | Locale plumbing |
| `path_provider` | ^2.1.6 | Filesystem locations for exports |
| `share_plus` | ^13.3.0 | Hands exported files to the system share sheet |
| `image_picker` | ^1.2.3 | Avatar and receipt image selection |
| `cupertino_icons` | ^1.0.8 | iOS-style icon set |

**Functional requirements**, by area, as built: Auth · Dashboard · Expenses ·
Income · Income sources · Categories · Budgets · Savings · Borrowing ·
Recurring · Reports · Activity log · Admin.

**Non-functional requirements**

- Bilingual **English and Khmer**, with 526 translated keys in
  `assets/lang/km.json`; English strings are the keys, the way the web does it.
- Auth tokens never touch plain storage — platform secure storage only.
- Light and dark themes, plus per-account colour and currency.
- Static analysis passes with zero warnings.
- Money is handled as strings/decimals, never floating point.

### 3. Architecture

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

### 4. Project facts (use for a "by the numbers" slide)

- **70** Dart files, **~20,390** lines under `lib/`
- **31** files in `lib/screens/`, **17** models, **7** providers, **2**
  repositories
- **4** widget/integration test files: smoke, provider wiring, back navigation,
  dashboard header
- **95** commits

### 5. Design system

A glassmorphism visual language: one gradient ground, translucent panes with a
light edge, real backdrop blur on the floating nav bar and tab controls,
pill-shaped controls, and a single brand green for anything actionable. Full
light and dark themes. **Inter** for Latin text, **Noto Sans Khmer** for Khmer,
both via `google_fonts`.

Notable UI detail worth one slide: the dashboard greeting is a
`SliverPersistentHeader` that collapses into a frosted bar as the cards scroll
under it — the avatar shrinks and the greeting line animates to zero height so
the name rises into the bar rather than leaving a gap.

### 6. What I want you to produce

A deck of `[N]` slides in this order. Give each slide a **title**, **3–5
bullets of at most 12 words each**, and a **speaker note** of 2–3 sentences.

1. Title — project name, speaker, occasion, `[date]`
2. The problem — two currencies, notebooks and chat apps, no self-hosted option
3. What SpendLog is — one API, four clients; this deck is the Flutter one
4. Why Flutter — one codebase, six platforms
5. Requirements — build and tooling
6. Requirements — dependencies (use the table, trimmed to the top 6)
7. Requirements — functional, by area
8. Requirements — non-functional
9. Architecture — the layer diagram (include a simple Mermaid or text diagram)
10. State management — why `provider`, and how one write refreshes many screens
11. Navigation — `go_router` stateful shell, form pages over sheets
12. Design system — glassmorphism, Inter/Noto Sans Khmer, light and dark
13. Localisation — English and Khmer, 526 keys
14. Security — secure storage, token interceptor, UUIDs
15. Quality — tests, zero-warning analysis
16. By the numbers — the metrics in section 4
17. Roadmap — clearly marked as future work
18. Demo / screenshots — leave placeholders
19. Conclusion and questions

Rules:

- Do **not** claim features outside section 2, and do **not** call the state
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
- Read the deck back against section 2 and cut anything SpendLog does not do.
- Rehearse against the clock: 19 slides is roughly 12–15 minutes at a
  comfortable pace — cut slides 10 and 11 first if you need to lose time.

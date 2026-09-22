# SpendLog features

The feature list is kept once, in the API repo, beside the API reference it
belongs with:

> `spendlog/docs/FEATURES.md`

It is not duplicated here on purpose. The features are the product's, not this
client's — the same expenses, budgets, savings and reports are served to the
Flutter app, the Expo app and the Inertia web app from one API — and a second
copy would start drifting the first time either was edited.

## What this client is missing

Two things in that list are not in the Flutter app yet, though the endpoints
for both are live:

- **Help** — the FAQs for end users, from `GET /faqs`. On web and native.
- **CMS pages** — `/p/{slug}`. On web.

Anything else in the list, this app has.

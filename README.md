# Gold Manager

A gold **sale & purchase** manager for one operator.

- **Current stock** — one pool, tracked in grams with a weighted-average cost per gram.
- **Transaction history** — every purchase and sale, filterable, with the running balance after each.
- **Login** — single credential `mani` / `1977`.
- **Theme** — yellow on black.
- **Stack** — Flutter (mobile) · Node/Express (API) · MongoDB.

```
gold/
├── mockup/prototype.html   # clickable six-screen visual prototype
├── backend/                # Node/Express + MongoDB API
└── mobile/                 # Flutter app
```

The visual prototype is also published at
<https://claude.ai/code/artifact/6aa9d027-8962-44df-9daa-7f42329f55f5>.

---

## 1. Backend

```bash
cd backend
cp .env.example .env          # set JWT_SECRET
npm install
```

**With a local MongoDB:**

```bash
# macOS install, once:
brew tap mongodb/brew && brew install mongodb-community
brew services start mongodb-community

npm run seed                  # user mani/1977 + 6 sample transactions
npm run dev                   # http://localhost:3000
```

**Without installing MongoDB** (in-memory, data not persisted — good for trying the app):

```bash
npm run dev:mem               # boots + seeds + serves on :3000
```

**Verify end-to-end** (spins its own in-memory Mongo):

```bash
npm run smoke                 # 19 checks: auth, stock math, over-sell 422, delete recompute, ...
```

API reference and stock-math notes: [backend/README.md](backend/README.md).

---

## 2. Mobile (Flutter)

This repo uses [`fvm`](https://fvm.app). Drop `fvm ` from the commands if you use a
system Flutter (stable channel, Dart ≥ 3.4).

```bash
cd mobile
fvm use stable                # one-time SDK download if needed
fvm flutter pub get
```

Run it, pointing at the backend. `10.0.2.2` is the Android emulator's route to
the host's `localhost`:

```bash
# Android emulator
fvm flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# iOS simulator
fvm flutter run --dart-define=API_BASE_URL=http://localhost:3000

# physical device — use the host's LAN IP
fvm flutter run --dart-define=API_BASE_URL=http://192.168.x.x:3000
```

Checks:

```bash
fvm flutter analyze
fvm flutter test
```

### Screens
`login` → `dashboard` (stock card, buy/sell, recent, realized profit) →
`add transaction` (buy/sale, live total, sale guarded by stock) →
`history` (All/Buy/Sell, grouped by date) → `transaction detail` (full record, delete).

State lives in `lib/state/app_state.dart`; every write calls the API then
re-pulls `/api/stock` + `/api/transactions` so the client never drifts.

---

## End-to-end smoke test (both together)

1. `cd backend && npm run dev:mem`
2. `cd mobile && fvm flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`
3. Sign in `mani` / `1977` → dashboard shows **860.00 g**, avg **₹5,914.95/g**, value **₹50,86,856**.
4. Buy 25 g → dashboard updates without a manual reload.
5. Try to sell more than stock → **Save** disabled, "Only … g available".
6. Sell a valid amount → weight drops, average cost unchanged, realized profit rises.
7. History → open a row → **Delete** → stock recomputes.
8. Kill the app and reopen → still signed in. Log out → back to login, token cleared.

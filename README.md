# Gold Manager

A gold **sale & purchase** manager for one operator.

- **Current stock** — one pool, tracked in grams with a weighted-average cost per gram.
- **Transaction history** — every purchase and sale, with the running balance after each.
  Search by buyer/seller name or note, and filter by a date range.
- **Deferred payments** — a buyer can pay for a sale (or you can pay a seller for a
  purchase) in full, partially, or later. Each transaction tracks Paid / Due and keeps
  a list of instalments; payments never affect stock or profit.
- **Per-person balances** — every party has a page showing all their bills and one
  **Receivable** / **Payable** total. Record what they paid once and tick which bills
  it covers — no need to open each transaction. Names are picked from a dropdown of
  those already used and grouped case-insensitively, so one person stays one row.
- **Loans** — lend cash (interest per day) or gold (interest per month), each with a
  "count the start day" toggle. Interest = principal ÷ reference × rate × periods,
  accruing continuously (a month = 30 days). Repaid in one go on a chosen date;
  principal + interest returns to your position.
- **Opening balances + one position** — you start with an opening cash and gold
  amount (editable). **Cash in hand** and **gold in stock** then flow through
  everything: purchases, sales, bill payments, loans out and loan repayments. Trade
  weighted-average cost and profit still come from buy/sell only.
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

# Gold Manager — Backend

Node/Express + MongoDB API for gold stock and the purchase/sale ledger.

## Run

```bash
cd backend
cp .env.example .env          # then edit JWT_SECRET
npm install

# MongoDB must be running. On macOS:
#   brew tap mongodb/brew
#   brew install mongodb-community
#   brew services start mongodb-community

npm run seed                  # creates user mani/1977 + 6 sample transactions
npm run dev                   # http://localhost:3000
```

No local MongoDB? Run the full end-to-end check against an in-memory server:

```bash
npm run smoke
```

## API

All routes except `POST /api/auth/login` require `Authorization: Bearer <token>`.

| Method | Path | Body / query | Returns |
| --- | --- | --- | --- |
| POST | `/api/auth/login` | `{ username, password }` | `{ token, user }` — 401 on mismatch |
| GET | `/api/stock` | — | `{ weightGrams, avgCostPerGram, stockValue, realizedProfit, lastRatePerGram, transactionCount }` |
| GET | `/api/transactions` | `?type=purchase\|sale` | array, newest first, each with `balanceAfter` |
| POST | `/api/transactions` | `{ type, date?, weightGrams, ratePerGram, note? }` | created row — **422** if a sale exceeds stock |
| GET | `/api/transactions/:id` | — | one row with `balanceAfter` |
| DELETE | `/api/transactions/:id` | — | `{ ok: true }` |

`totalAmount` is always computed server-side as `weightGrams * ratePerGram`.

## Stock math

`src/services/stock.js` is the single source of truth. Stock is one pool —
grams on hand plus a weighted-average cost per gram — derived by replaying every
transaction in date order, so it can never drift from the ledger.

- purchase of `q` g @ `r`: `avg = (qty*avg + q*r) / (qty + q)`, `qty += q`
- sale of `q` g @ `r`: `qty -= q`, `avg` unchanged, `profit = q*(r - avg)`

## curl

```bash
TOKEN=$(curl -s localhost:3000/api/auth/login -H 'Content-Type: application/json' \
  -d '{"username":"mani","password":"1977"}' | node -pe 'JSON.parse(require("fs").readFileSync(0)).token')

curl -s localhost:3000/api/stock -H "Authorization: Bearer $TOKEN"
curl -s localhost:3000/api/transactions -H "Authorization: Bearer $TOKEN"
```

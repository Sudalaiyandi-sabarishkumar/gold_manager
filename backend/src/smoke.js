// End-to-end smoke test with an in-memory MongoDB — no local Mongo install needed.
//   node src/smoke.js
// Exits non-zero on the first failed assertion.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'smoke-secret';

const { MongoMemoryServer } = require('mongodb-memory-server');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const { createApp } = require('./app');
const { connectDb } = require('./config/db');
const User = require('./models/User');
const Transaction = require('./models/Transaction');
const { SAMPLE } = require('./seed');

let pass = 0;
function check(label, cond) {
  if (cond) {
    pass += 1;
    console.log(`  ok  ${label}`);
  } else {
    console.error(`FAIL  ${label}`);
    process.exitCode = 1;
    throw new Error(`assertion failed: ${label}`);
  }
}
const approx = (a, b, tol = 0.02) => Math.abs(a - b) <= tol;

async function main() {
  const mem = await MongoMemoryServer.create();
  await connectDb(mem.getUri('gold_manager'));

  // --- seed ---
  await User.findOneAndUpdate(
    { username: 'mani' },
    { username: 'mani', passwordHash: await bcrypt.hash('1977', 10) },
    { upsert: true }
  );
  await Transaction.insertMany(
    SAMPLE.map((t) => ({
      ...t,
      date: new Date(t.date),
      totalAmount: Math.round(t.weightGrams * t.ratePerGram * 100) / 100,
    }))
  );

  const app = createApp();
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  const json = async (res) => ({ status: res.status, body: await res.json().catch(() => null) });

  // --- auth ---
  let r = await json(await fetch(`${base}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'mani', password: '1977' }),
  }));
  check('login with mani/1977 -> 200 + token', r.status === 200 && typeof r.body.token === 'string');
  const token = r.body.token;
  const authH = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

  r = await json(await fetch(`${base}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'mani', password: 'wrong' }),
  }));
  check('login with wrong password -> 401', r.status === 401);

  r = await json(await fetch(`${base}/api/stock`));
  check('GET /api/stock without token -> 401', r.status === 401);

  // --- stock from seed ---
  r = await json(await fetch(`${base}/api/stock`, { headers: authH }));
  check('seeded stock weight = 860 g', approx(r.body.weightGrams, 860));
  check('seeded avg cost ~ 5914.95 /g', approx(r.body.avgCostPerGram, 5914.95, 0.05));
  check('seeded realized profit ~ 40756', approx(r.body.realizedProfit, 40755.88, 1));

  // --- purchase moves weight + avg ---
  r = await json(await fetch(`${base}/api/transactions`, {
    method: 'POST',
    headers: authH,
    body: JSON.stringify({ type: 'purchase', date: '2026-09-08', weightGrams: 100, ratePerGram: 7000 }),
  }));
  check('POST purchase -> 201', r.status === 201 && r.body.type === 'purchase');
  check('purchase total computed server-side (700000)', r.body.totalAmount === 700000);
  const afterBuy = await json(await fetch(`${base}/api/stock`, { headers: authH }));
  check('weight rises by 100 -> 960 g', approx(afterBuy.body.weightGrams, 960));
  check('avg cost moved up toward 7000', afterBuy.body.avgCostPerGram > 6014);

  // --- over-sell rejected ---
  r = await json(await fetch(`${base}/api/transactions`, {
    method: 'POST',
    headers: authH,
    body: JSON.stringify({ type: 'sale', date: '2026-09-08', weightGrams: 5000, ratePerGram: 6200 }),
  }));
  check('over-sell -> 422 with available message', r.status === 422 && /available/.test(r.body.error));

  // --- valid sale: weight drops, avg unchanged ---
  const avgBeforeSale = afterBuy.body.avgCostPerGram;
  r = await json(await fetch(`${base}/api/transactions`, {
    method: 'POST',
    headers: authH,
    body: JSON.stringify({ type: 'sale', date: '2026-09-08', weightGrams: 60, ratePerGram: 6300 }),
  }));
  check('POST sale -> 201', r.status === 201 && r.body.type === 'sale');
  const saleId = r.body.id;
  const afterSale = await json(await fetch(`${base}/api/stock`, { headers: authH }));
  check('weight drops by 60 -> 900 g', approx(afterSale.body.weightGrams, 900));
  check('avg cost unchanged by sale', approx(afterSale.body.avgCostPerGram, avgBeforeSale, 0.01));

  // --- list + filter + balanceAfter ---
  r = await json(await fetch(`${base}/api/transactions`, { headers: authH }));
  check(
    'GET /api/transactions -> 8 rows (6 seed + buy + sale), newest first',
    r.body.length === 8 && r.body[0].id === saleId
  );
  check('rows carry balanceAfter', typeof r.body[0].balanceAfter === 'number');
  r = await json(await fetch(`${base}/api/transactions?type=sale`, { headers: authH }));
  check('filter type=sale -> only sales', r.body.every((t) => t.type === 'sale'));

  // --- delete restores stock ---
  r = await json(await fetch(`${base}/api/transactions/${saleId}`, { method: 'DELETE', headers: authH }));
  check('DELETE sale -> ok', r.status === 200 && r.body.ok === true);
  const afterDelete = await json(await fetch(`${base}/api/stock`, { headers: authH }));
  check('weight returns to 960 g after delete', approx(afterDelete.body.weightGrams, 960));

  server.close();
  await mongoose.disconnect();
  await mem.stop();
  console.log(`\n${pass} checks passed`);
}

main().catch((err) => {
  console.error('\nsmoke test errored:', err.message);
  process.exit(1);
});

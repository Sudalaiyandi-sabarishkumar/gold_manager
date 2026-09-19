const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const rateLimit = require('express-rate-limit');
const ah = require('../lib/asyncHandler');

const router = express.Router();

// Max 10 login attempts per IP per 15 minutes (successful logins count too,
// which is fine for a single-user app).
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many login attempts. Try again in 15 minutes.' },
});

// POST /api/auth/login  { username, password } -> { token, user }
router.post(
  '/login',
  loginLimiter,
  ah(async (req, res) => {
    const { username, password } = req.body || {};
    if (!username || !password) {
      return res.status(400).json({ error: 'username and password are required' });
    }

    const user = await User.findOne({ username: String(username).toLowerCase().trim() });
    // Compare even when the user is missing to keep timing roughly constant.
    const hash = user ? user.passwordHash : '$2a$10$invalidinvalidinvalidinvalidinvalidinvalidinv';
    const ok = await bcrypt.compare(String(password), hash);

    if (!user || !ok) return res.status(401).json({ error: 'Invalid credentials' });

    const token = jwt.sign(
      { sub: String(user._id), username: user.username },
      process.env.JWT_SECRET,
      { algorithm: 'HS256', expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );
    res.json({ token, user: { username: user.username } });
  })
);

module.exports = router;

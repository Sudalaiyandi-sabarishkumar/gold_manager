// Wrap an async route handler so rejected promises reach Express' error handler
// (Express 4 does not catch async errors on its own).
module.exports = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

const mongoose = require('mongoose');

async function connectDb(uri) {
  mongoose.set('strictQuery', true);
  await mongoose.connect(uri);
  const safe = uri.replace(/\/\/[^@]+@/, '//***@');
  console.log('[db] connected:', safe);
  return mongoose.connection;
}

module.exports = { connectDb };

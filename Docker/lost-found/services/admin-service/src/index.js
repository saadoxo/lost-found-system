const express = require('express');
const helmet  = require('helmet');

const app  = express();
const PORT = process.env.PORT || 3007;

app.use(helmet());
app.use(express.json({ limit: '10kb' }));

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'admin-service' });
});

app.get('/ready', (req, res) => {
  res.json({ status: 'ready', service: 'admin-service' });
});

app.listen(PORT, () => {
  console.log(JSON.stringify({ level: 'info', message: `admin-service listening on ${PORT}` }));
});

const express = require('express');
const helmet  = require('helmet');

const app  = express();
const PORT = process.env.PORT || 3003;

app.use(helmet());
app.use(express.json({ limit: '10kb' }));

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'search-service' });
});

app.get('/ready', (req, res) => {
  res.json({ status: 'ready', service: 'search-service' });
});

app.listen(PORT, () => {
  console.log(JSON.stringify({ level: 'info', message: `search-service listening on ${PORT}` }));
});

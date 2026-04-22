const express = require('express');
const helmet  = require('helmet');

const app  = express();
const PORT = process.env.PORT || 3006;

app.use(helmet());
app.use(express.json({ limit: '10kb' }));

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'image-service' });
});

app.get('/ready', (req, res) => {
  res.json({ status: 'ready', service: 'image-service' });
});

app.listen(PORT, () => {
  console.log(JSON.stringify({ level: 'info', message: `image-service listening on ${PORT}` }));
});

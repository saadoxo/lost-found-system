const app = require('./app');

const PORT = process.env.PORT || 3001;

app.listen(PORT, () => {
  console.log(JSON.stringify({
    level: 'info',
    message: `auth-service listening on ${PORT}`,
    env: process.env.NODE_ENV
  }));
});

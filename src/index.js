const express = require('express');
const client = require('prom-client');
const fs = require('fs');

const app = express();
const register = new client.Registry();

const requestsTotal = new client.Counter({
  name: 'app_requests_total',
  help: 'Total number of requests received',
  registers: [register],
});

const errorsTotal = new client.Counter({
  name: 'app_errors_total',
  help: 'Total number of errors returned',
  registers: [register],
});

const LOG_FILE = '/app/logs/app.log';

function log(level, message, extra = {}) {
  const entry = JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    message,
    ...extra,
  });
  console.log(entry);
  try {
    fs.appendFileSync(LOG_FILE, entry + '\n');
  } catch (err) {
    console.error('log write failed:', err.message);
  }
}

app.get('/', (req, res) => {
  requestsTotal.inc();
  log('info', 'Request received', { endpoint: '/', method: req.method, status: 200 });
  res.json({ status: 'ok', message: 'Hello from the observability app!' });
});

app.get('/error', (req, res) => {
  requestsTotal.inc();
  errorsTotal.inc();
  log('error', 'Error endpoint hit', { endpoint: '/error', method: req.method, status: 500 });
  res.status(500).json({ status: 'error', message: 'Simulated error' });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(3000, () => {
  log('info', 'Application started', { port: 3000 });
});

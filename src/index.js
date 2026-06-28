const express = require('express');
const client = require('prom-client');
const fs = require('fs');

const app = express();
const register = new client.Registry();

client.collectDefaultMetrics({ register });

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

const httpDuration = new client.Histogram({
  name: 'app_http_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1],
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

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    memory: process.memoryUsage(),
    version: process.env.npm_package_version || '1.0.0',
  });
});

app.get('/', (req, res) => {
  const end = httpDuration.startTimer({ method: req.method, route: '/' });
  requestsTotal.inc();
  log('info', 'Request received', { endpoint: '/', method: req.method, status: 200 });
  res.json({ status: 'ok', message: 'Hello from the observability app!' });
  end({ status_code: 200 });
});

app.get('/error', (req, res) => {
  const end = httpDuration.startTimer({ method: req.method, route: '/error' });
  requestsTotal.inc();
  errorsTotal.inc();
  log('error', 'Error endpoint hit', { endpoint: '/error', method: req.method, status: 500 });
  res.status(500).json({ status: 'error', message: 'Simulated error' });
  end({ status_code: 500 });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(3000, () => {
  log('info', 'Application started', { port: 3000 });
});

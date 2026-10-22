import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import app from '../src/app.js';

test('Health Endpoints Test Suite', async (t) => {
  await t.test('GET /health returns 200 and valid health status object', async () => {
    const res = await request(app).get('/health');

    assert.equal(res.status, 200);
    assert.equal(res.headers['content-type'].includes('application/json'), true);
    assert.equal(res.body.status, 'healthy');
    assert.equal(typeof res.body.timestamp, 'string');
    assert.equal(typeof res.body.uptimeSeconds, 'number');
    assert.equal(typeof res.body.service.name, 'string');
    assert.equal(typeof res.body.service.version, 'string');
    assert.equal(typeof res.body.system.freeMemoryMB, 'number');
    assert.equal(typeof res.body.system.totalMemoryMB, 'number');
  });

  await t.test('GET /api/health also aliases the health probe', async () => {
    const res = await request(app).get('/api/health');

    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'healthy');
  });
});

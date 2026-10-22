import test from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
import app from '../src/app.js';

test('API & Middleware Test Suite', async (t) => {
  await t.test('GET / returns 200 operational message and endpoints', async () => {
    const res = await request(app).get('/');
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'operational');
    assert.equal(typeof res.body.name, 'string');
  });

  await t.test('GET /api returns 200 and API metadata endpoints', async () => {
    const res = await request(app).get('/api');
    assert.equal(res.status, 200);
    assert.equal(typeof res.body.endpoints, 'object');
    assert.equal(res.body.endpoints.health, '/health');
  });

  await t.test('GET /api/info returns features and environment details', async () => {
    const res = await request(app).get('/api/info');
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'online');
    assert.equal(Array.isArray(res.body.features), true);
  });

  await t.test('GET /api/items returns list of items', async () => {
    const res = await request(app).get('/api/items');
    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.equal(Array.isArray(res.body.data), true);
  });

  await t.test('POST /api/items with valid payload creates an item', async () => {
    const payload = { name: 'Automated CI Test Item', category: 'Testing' };
    const res = await request(app)
      .post('/api/items')
      .send(payload)
      .set('Accept', 'application/json');

    assert.equal(res.status, 201);
    assert.equal(res.body.success, true);
    assert.equal(res.body.data.name, 'Automated CI Test Item');
    assert.equal(res.body.data.category, 'Testing');
  });

  await t.test('POST /api/items with missing name returns 400 Bad Request', async () => {
    const res = await request(app)
      .post('/api/items')
      .send({ category: 'Missing Name' })
      .set('Accept', 'application/json');

    assert.equal(res.status, 400);
    assert.equal(res.body.success, false);
    assert.equal(res.body.error.status, 400);
    assert.equal(typeof res.body.error.message, 'string');
  });

  await t.test('GET /api/error-test invokes centralized error handler', async () => {
    const res = await request(app).get('/api/error-test');
    assert.equal(res.status, 500);
    assert.equal(res.body.success, false);
    assert.equal(res.body.error.status, 500);
    assert.equal(typeof res.body.error.message, 'string');
  });

  await t.test('GET non-existent route returns standard 404 JSON', async () => {
    const res = await request(app).get('/does-not-exist-route-xyz');
    assert.equal(res.status, 404);
    assert.equal(res.body.success, false);
    assert.equal(res.body.error.status, 404);
  });
});

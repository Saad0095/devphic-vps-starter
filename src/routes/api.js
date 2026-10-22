import { Router } from 'express';
import config from '../config.js';

const router = Router();

// Sample in-memory data collection for demonstration
const sampleItems = [
  { id: 1, name: 'Sample Item Alpha', category: 'Deployment', status: 'active' },
  { id: 2, name: 'Sample Item Beta', category: 'Monitoring', status: 'pending' },
  { id: 3, name: 'Sample Item Gamma', category: 'Security', status: 'verified' },
];

/**
 * GET /api
 * Root API metadata and documentation link
 */
router.get('/', (_req, res) => {
  res.json({
    name: config.appName,
    version: config.appVersion,
    description: 'Production-ready Node.js LTS starter running on Ubuntu 24.04 VPS with Docker and Nginx',
    endpoints: {
      health: '/health',
      root: '/',
      api: '/api',
      info: '/api/info',
      items: '/api/items',
      errorTest: '/api/error-test',
    },
    documentation: 'https://github.com/Saad0095/devphic-vps-starter',
    timestamp: new Date().toISOString(),
  });
});

/**
 * GET /api/info
 * Basic application runtime info
 */
router.get('/info', (_req, res) => {
  res.json({
    status: 'online',
    appName: config.appName,
    environment: config.env,
    uptimeSeconds: Math.floor(process.uptime()),
    features: [
      'Docker multi-stage build',
      'Nginx reverse proxy with SSL termination',
      'Certbot Let\'s Encrypt auto-renewal',
      'Graceful process shutdown',
      'UFW firewall automated hardening',
    ],
  });
});

/**
 * GET /api/items
 * Retrieve sample items list
 */
router.get('/items', (_req, res) => {
  res.json({
    success: true,
    count: sampleItems.length,
    data: sampleItems,
  });
});

/**
 * POST /api/items
 * Create a new item (demonstrates JSON payload handling and validation)
 */
router.post('/items', (req, res, next) => {
  try {
    const { name, category } = req.body || {};

    if (!name || typeof name !== 'string') {
      const error = new Error('Field "name" is required and must be a string');
      error.statusCode = 400;
      return next(error);
    }

    const newItem = {
      id: sampleItems.length + 1,
      name: name.trim(),
      category: (category && typeof category === 'string') ? category.trim() : 'General',
      status: 'created',
      createdAt: new Date().toISOString(),
    };

    sampleItems.push(newItem);

    return res.status(201).json({
      success: true,
      message: 'Item created successfully',
      data: newItem,
    });
  } catch (err) {
    return next(err);
  }
});

/**
 * GET /api/error-test
 * Deliberately triggers an error to test the centralized error handler
 */
router.get('/error-test', (_req, _res, next) => {
  const testError = new Error('Deliberate test error triggered to verify error handling middleware.');
  testError.statusCode = 500;
  next(testError);
});

export default router;

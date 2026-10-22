import { Router } from 'express';
import os from 'os';
import config from '../config.js';

const router = Router();

/**
 * GET /health
 * System health and metrics probe endpoint for container orchestrators,
 * load balancers (Nginx), and uptime monitoring services.
 */
router.get('/health', (_req, res) => {
  const memoryUsage = process.memoryUsage();

  const healthData = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptimeSeconds: Math.floor(process.uptime()),
    service: {
      name: config.appName,
      version: config.appVersion,
      environment: config.env,
      nodeVersion: process.version,
    },
    system: {
      hostname: os.hostname(),
      platform: process.platform,
      arch: process.arch,
      loadAverage: os.loadavg(),
      freeMemoryMB: Math.round(os.freemem() / (1024 * 1024)),
      totalMemoryMB: Math.round(os.totalmem() / (1024 * 1024)),
      processMemoryMB: {
        rss: Math.round(memoryUsage.rss / (1024 * 1024)),
        heapUsed: Math.round(memoryUsage.heapUsed / (1024 * 1024)),
        heapTotal: Math.round(memoryUsage.heapTotal / (1024 * 1024)),
      },
    },
  };

  res.status(200).json(healthData);
});

export default router;

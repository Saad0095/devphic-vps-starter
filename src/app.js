import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import config from './config.js';
import healthRouter from './routes/health.js';
import apiRouter from './routes/api.js';
import notFoundHandler from './middleware/notFoundHandler.js';
import errorHandler from './middleware/errorHandler.js';

export function createApp() {
  const app = express();

  // Enable reverse proxy trust (Nginx sets X-Forwarded-For and X-Forwarded-Proto)
  if (config.trustProxy) {
    app.set('trust proxy', 1);
  }

  // Security HTTP headers
  app.use(
    helmet({
      contentSecurityPolicy: false, // Allows clean integration if serving APIs or hybrid UI
      crossOriginEmbedderPolicy: false,
    })
  );

  // CORS configuration
  app.use(
    cors({
      origin: config.corsOrigin === '*' ? '*' : config.corsOrigin.split(','),
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    })
  );

  // Body parsers
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true, limit: '1mb' }));

  // Minimal non-blocking request logger
  app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
      const duration = Date.now() - start;
      // Skip health check logging to keep logs clean in production
      if (req.path !== '/health') {
        console.log(`[HTTP] ${req.method} ${req.originalUrl} ${res.statusCode} - ${duration}ms (IP: ${req.ip})`);
      }
    });
    next();
  });

  // Health probe endpoints (accessible at both /health and /api/health)
  app.use('/', healthRouter);
  app.use('/api', healthRouter);

  // Root landing info endpoint
  app.get('/', (_req, res) => {
    res.json({
      name: config.appName,
      version: config.appVersion,
      status: 'operational',
      health: '/health',
      api: '/api',
      serverTime: new Date().toISOString(),
      message: 'Devphic VPS Starter is up and running securely on your Ubuntu VPS.',
    });
  });

  // API router
  app.use('/api', apiRouter);

  // 404 Not Found Handler
  app.use(notFoundHandler);

  // Centralized Error Handler
  app.use(errorHandler);

  return app;
}

export const app = createApp();
export default app;

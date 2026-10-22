import dotenv from 'dotenv';

// Load environment variables from .env file if present
dotenv.config();

export const config = {
  env: process.env.NODE_ENV || 'development',
  isProduction: process.env.NODE_ENV === 'production',
  port: parseInt(process.env.PORT, 10) || 3000,
  host: process.env.HOST || '0.0.0.0',
  appName: process.env.APP_NAME || 'Devphic VPS Starter API',
  appVersion: process.env.APP_VERSION || '1.0.0',
  corsOrigin: process.env.CORS_ORIGIN || '*',
  trustProxy: process.env.TRUST_PROXY === 'true' || process.env.TRUST_PROXY === '1' || true,
  shutdownTimeoutMs: parseInt(process.env.SHUTDOWN_TIMEOUT_MS, 10) || 10000,
};

export default config;

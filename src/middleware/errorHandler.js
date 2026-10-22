import config from '../config.js';

/**
 * Global centralized error handling middleware.
 * Ensures consistent JSON responses and hides stack traces in production.
 */
export function errorHandler(err, req, res, _next) {
  const statusCode = err.statusCode || err.status || 500;
  const message = err.message || 'Internal Server Error';

  // Structured logging for observability
  console.error(`[ERROR] ${new Date().toISOString()} - ${req.method} ${req.originalUrl}:`, {
    status: statusCode,
    message: err.message,
    stack: config.isProduction ? undefined : err.stack,
  });

  res.status(statusCode).json({
    success: false,
    error: {
      message,
      status: statusCode,
      ...(config.isProduction ? {} : { stack: err.stack }),
    },
    timestamp: new Date().toISOString(),
  });
}

export default errorHandler;

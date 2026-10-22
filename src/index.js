import http from 'http';
import app from './app.js';
import config from './config.js';

const server = http.createServer(app);

// Track active connections for graceful termination
const connections = new Set();
server.on('connection', (connection) => {
  connections.add(connection);
  connection.on('close', () => {
    connections.delete(connection);
  });
});

// Start listening
server.listen(config.port, config.host, () => {
  console.log(`=======================================================`);
  console.log(`🚀 ${config.appName} (v${config.appVersion}) is running`);
  console.log(`📡 URL: http://${config.host}:${config.port}`);
  console.log(`🏥 Health check: http://${config.host}:${config.port}/health`);
  console.log(`⚙️  Environment: ${config.env}`);
  console.log(`=======================================================`);
});

// Flag to prevent multiple simultaneous shutdown attempts
let isShuttingDown = false;

function gracefulShutdown(signal) {
  return () => {
    if (isShuttingDown) {
      console.log(`[SHUTDOWN] Shutdown already in progress. Ignoring signal ${signal}.`);
      return;
    }
    isShuttingDown = true;
    console.log(`\n[SHUTDOWN] Received ${signal}. Starting graceful shutdown...`);

    // 1. Stop accepting new incoming HTTP connections
    server.close((err) => {
      if (err) {
        console.error('[SHUTDOWN] Error during HTTP server close:', err);
        process.exit(1);
      }
      console.log('[SHUTDOWN] HTTP server closed cleanly. No new connections accepted.');
      process.exit(0);
    });

    // 2. Set hard timeout for existing in-flight connections
    const forceTimer = setTimeout(() => {
      console.warn(`[SHUTDOWN] Force closing remaining ${connections.size} connection(s) after timeout (${config.shutdownTimeoutMs}ms)...`);
      for (const connection of connections) {
        connection.destroy();
      }
      process.exit(1);
    }, config.shutdownTimeoutMs);

    // Prevent timeout timer from keeping Node event loop artificially alive if connections close early
    if (forceTimer.unref) {
      forceTimer.unref();
    }
  };
}

// Register OS signals
process.on('SIGTERM', gracefulShutdown('SIGTERM'));
process.on('SIGINT', gracefulShutdown('SIGINT'));

// Process-wide unhandled rejection & exception handlers
process.on('unhandledRejection', (reason, promise) => {
  console.error('[PROCESS] Unhandled Rejection at:', promise, 'reason:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('[PROCESS] Uncaught Exception:', error);
  // Uncaught exceptions leave application state unstable, initiate graceful shutdown
  const shutdown = gracefulShutdown('uncaughtException');
  shutdown();
});

export default server;

/**
 * 404 Not Found Middleware for unmapped routes.
 */
export function notFoundHandler(req, res, _next) {
  res.status(404).json({
    success: false,
    error: {
      message: `Cannot ${req.method} ${req.originalUrl}`,
      status: 404,
    },
    timestamp: new Date().toISOString(),
  });
}

export default notFoundHandler;

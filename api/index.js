/**
 * Single entry for all /api/* on Vercel. Rewrites send /api/:path* here with query path=:path*.
 */
export { default } from './[[...path]].js';

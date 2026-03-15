import { neon } from '@neondatabase/serverless';

const connectionString = process.env.POSTGRES_URL || process.env.DATABASE_URL;
export const sql = connectionString ? neon(connectionString) : null;

export function hasDb() {
  return !!connectionString;
}

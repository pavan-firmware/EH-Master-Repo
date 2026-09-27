/**
 * Drizzle ORM Configuration
 * Defines schema sources and future migration output directories.
 */

export default {
  schema: './src/schema/index.ts',
  out: './drizzle',
  dialect: 'postgresql',
  dbCredentials: {
    url: process.env.DATABASE_URL || 'postgresql://eh_user:eh_password@localhost:5432/eh_home',
  },
  strict: true,
  verbose: true,
};

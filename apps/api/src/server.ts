/**
 * EH Home API Server Process Entrypoint
 * Handles process lifecycle, network listening, and graceful termination.
 */

import dotenv from 'dotenv';
import path from 'node:path';

// The workspace .env lives at the repository root, while pnpm may execute
// this package with apps/api as the current directory.
dotenv.config({ path: path.resolve(__dirname, '../../../.env') });
dotenv.config();
import { buildApp } from './app';
import { loadConfig } from './config';

async function main(): Promise<void> {
  // The legacy backend owns PORT (3000). Keep this modular API isolated on
  // API_PORT so both services can run together without EADDRINUSE.
  const config = loadConfig({ PORT: process.env.API_PORT });

  const app = await buildApp({ config });

  // Graceful Shutdown
  const signals: NodeJS.Signals[] = ['SIGINT', 'SIGTERM'];
  for (const signal of signals) {
    process.on(signal, async () => {
      app.log.info({ signal }, 'Received termination signal, shutting down gracefully...');
      try {
        await app.close();
        app.log.info('Server shutdown completed successfully.');
        process.exit(0);
      } catch (err) {
        app.log.error({ err }, 'Error occurred during server shutdown');
        process.exit(1);
      }
    });
  }

  try {
    const address = await app.listen({
      host: config.HOST,
      port: config.PORT,
    });
    app.log.info(`EH Home API listening on ${address} [env: ${config.NODE_ENV}]`);
  } catch (err) {
    app.log.fatal({ err }, 'Failed to start API server');
    process.exit(1);
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error('Fatal initialization error:', err);
    process.exit(1);
  });
}

export { main };

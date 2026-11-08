"use strict";
/**
 * EH Home API Server Process Entrypoint
 * Handles process lifecycle, network listening, and graceful termination.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.main = main;
const dotenv_1 = __importDefault(require("dotenv"));
const node_path_1 = __importDefault(require("node:path"));
// The workspace .env lives at the repository root, while pnpm may execute
// this package with apps/api as the current directory.
dotenv_1.default.config({ path: node_path_1.default.resolve(__dirname, '../../../.env') });
dotenv_1.default.config();
const app_1 = require("./app");
const config_1 = require("./config");
async function main() {
    // The legacy backend owns PORT (3000). Keep this modular API isolated on
    // API_PORT so both services can run together without EADDRINUSE.
    const config = (0, config_1.loadConfig)({ PORT: process.env.API_PORT });
    const app = await (0, app_1.buildApp)({ config });
    // Graceful Shutdown
    const signals = ['SIGINT', 'SIGTERM'];
    for (const signal of signals) {
        process.on(signal, async () => {
            app.log.info({ signal }, 'Received termination signal, shutting down gracefully...');
            try {
                await app.close();
                app.log.info('Server shutdown completed successfully.');
                process.exit(0);
            }
            catch (err) {
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
    }
    catch (err) {
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
//# sourceMappingURL=server.js.map
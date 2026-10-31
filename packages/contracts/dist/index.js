"use strict";
/**
 * EH Home Canonical Shared Contracts
 *
 * TypeScript + Zod Runtime Validation & Static Types
 * Single source of truth for apps/api, apps/desktop, mobile clients, and tooling.
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateBenchArtifact = void 0;
__exportStar(require("./common"), exports);
__exportStar(require("./product"), exports);
__exportStar(require("./hardware"), exports);
__exportStar(require("./firmware"), exports);
__exportStar(require("./device"), exports);
__exportStar(require("./production"), exports);
__exportStar(require("./qr"), exports);
__exportStar(require("./packing"), exports);
__exportStar(require("./provisioning"), exports);
var provisioning_1 = require("./provisioning");
Object.defineProperty(exports, "validateBenchArtifact", { enumerable: true, get: function () { return provisioning_1.validateBenchArtifact; } });
__exportStar(require("./mqtt"), exports);
__exportStar(require("./telemetry"), exports);
__exportStar(require("./ota"), exports);
__exportStar(require("./security"), exports);
__exportStar(require("./audit"), exports);
__exportStar(require("./storage"), exports);
//# sourceMappingURL=index.js.map
"use strict";
/**
 * EH Home API Domain Modules Registry
 *
 * Establishes the modular-monolith domain boundaries.
 * In PART 03, the foundational system module is active.
 * Subsequent parts register their domain routes into this structure.
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
__exportStar(require("./system/system.routes"), exports);
__exportStar(require("./system/system.service"), exports);
__exportStar(require("./system/system.schema"), exports);
__exportStar(require("./products"), exports);
__exportStar(require("./hardware"), exports);
__exportStar(require("./firmware"), exports);
__exportStar(require("./inventory"), exports);
__exportStar(require("./mqtt"), exports);
__exportStar(require("./telemetry"), exports);
__exportStar(require("./commands"), exports);
__exportStar(require("./ota"), exports);
__exportStar(require("./security/security.service"), exports);
__exportStar(require("./security/security.repository"), exports);
__exportStar(require("./security/security.routes"), exports);
__exportStar(require("./audit/audit.service"), exports);
__exportStar(require("./audit/audit.repository"), exports);
__exportStar(require("./audit/audit.routes"), exports);
__exportStar(require("./storage/storage.interface"), exports);
__exportStar(require("./storage/storage.service"), exports);
__exportStar(require("./storage/storage.routes"), exports);
__exportStar(require("./storage/providers/memory-storage.provider"), exports);
__exportStar(require("./storage/providers/s3-storage.provider"), exports);
__exportStar(require("./backup/backup.interface"), exports);
__exportStar(require("./backup/backup.service"), exports);
__exportStar(require("./backup/restore.service"), exports);
__exportStar(require("./backup/backup.routes"), exports);
__exportStar(require("./backup/postgres-backup.engine"), exports);
//# sourceMappingURL=index.js.map
/**
 * Operations Audit Service
 *
 * Provides high-level APIs for:
 * 1. Emitting sanitized OperationalEvents across all subsystems
 * 2. Logging tamper-evident SecurityAuditRecords with hash-chaining
 * 3. Verifying cryptographic chain integrity
 * 4. Querying audit trails with role-scoped access
 */

const { AuditRedactionService } = require('./audit-redaction.service');

class OperationsAuditService {
  constructor({ operationalEventRepo, securityAuditRepo, auditRepo }) {
    this.operationalEventRepo = operationalEventRepo;
    this.securityAuditRepo = securityAuditRepo;
    this.auditRepo = auditRepo; // Existing Phase 2 general audit_logs
  }

  /**
   * Log an operational event. Automatically redacts sensitive fields.
   */
  async logOperationalEvent(eventData) {
    const { sanitized: sanitizedMetadata, markers: metaMarkers } = AuditRedactionService.redact(eventData.metadata || {});
    
    // Check top-level action/payload if present
    const markers = [...metaMarkers];

    const eventRecord = {
      ...eventData,
      metadata: sanitizedMetadata,
      redactionMarkers: markers
    };

    return this.operationalEventRepo.create(eventRecord);
  }

  /**
   * Log a security-critical transition into the tamper-evident hash-chained log.
   * STRICT BOUNDARY: Only security-sensitive events (auth burst, elevation, policy, reset, tamper)
   * are recorded here. General domain actions remain in audit_logs.
   */
  async logSecurityAuditRecord({
    id,
    actorUserId = null,
    homeId = null,
    deviceId = null,
    action,
    resourceType,
    resourceId = null,
    outcome = 'SUCCESS',
    ipAddress = null,
    correlationId = null,
    payload = {},
    metadata = {}
  }) {
    const { sanitized: sanitizedPayload, markers: pMarkers } = AuditRedactionService.redact(payload);
    const { sanitized: sanitizedMeta, markers: mMarkers } = AuditRedactionService.redact(metadata);

    const mergedMeta = {
      ...sanitizedMeta,
      redactionMarkers: [...pMarkers, ...mMarkers]
    };

    return this.securityAuditRepo.appendRecord({
      id,
      actorUserId,
      homeId,
      deviceId,
      action,
      resourceType,
      resourceId,
      outcome,
      ipAddress,
      correlationId,
      canonicalPayload: sanitizedPayload,
      metadata: mergedMeta
    });
  }

  /**
   * Verify the entire cryptographic hash chain
   */
  async verifyChainIntegrity() {
    return this.securityAuditRepo.verifyChainIntegrity();
  }

  /**
   * Query operational events with role-based scoping
   */
  async getOperationalEvents(filters) {
    return this.operationalEventRepo.findEvents(filters);
  }

  /**
   * Query security audit records with role-based scoping
   */
  async getSecurityAuditRecords(filters) {
    return this.securityAuditRepo.findRecords(filters);
  }
}

module.exports = { OperationsAuditService };

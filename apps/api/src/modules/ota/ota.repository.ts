import { OtaManifest } from '@eh-home/contracts';
import { randomUUID } from 'crypto';

export interface IOtaRepository {
  registerRelease(manifest: OtaManifest, additional?: any): Promise<void>;
  getReleaseById(releaseId: string): Promise<any | null>;
  findReleasesForVariant(productVariantId: string, hardwareRevision?: string): Promise<any[]>;
  createOtaJob(job: any): Promise<any>;
  updateOtaJob(jobId: string, updates: any): Promise<any | null>;
  getOtaJob(jobId: string): Promise<any | null>;
  getLatestDeviceJob(deviceId: string): Promise<any | null>;
}

export class OtaRepository implements IOtaRepository {
  private db: any;
  private releasesStore: Map<string, any> = new Map();
  private jobsStore: Map<string, any> = new Map();

  constructor(db?: any) {
    this.db = db;
  }

  public async registerRelease(manifest: OtaManifest, additional: any = {}): Promise<void> {
    const record = {
      id: manifest.releaseId,
      productVariantId: manifest.productVariantId,
      hardwareRevision: manifest.hardwareRevision,
      firmwareFamily: additional.firmwareFamily || 'esp32c6-switch-platform',
      version: manifest.version,
      minFirmwareVersion: manifest.minFirmwareVersion,
      releaseChannel: additional.releaseChannel || 'production',
      binarySizeBytes: manifest.binarySizeBytes,
      sha256: manifest.sha256,
      ed25519Signature: manifest.ed25519Signature,
      downloadUrl: manifest.downloadUrl,
      releaseNotes: manifest.releaseNotes || null,
      status: 'status' in additional ? additional.status : 'RELEASED',
      createdAt: manifest.createdAt,
      releasedAt: manifest.createdAt
    };

    if (!this.db || !this.db.insert) {
      this.releasesStore.set(manifest.releaseId, record);
      return;
    }

    const { firmwareReleases } = require('@eh-home/db-schema');
    await this.db.insert(firmwareReleases).values(record);
  }

  public async getReleaseById(releaseId: string): Promise<any | null> {
    if (!this.db || !this.db.select) {
      return this.releasesStore.get(releaseId) || null;
    }

    const { firmwareReleases, eq } = require('@eh-home/db-schema');
    const rows = await this.db.select().from(firmwareReleases).where(eq(firmwareReleases.id, releaseId)).limit(1);
    return rows.length > 0 ? rows[0] : null;
  }

  public async findReleasesForVariant(productVariantId: string, hardwareRevision?: string): Promise<any[]> {
    if (!this.db || !this.db.select) {
      const all = Array.from(this.releasesStore.values());
      return all.filter((r) => {
        if (r.productVariantId !== productVariantId) return false;
        if (hardwareRevision && r.hardwareRevision && r.hardwareRevision !== hardwareRevision) return false;
        return true;
      });
    }

    const { firmwareReleases, eq, and } = require('@eh-home/db-schema');
    const conditions = [eq(firmwareReleases.productVariantId, productVariantId)];
    if (hardwareRevision) {
      conditions.push(eq(firmwareReleases.hardwareRevision, hardwareRevision));
    }

    return this.db.select().from(firmwareReleases).where(and(...conditions));
  }

  public async createOtaJob(job: any): Promise<any> {
    const record = {
      id: job.id || randomUUID(),
      deviceId: job.deviceId,
      releaseId: job.releaseId,
      rolloutId: job.rolloutId || null,
      firmwareFamily: job.firmwareFamily,
      targetVersion: job.targetVersion,
      fromVersion: job.fromVersion,
      status: job.status || 'REQUESTED',
      progressPercent: job.progressPercent || 0,
      errorCode: null,
      errorMessage: null,
      sha256: job.sha256,
      ed25519Signature: job.ed25519Signature,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      completedAt: null
    };

    if (!this.db || !this.db.insert) {
      this.jobsStore.set(record.id, record);
      return record;
    }

    const { otaExecutionJobs } = require('@eh-home/db-schema');
    await this.db.insert(otaExecutionJobs).values({
      ...record,
      createdAt: new Date(),
      updatedAt: new Date(),
      completedAt: null
    });
    return record;
  }

  public async updateOtaJob(jobId: string, updates: any): Promise<any | null> {
    if (!this.db || !this.db.update) {
      const existing = this.jobsStore.get(jobId);
      if (!existing) return null;
      const updated = {
        ...existing,
        ...updates,
        updatedAt: new Date().toISOString()
      };
      if (['SUCCEEDED', 'FAILED', 'ROLLED_BACK', 'CANCELLED'].includes(updates.status)) {
        updated.completedAt = new Date().toISOString();
      }
      this.jobsStore.set(jobId, updated);
      return updated;
    }

    const { otaExecutionJobs, eq } = require('@eh-home/db-schema');
    const dbUpdates: any = {
      ...updates,
      updatedAt: new Date()
    };
    if (['SUCCEEDED', 'FAILED', 'ROLLED_BACK', 'CANCELLED'].includes(updates.status)) {
      dbUpdates.completedAt = new Date();
    }
    await this.db.update(otaExecutionJobs).set(dbUpdates).where(eq(otaExecutionJobs.id, jobId));
    return this.getOtaJob(jobId);
  }

  public async getOtaJob(jobId: string): Promise<any | null> {
    if (!this.db || !this.db.select) {
      return this.jobsStore.get(jobId) || null;
    }

    const { otaExecutionJobs, eq } = require('@eh-home/db-schema');
    const rows = await this.db.select().from(otaExecutionJobs).where(eq(otaExecutionJobs.id, jobId)).limit(1);
    return rows.length > 0 ? rows[0] : null;
  }

  public async getLatestDeviceJob(deviceId: string): Promise<any | null> {
    if (!this.db || !this.db.select) {
      const list = Array.from(this.jobsStore.values()).filter((j) => j.deviceId === deviceId);
      return list.length > 0 ? list[list.length - 1] : null;
    }

    const { otaExecutionJobs, eq, desc } = require('@eh-home/db-schema');
    const rows = await this.db
      .select()
      .from(otaExecutionJobs)
      .where(eq(otaExecutionJobs.deviceId, deviceId))
      .orderBy(desc(otaExecutionJobs.createdAt))
      .limit(1);
    return rows.length > 0 ? rows[0] : null;
  }
}

'use strict';

/**
 * EH Home — Synchronization, Reconciliation & Export API Router (Phase 17)
 */

class SyncApiRouter {
  constructor({ syncService, dataExportService, dataRetentionService }) {
    this.syncService = syncService;
    this.dataExportService = dataExportService;
    this.dataRetentionService = dataRetentionService;
  }

  async handleBootstrap(req, res) {
    try {
      const userId = req.actorContext ? req.actorContext.userId : (req.user ? req.user.id : null);
      if (!userId) {
        return res.status(401).json({ success: false, error: 'Unauthorized: Authentication required' });
      }

      const homeId = req.query ? req.query.homeId : null;
      const clientDeviceId = (req.query && req.query.clientDeviceId) || 'mobile_client';

      const bundle = await this.syncService.getBootstrapBundle(userId, homeId, clientDeviceId);
      return res.status(200).json({
        success: true,
        data: bundle,
        timestamp: new Date().toISOString()
      });
    } catch (err) {
      if (err.message.includes('not found') || err.message.includes('not a member')) {
        return res.status(404).json({ success: false, error: err.message });
      }
      return res.status(500).json({ success: false, error: err.message });
    }
  }

  async handleReconcile(req, res) {
    try {
      const userId = req.actorContext ? req.actorContext.userId : (req.user ? req.user.id : null);
      if (!userId) {
        return res.status(401).json({ success: false, error: 'Unauthorized: Authentication required' });
      }

      const { homeId, mutations = [] } = req.body || {};
      if (!homeId) {
        return res.status(400).json({ success: false, error: 'Missing required field: homeId' });
      }

      const result = await this.syncService.reconcilePendingChanges(userId, homeId, mutations);
      return res.status(200).json({
        success: true,
        data: result,
        timestamp: new Date().toISOString()
      });
    } catch (err) {
      if (err.message.includes('Authorization failed')) {
        return res.status(403).json({ success: false, error: err.message });
      }
      return res.status(500).json({ success: false, error: err.message });
    }
  }

  async handleExport(req, res) {
    try {
      const userId = req.actorContext ? req.actorContext.userId : (req.user ? req.user.id : null);
      if (!userId) {
        return res.status(401).json({ success: false, error: 'Unauthorized: Authentication required' });
      }

      const homeId = req.query ? req.query.homeId : null;
      let bundle;
      if (homeId) {
        bundle = await this.dataExportService.exportHomeData(userId, homeId);
      } else {
        bundle = await this.dataExportService.exportUserData(userId);
      }

      return res.status(200).json({
        success: true,
        data: bundle,
        timestamp: new Date().toISOString()
      });
    } catch (err) {
      if (err.message.includes('Authorization failed')) {
        return res.status(403).json({ success: false, error: err.message });
      }
      if (err.message.includes('not found')) {
        return res.status(404).json({ success: false, error: err.message });
      }
      return res.status(500).json({ success: false, error: err.message });
    }
  }
}

module.exports = { SyncApiRouter };

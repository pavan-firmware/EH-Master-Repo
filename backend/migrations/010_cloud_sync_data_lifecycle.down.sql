-- EH Home — Migration 010: Cloud Sync, Backup, Restore, Offline Reconciliation & Data Lifecycle (DOWN)

DROP TABLE IF EXISTS data_export_records CASCADE;
DROP TABLE IF EXISTS pending_change_audits CASCADE;
DROP TABLE IF EXISTS sync_checkpoints CASCADE;

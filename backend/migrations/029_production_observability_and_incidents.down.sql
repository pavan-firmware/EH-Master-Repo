-- Migration 029: Production Observability, Monitoring and Incidents (DOWN)
-- Rollback tables created in 029_production_observability_and_incidents.sql

DROP TABLE IF EXISTS platform_alerts CASCADE;
DROP TABLE IF EXISTS platform_incidents CASCADE;

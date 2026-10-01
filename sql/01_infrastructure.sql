-- ============================================================
-- 01_infrastructure.sql
-- Supply Chain Ontology - Infrastructure Setup
-- ============================================================

-- Database
CREATE OR REPLACE DATABASE SC_ONTOLOGY
  COMMENT = 'Supply Chain Industry Ontology - Governed semantic layer for cross-domain analytics';

-- Schemas
CREATE SCHEMA SC_ONTOLOGY.RAW
  COMMENT = 'Source tables simulating ERP, logistics, supplier, and IoT systems';

CREATE SCHEMA SC_ONTOLOGY.ANALYTICS
  COMMENT = 'Governed semantic layer - ontology-encoded semantic views and conversational agent';

CREATE SCHEMA SC_ONTOLOGY.DOCUMENTS
  COMMENT = 'Unstructured knowledge base - contracts, policies, quality reports';

-- Use existing warehouse
USE WAREHOUSE COMPUTE_WH;

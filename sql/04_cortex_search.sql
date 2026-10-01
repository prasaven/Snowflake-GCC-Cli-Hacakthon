-- ============================================================
-- 04_cortex_search.sql
-- Cortex Search Service over Supply Chain Knowledge Base
-- ============================================================

USE DATABASE SC_ONTOLOGY;

CREATE OR REPLACE CORTEX SEARCH SERVICE SC_ONTOLOGY.DOCUMENTS.SC_KNOWLEDGE_SEARCH
  ON content
  ATTRIBUTES category, doc_type, related_entity
  WAREHOUSE = COMPUTE_WH
  TARGET_LAG = '1 hour'
  AS (
    SELECT 
        doc_id,
        doc_type,
        title,
        content,
        category,
        related_entity,
        effective_date
    FROM SC_ONTOLOGY.DOCUMENTS.SUPPLY_CHAIN_KNOWLEDGE
  );

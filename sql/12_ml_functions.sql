-- ============================================================
-- 12_ml_functions.sql
-- Snowflake ML Functions: FORECAST, ANOMALY_DETECTION, CLASSIFY
-- ============================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA ADVANCED;

-- ============================================================
-- ML FORECAST: Predict future order volumes
-- ============================================================

-- Training data: daily order counts
CREATE OR REPLACE VIEW V_DAILY_ORDERS_SIMPLE AS
SELECT order_date AS ds, COUNT(*)::FLOAT AS order_count
FROM SC_ONTOLOGY.RAW.ORDERS
WHERE order_date IS NOT NULL
GROUP BY order_date
ORDER BY ds;

-- Train the forecast model
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST ORDER_VOLUME_FORECAST(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'SC_ONTOLOGY.ADVANCED.V_DAILY_ORDERS_SIMPLE'),
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'ORDER_COUNT'
);

-- Generate 30-day forecast
CALL ORDER_VOLUME_FORECAST!FORECAST(FORECASTING_PERIODS => 30);

-- ============================================================
-- ML ANOMALY DETECTION: Detect unusual order patterns
-- ============================================================

CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION ORDER_ANOMALY_DETECTOR(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'SC_ONTOLOGY.ADVANCED.V_DAILY_ORDERS_SIMPLE'),
    TIMESTAMP_COLNAME => 'DS',
    TARGET_COLNAME => 'ORDER_COUNT',
    LABEL_COLNAME => ''
);

-- To detect anomalies on new data:
-- CALL ORDER_ANOMALY_DETECTOR!DETECT_ANOMALIES(
--     INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'new_data_view'),
--     TIMESTAMP_COLNAME => 'DS',
--     TARGET_COLNAME => 'ORDER_COUNT'
-- );

-- ============================================================
-- CORTEX AI: Supplier Classification (CLASSIFY_TEXT)
-- ============================================================

CREATE OR REPLACE VIEW V_SUPPLIER_AI_CLASSIFICATION AS
SELECT 
    supplier_id, supplier_name, supplier_tier, quality_score, lead_time_days, status,
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        'Supplier: ' || supplier_name || '. Quality: ' || quality_score::VARCHAR || '/100. Lead time: ' || lead_time_days::VARCHAR || ' days. Status: ' || status || '. Tier: ' || supplier_tier,
        ARRAY_CONSTRUCT('Strategic Partner', 'Reliable Performer', 'Improvement Needed', 'At Risk', 'Critical Intervention')
    ):label::VARCHAR AS ai_risk_class
FROM SC_ONTOLOGY.RAW.SUPPLIERS
WHERE supplier_id <= 20;

-- ============================================================
-- CORTEX AI: Document Sentiment Analysis
-- ============================================================

CREATE OR REPLACE VIEW V_DOCUMENT_SENTIMENT AS
SELECT doc_id, title, doc_type, category, related_entity,
    SNOWFLAKE.CORTEX.SENTIMENT(content) AS sentiment_score,
    CASE WHEN SNOWFLAKE.CORTEX.SENTIMENT(content) > 0.3 THEN 'Positive'
         WHEN SNOWFLAKE.CORTEX.SENTIMENT(content) < -0.3 THEN 'Negative'
         ELSE 'Neutral' END AS sentiment_category
FROM SC_ONTOLOGY.DOCUMENTS.SUPPLY_CHAIN_KNOWLEDGE;

-- ============================================================
-- CORTEX AI: Auto-Summarize + Classify Documents
-- ============================================================

CREATE OR REPLACE VIEW V_DOCUMENT_AI_ENRICHED AS
SELECT doc_id, title, doc_type, category, related_entity,
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(content, 
        ARRAY_CONSTRUCT('Urgent Action Required', 'Risk Warning', 'Standard Process', 'Positive Performance', 'Compliance Notice')
    ):label::VARCHAR AS ai_classification,
    SNOWFLAKE.CORTEX.SUMMARIZE(content) AS ai_summary
FROM SC_ONTOLOGY.DOCUMENTS.SUPPLY_CHAIN_KNOWLEDGE;

-- ============================================================
-- CORTEX AI: LLM-Powered Supplier Risk Summary
-- ============================================================

CREATE OR REPLACE FUNCTION AI_SUPPLIER_SUMMARY(p_supplier_name VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS $$
    SELECT SNOWFLAKE.CORTEX.COMPLETE('claude-haiku-4-5',
        'You are a supply chain risk analyst. Summarize the risk profile of supplier "' || p_supplier_name || '" based on: ' ||
        (SELECT LISTAGG('Supplier: ' || supplier_name || ', Tier: ' || supplier_tier || 
            ', Quality: ' || quality_score::VARCHAR || '/100, Lead Time: ' || lead_time_days::VARCHAR || ' days, Status: ' || status, '; ')
         FROM SC_ONTOLOGY.RAW.SUPPLIERS WHERE supplier_name ILIKE '%' || p_supplier_name || '%') ||
        '. Provide 2-3 sentence executive summary with risk level and recommended actions.')
$$;

-- Test:
-- SELECT AI_SUPPLIER_SUMMARY('Quantum Plastics');
-- SELECT AI_SUPPLIER_SUMMARY('Apex Manufacturing');

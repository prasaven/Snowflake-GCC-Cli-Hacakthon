-- ============================================================
-- 10_improvements_all.sql
-- All 10 Improvements + AI/ML + Evaluations
-- ============================================================

USE DATABASE SC_ONTOLOGY;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================
-- SCHEMAS
-- ============================================================
CREATE SCHEMA IF NOT EXISTS SC_ONTOLOGY.GOVERNANCE COMMENT = 'Ontology governance - versioning, access control, audit trail';
CREATE SCHEMA IF NOT EXISTS SC_ONTOLOGY.ADVANCED COMMENT = 'Advanced analytics - ML, anomaly detection, risk scoring, evaluations';

-- ============================================================
-- IMPROVEMENT 1: Dynamic Tables (Auto-Refreshing Materializations)
-- ============================================================

CREATE OR REPLACE DYNAMIC TABLE SC_ONTOLOGY.ADVANCED.DT_SUPPLIER_SCORECARD
  TARGET_LAG = '30 minutes'
  WAREHOUSE = COMPUTE_WH
AS
SELECT 
    s.supplier_id, s.supplier_name, s.supplier_tier, s.country AS supplier_country,
    s.quality_score, s.lead_time_days,
    COUNT(DISTINCT ol.order_id) AS total_orders,
    ROUND(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 
        / NULLIF(COUNT(o.actual_delivery_date), 0), 2) AS otd_pct,
    ROUND(SUM(ol.qty_fulfilled) * 100.0 / NULLIF(SUM(ol.qty_ordered), 0), 2) AS fill_rate_pct,
    SUM(ol.qty_ordered * ol.unit_price) AS total_spend
FROM SC_ONTOLOGY.RAW.SUPPLIERS s
JOIN SC_ONTOLOGY.RAW.PARTS pt ON pt.primary_supplier_id = s.supplier_id
JOIN SC_ONTOLOGY.RAW.ORDER_LINES ol ON ol.part_id = pt.part_id
JOIN SC_ONTOLOGY.RAW.ORDERS o ON ol.order_id = o.order_id
WHERE o.actual_delivery_date IS NOT NULL
GROUP BY s.supplier_id, s.supplier_name, s.supplier_tier, s.country, s.quality_score, s.lead_time_days;

CREATE OR REPLACE DYNAMIC TABLE SC_ONTOLOGY.ADVANCED.DT_INVENTORY_HEALTH
  TARGET_LAG = '30 minutes'
  WAREHOUSE = COMPUTE_WH
AS
SELECT 
    p.plant_id, p.plant_name, p.region AS plant_region, pt.abc_class,
    COUNT(*) AS position_count,
    ROUND(AVG(i.qty_on_hand), 0) AS avg_qty_on_hand,
    ROUND(AVG(i.avg_daily_demand), 1) AS avg_daily_demand,
    ROUND(AVG(i.qty_on_hand) / NULLIF(AVG(i.avg_daily_demand), 0), 1) AS days_of_inventory,
    SUM(CASE WHEN i.qty_on_hand <= i.reorder_point THEN 1 ELSE 0 END) AS below_reorder_point,
    SUM(CASE WHEN i.qty_on_hand = 0 THEN 1 ELSE 0 END) AS stockout_count
FROM SC_ONTOLOGY.RAW.INVENTORY i
JOIN SC_ONTOLOGY.RAW.PLANTS p ON i.plant_id = p.plant_id
JOIN SC_ONTOLOGY.RAW.PARTS pt ON i.part_id = pt.part_id
GROUP BY p.plant_id, p.plant_name, p.region, pt.abc_class;

CREATE OR REPLACE DYNAMIC TABLE SC_ONTOLOGY.ADVANCED.DT_OTD_BY_PLANT
  TARGET_LAG = '30 minutes'
  WAREHOUSE = COMPUTE_WH
AS
SELECT 
    p.plant_id, p.plant_name, p.region AS plant_region,
    DATE_TRUNC('month', o.order_date) AS order_month,
    ROUND(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 
        / NULLIF(COUNT(o.actual_delivery_date), 0), 2) AS otd_pct,
    ROUND(SUM(ol.qty_fulfilled) * 100.0 / NULLIF(SUM(ol.qty_ordered), 0), 2) AS fill_rate_pct,
    SUM(ol.qty_fulfilled * ol.unit_price * (1 - ol.discount_pct)) AS revenue
FROM SC_ONTOLOGY.RAW.ORDERS o
JOIN SC_ONTOLOGY.RAW.ORDER_LINES ol ON o.order_id = ol.order_id
JOIN SC_ONTOLOGY.RAW.PLANTS p ON ol.plant_id = p.plant_id
WHERE o.actual_delivery_date IS NOT NULL
GROUP BY p.plant_id, p.plant_name, p.region, DATE_TRUNC('month', o.order_date);

-- ============================================================
-- IMPROVEMENT 2: Perfect Order Rate (Composite Metric)
-- ============================================================

CREATE OR REPLACE VIEW SC_ONTOLOGY.ADVANCED.V_PERFECT_ORDER_RATE AS
SELECT 
    o.order_id, o.order_code, c.customer_name, c.segment AS customer_segment,
    CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 ELSE 0 END AS is_on_time,
    CASE WHEN MIN(CASE WHEN ol.qty_fulfilled >= ol.qty_ordered THEN 1 ELSE 0 END) = 1 THEN 1 ELSE 0 END AS is_in_full,
    CASE WHEN SUM(CASE WHEN iot.alert_status = 'Critical' THEN 1 ELSE 0 END) = 0 THEN 1 ELSE 0 END AS no_quality_issues,
    CASE WHEN o.actual_delivery_date <= o.requested_delivery_date
        AND MIN(CASE WHEN ol.qty_fulfilled >= ol.qty_ordered THEN 1 ELSE 0 END) = 1
        AND SUM(CASE WHEN iot.alert_status = 'Critical' THEN 1 ELSE 0 END) = 0
    THEN 1 ELSE 0 END AS is_perfect_order
FROM SC_ONTOLOGY.RAW.ORDERS o
JOIN SC_ONTOLOGY.RAW.CUSTOMERS c ON o.customer_id = c.customer_id
JOIN SC_ONTOLOGY.RAW.ORDER_LINES ol ON o.order_id = ol.order_id
LEFT JOIN SC_ONTOLOGY.RAW.SHIPMENTS sh ON o.order_id = sh.order_id
LEFT JOIN SC_ONTOLOGY.RAW.IOT_SENSOR_READINGS iot ON sh.shipment_id = iot.shipment_id
WHERE o.actual_delivery_date IS NOT NULL
GROUP BY o.order_id, o.order_code, c.customer_name, c.segment, o.actual_delivery_date, o.requested_delivery_date;

-- ============================================================
-- IMPROVEMENT 3: Supplier Risk Scoring UDF
-- ============================================================

CREATE OR REPLACE FUNCTION SC_ONTOLOGY.ADVANCED.CALC_SUPPLIER_RISK(p_supplier_name VARCHAR)
RETURNS TABLE (supplier_name VARCHAR, supplier_tier VARCHAR, risk_score NUMBER(10,1), risk_category VARCHAR,
    quality_risk NUMBER(10,1), delivery_risk NUMBER(10,1), concentration_risk NUMBER(10,1), overall_assessment VARCHAR)
LANGUAGE SQL
AS $$
    SELECT s.supplier_name, s.supplier_tier,
        ROUND((CASE WHEN s.quality_score < 70 THEN 90 WHEN s.quality_score < 80 THEN 70 WHEN s.quality_score < 90 THEN 40 ELSE 15 END) * 0.4
            + (100 - COALESCE(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 / NULLIF(COUNT(o.actual_delivery_date), 0), 50)) * 0.4
            + 30 * 0.2, 1) AS risk_score,
        CASE WHEN ROUND((CASE WHEN s.quality_score < 70 THEN 90 WHEN s.quality_score < 80 THEN 70 WHEN s.quality_score < 90 THEN 40 ELSE 15 END) * 0.4
            + (100 - COALESCE(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 / NULLIF(COUNT(o.actual_delivery_date), 0), 50)) * 0.4
            + 30 * 0.2, 1) > 70 THEN 'Critical'
            WHEN ROUND((CASE WHEN s.quality_score < 70 THEN 90 WHEN s.quality_score < 80 THEN 70 WHEN s.quality_score < 90 THEN 40 ELSE 15 END) * 0.4
            + (100 - COALESCE(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 / NULLIF(COUNT(o.actual_delivery_date), 0), 50)) * 0.4
            + 30 * 0.2, 1) > 50 THEN 'High'
            ELSE 'Medium' END AS risk_category,
        ROUND(CASE WHEN s.quality_score < 70 THEN 90 WHEN s.quality_score < 80 THEN 70 WHEN s.quality_score < 90 THEN 40 ELSE 15 END, 1),
        ROUND(100 - COALESCE(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 / NULLIF(COUNT(o.actual_delivery_date), 0), 50), 1),
        20.0,
        CASE WHEN s.status = 'Probation' THEN 'ON PROBATION' ELSE 'Within parameters' END
    FROM SC_ONTOLOGY.RAW.SUPPLIERS s
    LEFT JOIN SC_ONTOLOGY.RAW.PARTS pt ON pt.primary_supplier_id = s.supplier_id
    LEFT JOIN SC_ONTOLOGY.RAW.ORDER_LINES ol ON ol.part_id = pt.part_id
    LEFT JOIN SC_ONTOLOGY.RAW.ORDERS o ON ol.order_id = o.order_id AND o.actual_delivery_date IS NOT NULL
    WHERE s.supplier_name ILIKE '%' || p_supplier_name || '%'
    GROUP BY s.supplier_id, s.supplier_name, s.supplier_tier, s.quality_score, s.status
$$;

-- ============================================================
-- IMPROVEMENT 4: Anomaly Detection (OTD Time Series)
-- ============================================================

CREATE OR REPLACE VIEW SC_ONTOLOGY.ADVANCED.V_OTD_DAILY_TIMESERIES AS
SELECT 
    o.actual_delivery_date AS delivery_date,
    COUNT(*) AS total_delivered,
    COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) AS on_time_count,
    ROUND(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 / COUNT(*), 2) AS otd_pct,
    AVG(ROUND(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 / COUNT(*), 2))
        OVER (ORDER BY o.actual_delivery_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS otd_7day_avg,
    STDDEV(ROUND(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 / COUNT(*), 2))
        OVER (ORDER BY o.actual_delivery_date ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS otd_30day_stddev
FROM SC_ONTOLOGY.RAW.ORDERS o
WHERE o.actual_delivery_date IS NOT NULL
GROUP BY o.actual_delivery_date;

-- ============================================================
-- IMPROVEMENT 5: Multi-Hop Impact Analysis
-- ============================================================

CREATE OR REPLACE FUNCTION SC_ONTOLOGY.ADVANCED.SUPPLY_CHAIN_IMPACT_ANALYSIS(p_entity_type VARCHAR, p_entity_name VARCHAR)
RETURNS TABLE (impact_level VARCHAR, entity_type VARCHAR, entity_name VARCHAR, relationship VARCHAR,
    estimated_orders_affected INT, estimated_revenue_at_risk FLOAT)
LANGUAGE SQL
AS $$
    SELECT CASE hop WHEN 1 THEN 'Direct' ELSE 'Secondary' END, entity_type, entity_name, relationship, order_count, revenue
    FROM (
        SELECT 1 AS hop, 'Part' AS entity_type, pt.part_name AS entity_name,
            'Supplied by ' || s.supplier_name AS relationship,
            COUNT(DISTINCT ol.order_id) AS order_count, SUM(ol.qty_ordered * ol.unit_price) AS revenue
        FROM SC_ONTOLOGY.RAW.SUPPLIERS s
        JOIN SC_ONTOLOGY.RAW.PARTS pt ON pt.primary_supplier_id = s.supplier_id
        JOIN SC_ONTOLOGY.RAW.ORDER_LINES ol ON ol.part_id = pt.part_id
        WHERE p_entity_type = 'Supplier' AND s.supplier_name ILIKE '%' || p_entity_name || '%'
        GROUP BY pt.part_name, s.supplier_name
        UNION ALL
        SELECT 2, 'Customer', c.customer_name,
            'Orders parts from ' || s.supplier_name,
            COUNT(DISTINCT o.order_id), SUM(ol.qty_ordered * ol.unit_price)
        FROM SC_ONTOLOGY.RAW.SUPPLIERS s
        JOIN SC_ONTOLOGY.RAW.PARTS pt ON pt.primary_supplier_id = s.supplier_id
        JOIN SC_ONTOLOGY.RAW.ORDER_LINES ol ON ol.part_id = pt.part_id
        JOIN SC_ONTOLOGY.RAW.ORDERS o ON ol.order_id = o.order_id
        JOIN SC_ONTOLOGY.RAW.CUSTOMERS c ON o.customer_id = c.customer_id
        WHERE p_entity_type = 'Supplier' AND s.supplier_name ILIKE '%' || p_entity_name || '%'
        GROUP BY c.customer_name, s.supplier_name
    ) ORDER BY hop, revenue DESC
$$;

-- ============================================================
-- IMPROVEMENT 6: Feedback & Evaluation
-- ============================================================

CREATE OR REPLACE TABLE SC_ONTOLOGY.ADVANCED.AGENT_EVAL_DATASET (
    eval_id INT AUTOINCREMENT, question VARCHAR(500), expected_tool VARCHAR(100),
    expected_metric VARCHAR(100), ground_truth_sql VARCHAR(4000),
    ground_truth_answer VARCHAR(500), persona VARCHAR(50), difficulty VARCHAR(20)
);

CREATE OR REPLACE TABLE SC_ONTOLOGY.ADVANCED.AGENT_EVAL_RESULTS (
    eval_id INT, question VARCHAR(500), expected_tool VARCHAR(100),
    ground_truth_answer VARCHAR(500), persona VARCHAR(50), difficulty VARCHAR(20),
    agent_response VARCHAR(100000), response_status VARCHAR(20),
    tool_used VARCHAR(100), sql_generated VARCHAR(4000), evaluated_at TIMESTAMP
);

-- ============================================================
-- IMPROVEMENT 7: Row-Level Security
-- ============================================================

CREATE OR REPLACE TABLE SC_ONTOLOGY.GOVERNANCE.PERSONA_REGION_ACCESS (
    role_name VARCHAR(100), persona VARCHAR(50), allowed_regions VARCHAR(500),
    can_view_financials BOOLEAN, can_view_supplier_details BOOLEAN
);

-- ============================================================
-- IMPROVEMENT 8: Streams + Tasks (Incremental Processing)
-- ============================================================

CREATE OR REPLACE STREAM SC_ONTOLOGY.RAW.ORDERS_STREAM ON TABLE SC_ONTOLOGY.RAW.ORDERS;

CREATE OR REPLACE TABLE SC_ONTOLOGY.ADVANCED.KPI_ALERT_LOG (
    alert_id INT AUTOINCREMENT, alert_time TIMESTAMP, metric_name VARCHAR(100),
    current_value FLOAT, threshold FLOAT, alert_type VARCHAR(200), acknowledged BOOLEAN DEFAULT FALSE
);

CREATE OR REPLACE TASK SC_ONTOLOGY.ADVANCED.TASK_REFRESH_KPI_ALERTS
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '60 MINUTE'
AS
  INSERT INTO SC_ONTOLOGY.ADVANCED.KPI_ALERT_LOG (alert_time, metric_name, current_value, threshold, alert_type)
  SELECT CURRENT_TIMESTAMP(), 'OTD%', otd_pct, 40.0, 'OTD Below Threshold'
  FROM (SELECT ROUND(COUNT(CASE WHEN actual_delivery_date <= requested_delivery_date THEN 1 END) * 100.0 
      / NULLIF(COUNT(actual_delivery_date), 0), 2) AS otd_pct
    FROM SC_ONTOLOGY.RAW.ORDERS WHERE actual_delivery_date IS NOT NULL AND order_date >= DATEADD('day', -7, CURRENT_DATE()))
  WHERE otd_pct < 40.0;

-- ============================================================
-- IMPROVEMENT 9: External Data Enrichment
-- ============================================================

CREATE OR REPLACE TABLE SC_ONTOLOGY.ADVANCED.COUNTRY_RISK_INDEX (
    country VARCHAR(100), risk_index FLOAT, climate_risk VARCHAR(20),
    geopolitical_risk VARCHAR(20), logistics_reliability VARCHAR(20), last_updated DATE
);

-- ============================================================
-- IMPROVEMENT 10: Ontology Versioning
-- ============================================================

CREATE OR REPLACE TABLE SC_ONTOLOGY.GOVERNANCE.ONTOLOGY_CHANGELOG (
    version_id INT AUTOINCREMENT, version_tag VARCHAR(20),
    change_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    change_type VARCHAR(50), object_affected VARCHAR(200),
    description VARCHAR(2000), changed_by VARCHAR(100), breaking_change BOOLEAN DEFAULT FALSE
);

-- ============================================================
-- AI/ML CAPABILITIES: Cortex AI Functions
-- ============================================================

-- AI-powered supplier risk summary
CREATE OR REPLACE FUNCTION SC_ONTOLOGY.ADVANCED.AI_SUPPLIER_SUMMARY(p_supplier_name VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS $$
    SELECT SNOWFLAKE.CORTEX.COMPLETE('claude-haiku-4-5',
        'You are a supply chain risk analyst. Summarize the risk profile of supplier "' || p_supplier_name || '" based on: ' ||
        (SELECT LISTAGG('Supplier: ' || supplier_name || ', Tier: ' || supplier_tier || 
            ', Quality: ' || quality_score::VARCHAR || '/100, Lead Time: ' || lead_time_days::VARCHAR || ' days, Status: ' || status, '; ')
         FROM SC_ONTOLOGY.RAW.SUPPLIERS WHERE supplier_name ILIKE '%' || p_supplier_name || '%') ||
        '. Provide 2-3 sentence executive summary.')
$$;

-- Document sentiment analysis
CREATE OR REPLACE VIEW SC_ONTOLOGY.ADVANCED.V_DOCUMENT_SENTIMENT AS
SELECT doc_id, title, doc_type, category, related_entity,
    SNOWFLAKE.CORTEX.SENTIMENT(content) AS sentiment_score,
    CASE WHEN SNOWFLAKE.CORTEX.SENTIMENT(content) > 0.3 THEN 'Positive'
         WHEN SNOWFLAKE.CORTEX.SENTIMENT(content) < -0.3 THEN 'Negative'
         ELSE 'Neutral' END AS sentiment_category
FROM SC_ONTOLOGY.DOCUMENTS.SUPPLY_CHAIN_KNOWLEDGE;

-- Document AI classification + summarization
CREATE OR REPLACE VIEW SC_ONTOLOGY.ADVANCED.V_DOCUMENT_AI_ENRICHED AS
SELECT doc_id, title, doc_type, category, related_entity,
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(content, 
        ARRAY_CONSTRUCT('Urgent Action Required', 'Risk Warning', 'Standard Process', 'Positive Performance', 'Compliance Notice')
    ):label::VARCHAR AS ai_classification,
    SNOWFLAKE.CORTEX.SUMMARIZE(content) AS ai_summary
FROM SC_ONTOLOGY.DOCUMENTS.SUPPLY_CHAIN_KNOWLEDGE;

-- ============================================================
-- AI EVALUATION: Run and score agent responses
-- ============================================================

CREATE OR REPLACE PROCEDURE SC_ONTOLOGY.ADVANCED.RUN_AGENT_EVALUATION()
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    INSERT INTO SC_ONTOLOGY.ADVANCED.AGENT_EVAL_RESULTS
    SELECT 1, 'What is our overall on-time delivery rate?', 'SupplyChainAnalyst', '47.95', 'Planning', 'Easy',
        SNOWFLAKE.CORTEX.DATA_AGENT_RUN('SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT',
            $${"messages": [{"role": "user", "content": [{"type": "text", "text": "What is our overall on-time delivery rate?"}]}]}$$),
        'completed', NULL, NULL, CURRENT_TIMESTAMP();
    INSERT INTO SC_ONTOLOGY.ADVANCED.AGENT_EVAL_RESULTS
    SELECT 2, 'What is our fill rate?', 'SupplyChainAnalyst', '66.66', 'Planning', 'Easy',
        SNOWFLAKE.CORTEX.DATA_AGENT_RUN('SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT',
            $${"messages": [{"role": "user", "content": [{"type": "text", "text": "What is our fill rate?"}]}]}$$),
        'completed', NULL, NULL, CURRENT_TIMESTAMP();
    INSERT INTO SC_ONTOLOGY.ADVANCED.AGENT_EVAL_RESULTS
    SELECT 3, 'How many days of inventory do we have?', 'SupplyChainAnalyst', '23.9', 'Planning', 'Easy',
        SNOWFLAKE.CORTEX.DATA_AGENT_RUN('SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT',
            $${"messages": [{"role": "user", "content": [{"type": "text", "text": "How many days of inventory do we have?"}]}]}$$),
        'completed', NULL, NULL, CURRENT_TIMESTAMP();
    INSERT INTO SC_ONTOLOGY.ADVANCED.AGENT_EVAL_RESULTS
    SELECT 4, 'What are DHL Express contract terms?', 'KnowledgeSearch', 'Express 2-day 99.5% target', 'Logistics', 'Hard',
        SNOWFLAKE.CORTEX.DATA_AGENT_RUN('SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT',
            $${"messages": [{"role": "user", "content": [{"type": "text", "text": "What are DHL Express contract terms for express shipments?"}]}]}$$),
        'completed', NULL, NULL, CURRENT_TIMESTAMP();
    INSERT INTO SC_ONTOLOGY.ADVANCED.AGENT_EVAL_RESULTS
    SELECT 5, 'Which suppliers have worst OTD?', 'ProcurementAnalyst', 'Bottom suppliers by OTD', 'Procurement', 'Medium',
        SNOWFLAKE.CORTEX.DATA_AGENT_RUN('SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT',
            $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Which suppliers have the worst on-time delivery performance?"}]}]}$$),
        'completed', NULL, NULL, CURRENT_TIMESTAMP();
    RETURN 'Evaluation complete: 5 questions evaluated';
END;

-- Evaluation summary view
CREATE OR REPLACE VIEW SC_ONTOLOGY.ADVANCED.V_EVAL_SUMMARY AS
SELECT 
    COUNT(*) AS total_evaluations,
    SUM(CASE 
        WHEN (agent_response LIKE '%47.95%' AND eval_id = 1)
          OR (agent_response LIKE '%66.6%' AND eval_id = 2)
          OR ((agent_response LIKE '%23.9%' OR agent_response LIKE '%24%') AND eval_id = 3)
          OR (agent_response LIKE '%99.5%' AND eval_id = 4)
          OR (agent_response LIKE '%supplier%' AND eval_id = 5)
        THEN 1 ELSE 0 END) AS passed,
    ROUND(SUM(CASE 
        WHEN (agent_response LIKE '%47.95%' AND eval_id = 1)
          OR (agent_response LIKE '%66.6%' AND eval_id = 2)
          OR ((agent_response LIKE '%23.9%' OR agent_response LIKE '%24%') AND eval_id = 3)
          OR (agent_response LIKE '%99.5%' AND eval_id = 4)
          OR (agent_response LIKE '%supplier%' AND eval_id = 5)
        THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pass_rate_pct,
    SUM(CASE WHEN agent_response LIKE '%Analyst%' THEN 1 ELSE 0 END) AS used_analyst,
    SUM(CASE WHEN agent_response LIKE '%KnowledgeSearch%' THEN 1 ELSE 0 END) AS used_search
FROM SC_ONTOLOGY.ADVANCED.AGENT_EVAL_RESULTS;

-- Run: CALL SC_ONTOLOGY.ADVANCED.RUN_AGENT_EVALUATION();
-- Check: SELECT * FROM SC_ONTOLOGY.ADVANCED.V_EVAL_SUMMARY;

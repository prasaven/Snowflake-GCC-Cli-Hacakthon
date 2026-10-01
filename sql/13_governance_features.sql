-- ============================================================
-- 13_governance_features.sql
-- Streamlit + DMFs + Tags + Policies + Alerts + Enhanced Agent
-- ============================================================

USE DATABASE SC_ONTOLOGY;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================
-- STREAMLIT IN SNOWFLAKE: Interactive Dashboard
-- ============================================================

CREATE OR REPLACE STAGE SC_ONTOLOGY.ANALYTICS.STREAMLIT_STAGE DIRECTORY = (ENABLE = TRUE);
-- PUT 'file://D:/clihackathon/streamlit_app.py' @SC_ONTOLOGY.ANALYTICS.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

CREATE OR REPLACE STREAMLIT SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_DASHBOARD
  ROOT_LOCATION = '@SC_ONTOLOGY.ANALYTICS.STREAMLIT_STAGE'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = COMPUTE_WH
  COMMENT = 'Supply Chain Ontology - Interactive Intelligence Dashboard';

-- ============================================================
-- DATA METRIC FUNCTIONS (DMFs): Automated Quality Monitoring
-- ============================================================

CREATE OR REPLACE DATA METRIC FUNCTION SC_ONTOLOGY.GOVERNANCE.DMF_NEGATIVE_INVENTORY(
    ARG_T TABLE(qty_on_hand NUMBER)
) RETURNS NUMBER AS $$ SELECT COUNT(*) FROM ARG_T WHERE qty_on_hand < 0 $$;

CREATE OR REPLACE DATA METRIC FUNCTION SC_ONTOLOGY.GOVERNANCE.DMF_NULL_DELIVERY_DATES(
    ARG_T TABLE(actual_delivery_date DATE, status VARCHAR)
) RETURNS NUMBER AS $$ SELECT COUNT(*) FROM ARG_T WHERE status = 'Delivered' AND actual_delivery_date IS NULL $$;

CREATE OR REPLACE DATA METRIC FUNCTION SC_ONTOLOGY.GOVERNANCE.DMF_LOW_FILL_RATE(
    ARG_T TABLE(qty_fulfilled NUMBER, qty_ordered NUMBER)
) RETURNS NUMBER AS $$ SELECT COUNT(*) FROM ARG_T WHERE qty_ordered > 0 AND (qty_fulfilled * 1.0 / qty_ordered) < 0.5 $$;

-- Attach DMFs to tables
ALTER TABLE SC_ONTOLOGY.RAW.INVENTORY SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE SC_ONTOLOGY.RAW.INVENTORY ADD DATA METRIC FUNCTION SC_ONTOLOGY.GOVERNANCE.DMF_NEGATIVE_INVENTORY ON (qty_on_hand);

ALTER TABLE SC_ONTOLOGY.RAW.ORDERS SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE SC_ONTOLOGY.RAW.ORDERS ADD DATA METRIC FUNCTION SC_ONTOLOGY.GOVERNANCE.DMF_NULL_DELIVERY_DATES ON (actual_delivery_date, status);

ALTER TABLE SC_ONTOLOGY.RAW.ORDER_LINES SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';
ALTER TABLE SC_ONTOLOGY.RAW.ORDER_LINES ADD DATA METRIC FUNCTION SC_ONTOLOGY.GOVERNANCE.DMF_LOW_FILL_RATE ON (qty_fulfilled, qty_ordered);

-- ============================================================
-- OBJECT TAGGING: Enterprise Metadata Governance
-- ============================================================

CREATE OR REPLACE TAG SC_ONTOLOGY.GOVERNANCE.ONTOLOGY_DOMAIN ALLOWED_VALUES 'ERP', 'Logistics', 'Supplier', 'IoT', 'Finance', 'Planning', 'Cross-Domain';
CREATE OR REPLACE TAG SC_ONTOLOGY.GOVERNANCE.DATA_SENSITIVITY ALLOWED_VALUES 'Public', 'Internal', 'Confidential', 'Restricted';
CREATE OR REPLACE TAG SC_ONTOLOGY.GOVERNANCE.DATA_OWNER;
CREATE OR REPLACE TAG SC_ONTOLOGY.GOVERNANCE.REFRESH_FREQUENCY ALLOWED_VALUES 'Real-time', 'Hourly', 'Daily', 'Weekly', 'Static';

ALTER TABLE SC_ONTOLOGY.RAW.SUPPLIERS SET TAG SC_ONTOLOGY.GOVERNANCE.ONTOLOGY_DOMAIN = 'Supplier', SC_ONTOLOGY.GOVERNANCE.DATA_SENSITIVITY = 'Confidential', SC_ONTOLOGY.GOVERNANCE.DATA_OWNER = 'Procurement';
ALTER TABLE SC_ONTOLOGY.RAW.ORDERS SET TAG SC_ONTOLOGY.GOVERNANCE.ONTOLOGY_DOMAIN = 'ERP', SC_ONTOLOGY.GOVERNANCE.DATA_SENSITIVITY = 'Internal', SC_ONTOLOGY.GOVERNANCE.DATA_OWNER = 'Planning';
ALTER TABLE SC_ONTOLOGY.RAW.SHIPMENTS SET TAG SC_ONTOLOGY.GOVERNANCE.ONTOLOGY_DOMAIN = 'Logistics', SC_ONTOLOGY.GOVERNANCE.DATA_SENSITIVITY = 'Internal', SC_ONTOLOGY.GOVERNANCE.DATA_OWNER = 'Logistics';
ALTER TABLE SC_ONTOLOGY.RAW.INVENTORY SET TAG SC_ONTOLOGY.GOVERNANCE.ONTOLOGY_DOMAIN = 'Planning', SC_ONTOLOGY.GOVERNANCE.DATA_SENSITIVITY = 'Internal', SC_ONTOLOGY.GOVERNANCE.DATA_OWNER = 'Planning';
ALTER TABLE SC_ONTOLOGY.RAW.CUSTOMERS SET TAG SC_ONTOLOGY.GOVERNANCE.ONTOLOGY_DOMAIN = 'Finance', SC_ONTOLOGY.GOVERNANCE.DATA_SENSITIVITY = 'Restricted', SC_ONTOLOGY.GOVERNANCE.DATA_OWNER = 'Sales';
ALTER TABLE SC_ONTOLOGY.RAW.IOT_SENSOR_READINGS SET TAG SC_ONTOLOGY.GOVERNANCE.ONTOLOGY_DOMAIN = 'IoT', SC_ONTOLOGY.GOVERNANCE.DATA_SENSITIVITY = 'Internal', SC_ONTOLOGY.GOVERNANCE.DATA_OWNER = 'Operations';

-- ============================================================
-- ROW ACCESS POLICY: Persona-Based Data Filtering
-- ============================================================

CREATE OR REPLACE ROW ACCESS POLICY SC_ONTOLOGY.GOVERNANCE.RAP_REGION_FILTER
AS (region_val VARCHAR) RETURNS BOOLEAN ->
    CURRENT_ROLE() = 'ACCOUNTADMIN'
    OR EXISTS (SELECT 1 FROM SC_ONTOLOGY.GOVERNANCE.PERSONA_REGION_ACCESS
        WHERE role_name = CURRENT_ROLE() AND CONTAINS(allowed_regions, region_val));

-- ============================================================
-- MASKING POLICIES: Column-Level Security
-- ============================================================

CREATE OR REPLACE MASKING POLICY SC_ONTOLOGY.GOVERNANCE.MASK_FINANCIAL_DATA AS (val FLOAT) RETURNS FLOAT ->
    CASE WHEN CURRENT_ROLE() = 'ACCOUNTADMIN' THEN val
         WHEN EXISTS (SELECT 1 FROM SC_ONTOLOGY.GOVERNANCE.PERSONA_REGION_ACCESS WHERE role_name = CURRENT_ROLE() AND can_view_financials = TRUE) THEN val
         ELSE -999.99 END;

CREATE OR REPLACE MASKING POLICY SC_ONTOLOGY.GOVERNANCE.MASK_CUSTOMER_PII AS (val VARCHAR) RETURNS VARCHAR ->
    CASE WHEN CURRENT_ROLE() = 'ACCOUNTADMIN' THEN val
         WHEN CURRENT_ROLE() IN ('SC_PLANNING_ROLE', 'SC_PROCUREMENT_ROLE') THEN LEFT(val, 3) || '***'
         ELSE '***RESTRICTED***' END;

-- ============================================================
-- SNOWFLAKE ALERTS: Proactive KPI Monitoring
-- ============================================================

CREATE OR REPLACE ALERT SC_ONTOLOGY.ADVANCED.ALERT_OTD_CRITICAL
  WAREHOUSE = COMPUTE_WH SCHEDULE = '60 MINUTE'
  IF (EXISTS (SELECT 1 FROM (
    SELECT ROUND(COUNT(CASE WHEN actual_delivery_date <= requested_delivery_date THEN 1 END) * 100.0 / NULLIF(COUNT(actual_delivery_date), 0), 2) AS otd_pct
    FROM SC_ONTOLOGY.RAW.ORDERS WHERE actual_delivery_date IS NOT NULL AND order_date >= DATEADD('day', -7, CURRENT_DATE())
  ) WHERE otd_pct < 40.0))
  THEN INSERT INTO SC_ONTOLOGY.ADVANCED.KPI_ALERT_LOG (alert_time, metric_name, current_value, threshold, alert_type)
    SELECT CURRENT_TIMESTAMP(), 'OTD%_7DAY', otd_pct, 40.0, 'CRITICAL: OTD below 40%'
    FROM (SELECT ROUND(COUNT(CASE WHEN actual_delivery_date <= requested_delivery_date THEN 1 END) * 100.0 / NULLIF(COUNT(actual_delivery_date), 0), 2) AS otd_pct
    FROM SC_ONTOLOGY.RAW.ORDERS WHERE actual_delivery_date IS NOT NULL AND order_date >= DATEADD('day', -7, CURRENT_DATE()));

CREATE OR REPLACE ALERT SC_ONTOLOGY.ADVANCED.ALERT_FILL_RATE_LOW
  WAREHOUSE = COMPUTE_WH SCHEDULE = '60 MINUTE'
  IF (EXISTS (SELECT 1 FROM (SELECT SUM(qty_fulfilled) * 100.0 / NULLIF(SUM(qty_ordered), 0) AS fr FROM SC_ONTOLOGY.RAW.ORDER_LINES) WHERE fr < 60.0))
  THEN INSERT INTO SC_ONTOLOGY.ADVANCED.KPI_ALERT_LOG (alert_time, metric_name, current_value, threshold, alert_type)
    SELECT CURRENT_TIMESTAMP(), 'FILL_RATE', fr, 60.0, 'WARNING: Fill rate below 60%'
    FROM (SELECT SUM(qty_fulfilled) * 100.0 / NULLIF(SUM(qty_ordered), 0) AS fr FROM SC_ONTOLOGY.RAW.ORDER_LINES);

CREATE OR REPLACE ALERT SC_ONTOLOGY.ADVANCED.ALERT_STOCKOUT_RISK
  WAREHOUSE = COMPUTE_WH SCHEDULE = '60 MINUTE'
  IF (EXISTS (SELECT 1 FROM SC_ONTOLOGY.RAW.INVENTORY i JOIN SC_ONTOLOGY.RAW.PARTS p ON i.part_id = p.part_id
    WHERE p.abc_class = 'A' AND i.avg_daily_demand > 0 AND (i.qty_on_hand / i.avg_daily_demand) < 5))
  THEN INSERT INTO SC_ONTOLOGY.ADVANCED.KPI_ALERT_LOG (alert_time, metric_name, current_value, threshold, alert_type)
    SELECT CURRENT_TIMESTAMP(), 'A_CLASS_DOI', AVG(i.qty_on_hand / NULLIF(i.avg_daily_demand, 0)), 5.0, 'CRITICAL: A-class stockout risk'
    FROM SC_ONTOLOGY.RAW.INVENTORY i JOIN SC_ONTOLOGY.RAW.PARTS p ON i.part_id = p.part_id
    WHERE p.abc_class = 'A' AND i.avg_daily_demand > 0 AND (i.qty_on_hand / i.avg_daily_demand) < 5;

-- ============================================================
-- ADDITIONAL AI/ML FUNCTIONS
-- ============================================================

CREATE OR REPLACE FUNCTION SC_ONTOLOGY.ADVANCED.AI_EXPLAIN_ANOMALY(p_metric VARCHAR, p_value FLOAT, p_threshold FLOAT)
RETURNS VARCHAR LANGUAGE SQL AS $$
SELECT SNOWFLAKE.CORTEX.COMPLETE('claude-haiku-4-5',
    'Supply chain metric "' || p_metric || '" is ' || p_value::VARCHAR || ' (' ||
    CASE WHEN p_value < p_threshold THEN 'BELOW' ELSE 'ABOVE' END || ' threshold ' || p_threshold::VARCHAR ||
    '). Give top 3 root causes, immediate actions, and which team to notify. Max 5 sentences.')
$$;

CREATE OR REPLACE FUNCTION SC_ONTOLOGY.ADVANCED.AI_PRIORITIZE_ORDERS()
RETURNS TABLE (order_id INT, customer_name VARCHAR, segment VARCHAR, days_until_due INT, priority_score INT, ai_recommendation VARCHAR)
LANGUAGE SQL AS $$
SELECT o.order_id, c.customer_name, c.segment,
    DATEDIFF('day', CURRENT_DATE(), o.requested_delivery_date),
    (CASE c.segment WHEN 'Strategic' THEN 40 WHEN 'Enterprise' THEN 30 WHEN 'Mid-Market' THEN 20 ELSE 10 END
     + CASE WHEN DATEDIFF('day', CURRENT_DATE(), o.requested_delivery_date) < 3 THEN 50
            WHEN DATEDIFF('day', CURRENT_DATE(), o.requested_delivery_date) < 7 THEN 30 ELSE 5 END
     + CASE o.shipping_priority WHEN 'Express' THEN 20 ELSE 10 END)::INT,
    CASE WHEN DATEDIFF('day', CURRENT_DATE(), o.requested_delivery_date) < 0 THEN 'OVERDUE - Expedite now'
         WHEN DATEDIFF('day', CURRENT_DATE(), o.requested_delivery_date) < 3 THEN 'CRITICAL - Air freight'
         WHEN DATEDIFF('day', CURRENT_DATE(), o.requested_delivery_date) < 7 THEN 'HIGH - Monitor'
         ELSE 'NORMAL' END
FROM SC_ONTOLOGY.RAW.ORDERS o JOIN SC_ONTOLOGY.RAW.CUSTOMERS c ON o.customer_id = c.customer_id
WHERE o.status IN ('Pending', 'Processing') AND o.requested_delivery_date IS NOT NULL
ORDER BY 5 DESC LIMIT 20
$$;

-- ============================================================
-- 09_demo_queries.sql
-- Cross-Persona Consistency Demonstrations
-- Proves same metric resolves identically across all personas
-- ============================================================

USE DATABASE SC_ONTOLOGY;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================
-- DEMO 1: Executive Dashboard - All 4 Canonical KPIs
-- ============================================================
SELECT 'On-Time Delivery Rate (OTD%)' AS metric,
       ROUND(COUNT(CASE WHEN actual_delivery_date <= requested_delivery_date THEN 1 END) * 100.0 
           / NULLIF(COUNT(actual_delivery_date), 0), 2)::VARCHAR AS value,
       'delivered_on_time / total_delivered * 100' AS formula
FROM SC_ONTOLOGY.RAW.ORDERS WHERE actual_delivery_date IS NOT NULL
UNION ALL
SELECT 'Fill Rate (%)',
       ROUND(SUM(qty_fulfilled) * 100.0 / NULLIF(SUM(qty_ordered), 0), 2)::VARCHAR,
       'sum(qty_fulfilled) / sum(qty_ordered) * 100'
FROM SC_ONTOLOGY.RAW.ORDER_LINES
UNION ALL
SELECT 'Days of Inventory (DOI)',
       ROUND(AVG(qty_on_hand) / NULLIF(AVG(avg_daily_demand), 0), 1)::VARCHAR,
       'avg(qty_on_hand) / avg(daily_demand)'
FROM SC_ONTOLOGY.RAW.INVENTORY
UNION ALL
SELECT 'Freight Cost Per Unit',
       ROUND(AVG(freight_cost / NULLIF(qty_shipped, 0)), 2)::VARCHAR,
       'avg(freight_cost / qty_shipped)'
FROM SC_ONTOLOGY.RAW.SHIPMENTS;

-- ============================================================
-- DEMO 2: SAME OTD% METRIC - THREE DIFFERENT PERSONAS
-- All use: COUNT(actual <= requested) / COUNT(delivered) * 100
-- ============================================================

-- PLANNING PERSONA: "What is our on-time delivery rate by plant?"
SELECT 'PLANNING' AS persona, p.plant_name AS grouping_dimension,
    ROUND(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 
        / NULLIF(COUNT(o.actual_delivery_date), 0), 2) AS otd_pct
FROM SC_ONTOLOGY.RAW.ORDERS o
JOIN SC_ONTOLOGY.RAW.ORDER_LINES ol ON o.order_id = ol.order_id
JOIN SC_ONTOLOGY.RAW.PLANTS p ON ol.plant_id = p.plant_id
WHERE o.actual_delivery_date IS NOT NULL
GROUP BY p.plant_name ORDER BY otd_pct DESC;

-- PROCUREMENT PERSONA: "Which suppliers have the worst OTD?"
SELECT 'PROCUREMENT' AS persona, s.supplier_name AS grouping_dimension,
    ROUND(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 
        / NULLIF(COUNT(o.actual_delivery_date), 0), 2) AS otd_pct
FROM SC_ONTOLOGY.RAW.ORDERS o
JOIN SC_ONTOLOGY.RAW.ORDER_LINES ol ON o.order_id = ol.order_id
JOIN SC_ONTOLOGY.RAW.PARTS pt ON ol.part_id = pt.part_id
JOIN SC_ONTOLOGY.RAW.SUPPLIERS s ON pt.primary_supplier_id = s.supplier_id
WHERE o.actual_delivery_date IS NOT NULL
GROUP BY s.supplier_name ORDER BY otd_pct ASC LIMIT 10;

-- LOGISTICS PERSONA: "Show me OTD by carrier"
SELECT 'LOGISTICS' AS persona, sh.carrier AS grouping_dimension,
    ROUND(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 
        / NULLIF(COUNT(o.actual_delivery_date), 0), 2) AS otd_pct
FROM SC_ONTOLOGY.RAW.SHIPMENTS sh
JOIN SC_ONTOLOGY.RAW.ORDERS o ON sh.order_id = o.order_id
WHERE o.actual_delivery_date IS NOT NULL
GROUP BY sh.carrier ORDER BY otd_pct DESC;

-- ============================================================
-- DEMO 3: Agent Interaction (via DATA_AGENT_RUN)
-- ============================================================

-- Structured question (routes to Cortex Analyst)
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "What is our overall on-time delivery rate?"}]}]}$$
) AS structured_response;

-- Unstructured question (routes to Cortex Search)
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "What are our contract terms with DHL Express?"}]}]}$$
) AS unstructured_response;

-- Cross-domain question (uses both tools)
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "Quantum Plastics has quality issues. What is their current OTD performance and what corrective actions have been taken?"}]}]}$$
) AS cross_domain_response;

-- ============================================================
-- DEMO 4: Semantic View Governance - Describe the ontology
-- ============================================================
SHOW SEMANTIC METRICS IN SEMANTIC VIEW SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_VIEW;
SHOW SEMANTIC DIMENSIONS IN SEMANTIC VIEW SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_VIEW;

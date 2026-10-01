-- ============================================================
-- 11_cortex_agent_evaluation.sql
-- Native Snowflake Cortex Agent Evaluation Framework
-- Uses EXECUTE_AI_EVALUATION + SYSTEM$CREATE_EVALUATION_DATASET
-- ============================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA ADVANCED;

-- ============================================================
-- STEP 1: Create evaluation input table (proper format)
-- Two columns: input_query (VARCHAR) + ground_truth (VARIANT)
-- ============================================================

CREATE OR REPLACE TABLE SC_AGENT_EVAL_INPUT (
    input_query VARCHAR,
    ground_truth VARIANT
);

INSERT INTO SC_AGENT_EVAL_INPUT (input_query, ground_truth)
SELECT 'What is our overall on-time delivery rate?',
  PARSE_JSON('{"ground_truth_output": "The on-time delivery rate (OTD) is approximately 47.95%. This metric measures the percentage of orders delivered on or before the customer-requested delivery date. Only orders with confirmed delivery are included. Formula: orders delivered on time / total delivered * 100.", "ground_truth_invocations": [{"tool_name": "SupplyChainAnalyst", "tool_input": "on-time delivery rate overall", "tool_output": "SQL querying orders table returning approximately 47.95%"}]}')
UNION ALL
SELECT 'What is our fill rate across all plants?',
  PARSE_JSON('{"ground_truth_output": "The overall fill rate is approximately 66.66%. Fill rate measures qty fulfilled / qty ordered * 100.", "ground_truth_invocations": [{"tool_name": "SupplyChainAnalyst", "tool_input": "fill rate across all plants", "tool_output": "SQL aggregating qty_fulfilled / qty_ordered returning ~66.66%"}]}')
UNION ALL
SELECT 'How many days of inventory do we have overall?',
  PARSE_JSON('{"ground_truth_output": "We have approximately 23.9 days of inventory. DOI = avg qty on hand / avg daily demand.", "ground_truth_invocations": [{"tool_name": "SupplyChainAnalyst", "tool_input": "days of inventory overall", "tool_output": "SQL computing avg(qty_on_hand)/avg(avg_daily_demand) returning ~23.9 days"}]}')
UNION ALL
SELECT 'What are our contract terms with DHL Express for express shipments?',
  PARSE_JSON('{"ground_truth_output": "DHL Express: 2-day delivery, 99.5% on-time target. Coverage: NA and Europe. Per-kg pricing with quarterly fuel surcharge. Claims within 48 hours. Temp-controlled at 15% premium.", "ground_truth_invocations": [{"tool_name": "KnowledgeSearch", "tool_input": "DHL Express contract terms express", "tool_output": "Logistics Service Agreement document with express 2-day 99.5% target"}]}')
UNION ALL
SELECT 'Which suppliers have the worst on-time delivery performance?',
  PARSE_JSON('{"ground_truth_output": "Bottom suppliers include GlobalParts Inc and Delta Fasteners with OTD below 45%. OTD = delivered on/before requested / total delivered * 100.", "ground_truth_invocations": [{"tool_name": "SupplyChainAnalyst", "tool_input": "suppliers worst OTD performance", "tool_output": "SQL joining orders-order_lines-parts-suppliers computing OTD by supplier, ordered ascending"}]}')
UNION ALL
SELECT 'What corrective actions were taken for Quantum Plastics quality issues?',
  PARSE_JSON('{"ground_truth_output": "Quantum Plastics placed on probation. Defect: Polymer Seal Ring hardness out of spec (Shore A 55 vs 65-70). Actions: 100% incoming inspection, alt supplier qualification. Root cause: unauthorized recycled polymer. Impact: $47K production losses + $12K expediting.", "ground_truth_invocations": [{"tool_name": "KnowledgeSearch", "tool_input": "Quantum Plastics quality corrective actions", "tool_output": "NCR-2025-0847 document describing probation, inspections, and qualification"}]}')
UNION ALL
SELECT 'What is the on-time delivery rate by carrier?',
  PARSE_JSON('{"ground_truth_output": "OTD by carrier: Maersk ~50%, UPS ~49%, others 46-49%. Same canonical OTD formula used: delivered on/before requested / total delivered.", "ground_truth_invocations": [{"tool_name": "SupplyChainAnalyst", "tool_input": "on-time delivery rate by carrier", "tool_output": "SQL joining shipments-orders computing OTD grouped by carrier"}]}')
UNION ALL
SELECT 'What is our inventory management policy for A-class items?',
  PARSE_JSON('{"ground_truth_output": "A-items (top 20% by value): weekly cycle counts, max 15 days DOI target. Safety stock = 1.65 * SQRT(lead_time) * demand_stddev. Reorder point = safety_stock + daily_demand * lead_time.", "ground_truth_invocations": [{"tool_name": "KnowledgeSearch", "tool_input": "inventory management policy A-class items", "tool_output": "Inventory Management Policy describing A-item rules"}]}');

-- ============================================================
-- STEP 2: Create Snowflake Dataset from the table
-- ============================================================

CALL SYSTEM$CREATE_EVALUATION_DATASET(
  'Cortex Agent',
  'SC_ONTOLOGY.ADVANCED.SC_AGENT_EVAL_INPUT',
  'SC_ONTOLOGY.ADVANCED.SC_AGENT_EVAL_DATASET_V1',
  OBJECT_CONSTRUCT(
    'query_text', 'INPUT_QUERY',
    'expected_tools', 'GROUND_TRUTH'
  )
);

-- ============================================================
-- STEP 3: Create internal stage and upload YAML config
-- ============================================================

CREATE OR REPLACE STAGE EVAL_CONFIG_STAGE;
-- PUT eval_config.yaml to stage (run from client):
-- PUT 'file://D:/clihackathon/eval_config.yaml' @SC_ONTOLOGY.ADVANCED.EVAL_CONFIG_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- ============================================================
-- STEP 4: Execute the evaluation
-- ============================================================

CALL EXECUTE_AI_EVALUATION(
  'START',
  OBJECT_CONSTRUCT('run_name', 'sc-ontology-eval-v1'),
  '@SC_ONTOLOGY.ADVANCED.EVAL_CONFIG_STAGE/eval_config.yaml'
);

-- Check status (poll until COMPLETED):
CALL EXECUTE_AI_EVALUATION(
  'STATUS',
  OBJECT_CONSTRUCT('run_name', 'sc-ontology-eval-v1'),
  '@SC_ONTOLOGY.ADVANCED.EVAL_CONFIG_STAGE/eval_config.yaml'
);

-- ============================================================
-- STEP 5: Retrieve and analyze results
-- ============================================================

-- Summary scores by metric
SELECT 
    METRIC_NAME,
    ROUND(AVG(EVAL_AGG_SCORE), 3) AS avg_score,
    COUNT(DISTINCT INPUT_ID) AS questions_evaluated
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
  'SC_ONTOLOGY', 'ANALYTICS', 'SUPPLY_CHAIN_AGENT', 'CORTEX AGENT', 'sc-ontology-eval-v1'
))
WHERE METRIC_NAME IS NOT NULL
GROUP BY METRIC_NAME
ORDER BY METRIC_NAME;

-- Detailed per-question results
SELECT 
    INPUT AS question,
    METRIC_NAME,
    EVAL_AGG_SCORE AS score,
    LEFT(OUTPUT, 200) AS response_preview
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
  'SC_ONTOLOGY', 'ANALYTICS', 'SUPPLY_CHAIN_AGENT', 'CORTEX AGENT', 'sc-ontology-eval-v1'
))
WHERE METRIC_NAME = 'answer_correctness'
ORDER BY EVAL_AGG_SCORE ASC;

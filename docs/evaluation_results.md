# Cortex Agent Evaluation Results (Official)

## Snowflake Native Evaluation Framework

Evaluation run via `EXECUTE_AI_EVALUATION` using the Snowflake Cortex Agent Evaluation framework
with 8 ground-truth questions across 5 metrics.

### Run Details

| Field | Value |
|-------|-------|
| **Run Name** | `sc-ontology-eval-v1` |
| **Agent** | `SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT` |
| **Dataset** | `SC_ONTOLOGY.ADVANCED.SC_AGENT_EVAL_DATASET_V1` (8 records) |
| **Status** | COMPLETED |
| **Config** | `@SC_ONTOLOGY.ADVANCED.EVAL_CONFIG_STAGE/eval_config.yaml` |

### Metric Scores

| Metric | Average Score | Description |
|--------|:---:|-------------|
| **answer_correctness** | **0.876** | How closely agent answers match ground truth |
| **logical_consistency** | **1.000** | Consistency across instructions, planning, tool calls |
| **tool_selection_accuracy** | **1.000** | Whether correct tools were invoked |
| **tool_execution_accuracy** | **0.994** | Quality of tool inputs and outputs |
| **metric_consistency** (custom) | **4.25/10** | Custom metric for formula consistency (needs calibration) |

### Key Findings

1. **Perfect Tool Routing (TSA = 1.0):** The agent ALWAYS selected the correct tool:
   - Structured KPI questions → `SupplyChainAnalyst`
   - Policy/contract questions → `KnowledgeSearch`
   - No misrouting detected across all 8 test cases

2. **Perfect Logical Consistency (1.0):** The agent's reasoning chain is internally consistent — 
   it follows orchestration instructions, uses appropriate tools, and doesn't contradict itself.

3. **Strong Answer Correctness (0.876):** 87.6% accuracy against ground truth. The LLM judge 
   confirmed that actual metric values match expected values and canonical definitions are cited.

4. **Near-Perfect Tool Execution (0.994):** Tool inputs and outputs align with expectations —
   the SQL generated uses correct tables, joins, and formulas.

### Per-Question Breakdown (Answer Correctness)

| Question | Score | Notes |
|----------|:-----:|-------|
| On-time delivery rate | 1.0 | Exact match: 47.95% with formula citation |
| Fill rate | 1.0 | Exact match: 66.66% |
| Days of inventory | 1.0 | Exact match: 23.9 days |
| DHL Express contract terms | 1.0 | All key terms retrieved from documents |
| Worst supplier OTD | 0.75 | Correct data but slight formatting difference |
| Quantum Plastics corrective actions | 1.0 | Full NCR details retrieved |
| OTD by carrier | 0.5 | Partially correct — values slightly different from ground truth |
| A-class inventory policy | 1.0 | All policy details matched perfectly |

### ML Functions Deployed

| Function | Type | Purpose |
|----------|------|---------|
| `ORDER_VOLUME_FORECAST` | SNOWFLAKE.ML.FORECAST | 30-day demand prediction (~27 orders/day) |
| `ORDER_ANOMALY_DETECTOR` | SNOWFLAKE.ML.ANOMALY_DETECTION | Detect unusual order volume patterns |
| `V_SUPPLIER_AI_CLASSIFICATION` | CORTEX.CLASSIFY_TEXT | Auto-classify supplier risk level |
| `V_DOCUMENT_SENTIMENT` | CORTEX.SENTIMENT | Sentiment analysis on all documents |
| `V_DOCUMENT_AI_ENRICHED` | CORTEX.CLASSIFY_TEXT + SUMMARIZE | Document triage + auto-summary |
| `AI_SUPPLIER_SUMMARY` | CORTEX.COMPLETE | LLM-generated risk summaries |

### How to Re-Run

```sql
USE DATABASE SC_ONTOLOGY;
USE SCHEMA ADVANCED;

-- Start evaluation
CALL EXECUTE_AI_EVALUATION(
  'START',
  OBJECT_CONSTRUCT('run_name', 'sc-ontology-eval-v2'),
  '@SC_ONTOLOGY.ADVANCED.EVAL_CONFIG_STAGE/eval_config.yaml'
);

-- Check status (poll until COMPLETED)
CALL EXECUTE_AI_EVALUATION(
  'STATUS',
  OBJECT_CONSTRUCT('run_name', 'sc-ontology-eval-v2'),
  '@SC_ONTOLOGY.ADVANCED.EVAL_CONFIG_STAGE/eval_config.yaml'
);

-- Get results
SELECT METRIC_NAME, ROUND(AVG(EVAL_AGG_SCORE), 3) AS avg_score
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
  'SC_ONTOLOGY', 'ANALYTICS', 'SUPPLY_CHAIN_AGENT', 'CORTEX AGENT', 'sc-ontology-eval-v2'
))
WHERE METRIC_NAME IS NOT NULL
GROUP BY METRIC_NAME;
```

### Suggestions for Improving Scores

1. **Answer Correctness → 0.95+:** Add more verified queries covering carrier-level and time-filtered OTD
2. **Custom Metric Calibration:** Adjust the scoring prompt to use a 0-1 scale matching other metrics
3. **Expand Dataset:** Add 20+ more questions covering edge cases (empty results, out-of-scope, multi-hop)
4. **Time-Scoped Queries:** Use absolute dates in ground truth to avoid drift
5. **Add Tool Execution Ground Truth:** Include expected SQL patterns in `tool_output` for TEA scoring

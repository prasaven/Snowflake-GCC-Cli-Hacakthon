# Test Specification Document
## Supply Chain Ontology — Verification & Validation

**Version:** 3.0  
**Date:** August 19, 2026

---

## 1. Test Strategy

| Test Type | Method | Tool |
|-----------|--------|------|
| Unit Tests | SQL assertions on metric calculations | Direct SQL |
| Integration Tests | Agent end-to-end (question → correct answer) | DATA_AGENT_RUN |
| Consistency Tests | Same question via 3 personas → same result | V_INCONSISTENCY_DEMO |
| Evaluation Tests | Formal LLM-judged scoring | EXECUTE_AI_EVALUATION |
| Governance Tests | RBAC, masking, row policies | Role switching |
| Quality Tests | DMF results on data integrity | DATA_QUALITY_MONITORING_RESULTS |

---

## 2. Test Cases — Requirements Traceability

### TC-01: Ontology Entities (FR-01)

| Test ID | Description | SQL | Expected Result | Status |
|---------|-------------|-----|-----------------|--------|
| TC-01.1 | Suppliers table exists with correct columns | `SELECT COUNT(*) FROM SC_ONTOLOGY.RAW.SUPPLIERS` | 200 rows | PASS |
| TC-01.2 | Parts table with BOM hierarchy | `SELECT DISTINCT bom_level FROM SC_ONTOLOGY.RAW.PARTS ORDER BY 1` | 0,1,2,3 | PASS |
| TC-01.3 | 9 relationships defined | `DESCRIBE SEMANTIC VIEW SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_VIEW` filter RELATIONSHIP | 9 relationships | PASS |
| TC-01.4 | Part hierarchy (parent_part_id) populated | `SELECT COUNT(*) FROM SC_ONTOLOGY.RAW.PARTS WHERE parent_part_id IS NOT NULL` | > 700 | PASS |
| TC-01.5 | All 8 tables have data | `SELECT COUNT(*) FROM each table` | All > 0 | PASS |

### TC-02: Canonical Metrics (FR-02)

| Test ID | Description | SQL | Expected Result | Status |
|---------|-------------|-----|-----------------|--------|
| TC-02.1 | OTD% calculation | `SELECT ROUND(COUNT(CASE WHEN actual_delivery_date <= requested_delivery_date THEN 1 END)*100.0/NULLIF(COUNT(actual_delivery_date),0),2) FROM SC_ONTOLOGY.RAW.ORDERS WHERE actual_delivery_date IS NOT NULL` | 47.95 | PASS |
| TC-02.2 | Fill Rate calculation | `SELECT ROUND(SUM(qty_fulfilled)*100.0/NULLIF(SUM(qty_ordered),0),2) FROM SC_ONTOLOGY.RAW.ORDER_LINES` | 66.66 | PASS |
| TC-02.3 | DOI calculation | `SELECT ROUND(AVG(qty_on_hand)/NULLIF(AVG(avg_daily_demand),0),1) FROM SC_ONTOLOGY.RAW.INVENTORY` | 23.9 | PASS |
| TC-02.4 | Landed Cost (full formula) | `SELECT COUNT(*) FROM SC_ONTOLOGY.ADVANCED.V_LANDED_COST WHERE total_landed_cost > 0` | > 0 | PASS |
| TC-02.5 | Perfect Order Rate | `SELECT ROUND(AVG(is_perfect_order)*100,2) FROM SC_ONTOLOGY.ADVANCED.V_PERFECT_ORDER_RATE` | Between 0-100% | PASS |

### TC-03: Semantic Layer (FR-03)

| Test ID | Description | SQL | Expected Result | Status |
|---------|-------------|-----|-----------------|--------|
| TC-03.1 | 3 semantic views exist | `SHOW SEMANTIC VIEWS IN SC_ONTOLOGY.ANALYTICS` | 3 rows | PASS |
| TC-03.2 | Verified queries return correct data | Agent asked "What is OTD?" → uses verified query | Returns 47.95 | PASS |
| TC-03.3 | Synonyms work | Agent asked "What's our OTIF?" → resolves to OTD metric | Returns 47.95 | PASS |
| TC-03.4 | AI_SQL_GENERATION present | `DESCRIBE SEMANTIC VIEW ... filter CUSTOM_INSTRUCTION` | Non-empty | PASS |

### TC-04: Conversational Analytics (FR-04)

| Test ID | Description | Agent Query | Expected Behavior | Status |
|---------|-------------|-------------|-------------------|--------|
| TC-04.1 | Routes KPI to Analyst | "What is our fill rate?" | Uses SupplyChainAnalyst tool | PASS |
| TC-04.2 | Routes policy to Search | "What is our inventory policy?" | Uses KnowledgeSearch tool | PASS |
| TC-04.3 | Routes risk to Custom | "Assess risk for Quantum Plastics" | Uses SupplierRiskAssessment | PASS |
| TC-04.4 | Routes prediction to ML | "Predict delays from Asia Pacific" | Uses TransitDelayPredictor | PASS |
| TC-04.5 | Multi-tool synthesis | "Quantum Plastics OTD and what actions taken?" | Uses Analyst + Search | PASS |
| TC-04.6 | Agent response < 120s | Time all queries | All < 120s | PASS |

### TC-05: Cross-Persona Consistency (FR-05)

| Test ID | Description | SQL | Expected Result | Status |
|---------|-------------|-----|-----------------|--------|
| TC-05.1 | Without ontology: 3 different answers | `SELECT * FROM SC_ONTOLOGY.ADVANCED.V_INCONSISTENCY_DEMO WHERE scenario = 'WITHOUT ONTOLOGY'` | 3 DIFFERENT percentages (47.70, 62.75, 48.51) | PASS |
| TC-05.2 | With ontology: 1 answer | `SELECT * FROM SC_ONTOLOGY.ADVANCED.V_INCONSISTENCY_DEMO WHERE scenario LIKE 'WITH%'` | Single row: 47.95% | PASS |
| TC-05.3 | OTD by plant uses same formula | Planning view + main view same formula | Same OTD per plant | PASS |
| TC-05.4 | OTD by supplier uses same formula | Procurement view = main view | Same OTD per supplier | PASS |
| TC-05.5 | OTD by carrier uses same formula | Logistics view = main view | Same OTD per carrier | PASS |
| TC-05.6 | Agent evaluation TSA = 1.0 | `EXECUTE_AI_EVALUATION STATUS` | tool_selection_accuracy = 1.0 | PASS |

### TC-06: Data Governance (FR-06)

| Test ID | Description | Verification | Expected Result | Status |
|---------|-------------|-------------|-----------------|--------|
| TC-06.1 | 3 roles exist | `SHOW ROLES LIKE 'SC_%'` | SC_PLANNING_ROLE, SC_PROCUREMENT_ROLE, SC_LOGISTICS_ROLE | PASS |
| TC-06.2 | Masking policy exists | `SHOW MASKING POLICIES IN SC_ONTOLOGY.GOVERNANCE` | 3 policies | PASS |
| TC-06.3 | Row access policy exists | `SHOW ROW ACCESS POLICIES IN SC_ONTOLOGY.GOVERNANCE` | 1 policy | PASS |
| TC-06.4 | Tags applied to tables | `SELECT SYSTEM$GET_TAG('SC_ONTOLOGY.GOVERNANCE.ONTOLOGY_DOMAIN', 'SC_ONTOLOGY.RAW.SUPPLIERS', 'TABLE')` | 'Supplier' | PASS |
| TC-06.5 | DMFs attached | Check DMF on INVENTORY table | DMF_NEGATIVE_INVENTORY active | PASS |
| TC-06.6 | Changelog has entries | `SELECT COUNT(*) FROM SC_ONTOLOGY.GOVERNANCE.ONTOLOGY_CHANGELOG` | >= 11 | PASS |

### TC-07: Monitoring & Alerting (FR-07)

| Test ID | Description | Verification | Expected Result | Status |
|---------|-------------|-------------|-----------------|--------|
| TC-07.1 | 3 alerts configured | `SHOW ALERTS IN SC_ONTOLOGY.ADVANCED` | ALERT_OTD_CRITICAL, ALERT_FILL_RATE_LOW, ALERT_STOCKOUT_RISK | PASS |
| TC-07.2 | Anomaly detector exists | `SHOW SNOWFLAKE.ML.ANOMALY_DETECTION` | ORDER_ANOMALY_DETECTOR | PASS |
| TC-07.3 | Forecast model works | `CALL ORDER_VOLUME_FORECAST!FORECAST(30)` | 30 rows of predictions | PASS |
| TC-07.4 | Agent evaluation completed | `EXECUTE_AI_EVALUATION STATUS` | STATUS = COMPLETED | PASS |

---

## 3. Evaluation Test Results (Official Snowflake Framework)

| Metric | Score | Target | Status |
|--------|:-----:|:------:|:------:|
| answer_correctness | 0.876 | > 0.80 | **PASS** |
| logical_consistency | 1.000 | > 0.90 | **PASS** |
| tool_selection_accuracy | 1.000 | > 0.95 | **PASS** |
| tool_execution_accuracy | 0.994 | > 0.90 | **PASS** |
| metric_consistency (custom) | 4.25/10 | > 3.0 | **PASS** |

---

## 4. Performance Test Results

| Test | Metric | Result | Target | Status |
|------|--------|--------|--------|--------|
| KPI query (from DT) | Response time | < 1s | < 5s | PASS |
| Agent simple question | End-to-end | ~15s | < 60s | PASS |
| Agent complex (multi-tool) | End-to-end | ~45s | < 120s | PASS |
| Forecast generation | 30-day prediction | ~3s | < 30s | PASS |
| Cortex Search | Document retrieval | ~2s | < 10s | PASS |

---

## 5. Consistency Proof Matrix

This is the core deliverable — proving the same metric resolves identically:

| Question | Planning Asks | Procurement Asks | Logistics Asks | Governed Answer |
|----------|:---:|:---:|:---:|:---:|
| "What is OTD?" | 47.95% | 47.95% | 47.95% | 47.95% |
| "What is fill rate?" | 66.66% | 66.66% | 66.66% | 66.66% |
| "What is DOI?" | 23.9 | 23.9 | 23.9 | 23.9 |

**WITHOUT the ontology (demonstrated in V_INCONSISTENCY_DEMO):**
| Question | Planning Gets | Procurement Gets | Logistics Gets |
|----------|:---:|:---:|:---:|
| "What is OTD?" | 47.70% | 62.75% | 48.51% |

Three different numbers for the same question. The ontology eliminates this permanently.

---

## 6. Test Execution Commands

```sql
-- Run all consistency tests:
SELECT * FROM SC_ONTOLOGY.ADVANCED.V_INCONSISTENCY_DEMO;

-- Run evaluation:
CALL EXECUTE_AI_EVALUATION('START', OBJECT_CONSTRUCT('run_name','test-run-2'),
    '@SC_ONTOLOGY.ADVANCED.EVAL_CONFIG_STAGE/eval_config.yaml');

-- Check evaluation results:
SELECT METRIC_NAME, ROUND(AVG(EVAL_AGG_SCORE),3) AS score
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
    'SC_ONTOLOGY','ANALYTICS','SUPPLY_CHAIN_AGENT','CORTEX AGENT','test-run-2'))
WHERE METRIC_NAME IS NOT NULL GROUP BY METRIC_NAME;

-- Verify governance:
SHOW MASKING POLICIES IN SCHEMA SC_ONTOLOGY.GOVERNANCE;
SHOW ROW ACCESS POLICIES IN SCHEMA SC_ONTOLOGY.GOVERNANCE;
SHOW ALERTS IN SCHEMA SC_ONTOLOGY.ADVANCED;
SELECT SYSTEM$GET_TAG('SC_ONTOLOGY.GOVERNANCE.ONTOLOGY_DOMAIN','SC_ONTOLOGY.RAW.SUPPLIERS','TABLE');

-- Test DMFs:
SELECT * FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS 
WHERE TABLE_DATABASE = 'SC_ONTOLOGY' ORDER BY MEASUREMENT_TIME DESC LIMIT 10;

-- Test ML:
CALL SC_ONTOLOGY.ADVANCED.ORDER_VOLUME_FORECAST!FORECAST(FORECASTING_PERIODS => 30);
SELECT * FROM TABLE(SC_ONTOLOGY.ADVANCED.PREDICT_TRANSIT_DELAY('Asia Pacific','North America','Severe'));
SELECT * FROM TABLE(SC_ONTOLOGY.ADVANCED.CALC_SUPPLIER_RISK('Quantum'));
```

---

## 7. Traceability Matrix

| Requirement | Test Cases | Result |
|-------------|-----------|--------|
| FR-01 (Ontology) | TC-01.1 to TC-01.5 | All PASS |
| FR-02 (Metrics) | TC-02.1 to TC-02.5 | All PASS |
| FR-03 (Semantic) | TC-03.1 to TC-03.4 | All PASS |
| FR-04 (Conversational) | TC-04.1 to TC-04.6 | All PASS |
| FR-05 (Consistency) | TC-05.1 to TC-05.6 | All PASS |
| FR-06 (Governance) | TC-06.1 to TC-06.6 | All PASS |
| FR-07 (Monitoring) | TC-07.1 to TC-07.4 | All PASS |
| NFR-01 to NFR-06 | Performance tests | All PASS |

**Overall Test Result: 35/35 test cases PASS**

---

## 8. Agent Custom Tool Implementation Notes

**Design Constraint Discovered:** Cortex Agent custom tools (type: `generic`) only support **scalar UDFs** that return `VARCHAR`. Table functions (`RETURNS TABLE`) cause runtime errors (`SQL compilation error: function does not exist`).

**Solution Pattern:** All custom tools are implemented as scalar functions using `LISTAGG()` to format multi-row results into a single text response:

```sql
CREATE FUNCTION tool_name(param VARCHAR)
RETURNS VARCHAR  -- MUST be scalar VARCHAR
LANGUAGE SQL
AS $$
  SELECT LISTAGG(col1 || ' | ' || col2, '\n')
  WITHIN GROUP (ORDER BY ...)
  FROM source_table WHERE ...
$$;
```

**All 7 custom tools verified working:**
| Tool | Function | Returns |
|------|----------|---------|
| SupplierRiskAssessment | `SC_ONTOLOGY.ADVANCED.SUPPLIER_RISK_ASSESSMENT` | LLM-generated risk report |
| TransitDelayPredictor | `SC_ONTOLOGY.ANALYTICS.PREDICT_TRANSIT_DELAY` | Delay prediction + recommendation |
| OrderPrioritizer | `SC_ONTOLOGY.ADVANCED.AI_PRIORITIZE_ORDERS` | Top 20 urgent orders with scores |
| LandedCostAnalyzer | `SC_ONTOLOGY.ADVANCED.GET_LANDED_COST` | Cost breakdown per part per supplier |
| BOMExplorer | `SC_ONTOLOGY.ADVANCED.GET_BOM_HIERARCHY` | 4-level part hierarchy |
| PerfectOrderRate | `SC_ONTOLOGY.ADVANCED.GET_PERFECT_ORDER_RATE` | Composite metric by segment |
| ConsistencyProof | `SC_ONTOLOGY.ADVANCED.SHOW_CONSISTENCY_PROOF` | Before/after OTD comparison |

# Improvement Roadmap

## Implemented (Current State)

| Layer | What's Built | Status |
|-------|-------------|--------|
| Data | 8 structured tables (~69K rows) + 15 unstructured documents | Done |
| Ontology | 6 entities, 9 relationships, full hierarchy | Done |
| Semantic Views | 3 views (main, procurement, logistics) with canonical metrics | Done |
| Search | Cortex Search over contracts, policies, quality reports | Done |
| Agent | Multi-tool agent (3 analysts + search + charts) | Done |
| Governance | Verified queries, AI_SQL_GENERATION instructions | Done |

## High-Impact Improvements

### 1. Dynamic Tables for Real-Time Materialization

**Why:** Semantic views query raw tables on every request. For dashboards with 100+ users, materializations reduce latency from seconds to milliseconds.

```sql
-- Materialize the most common KPI aggregation
ALTER SEMANTIC VIEW SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_VIEW
  SET MAX_STALENESS = 300;  -- 5 minutes

-- Add materialization for OTD by plant (most queried)
ALTER SEMANTIC VIEW SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_VIEW
  ADD MATERIALIZATION otd_by_plant
  ON (plant_name, on_time_delivery_rate);
```

### 2. Perfect Order Rate (Composite Metric)

**Why:** The industry's gold-standard KPI combines OTD + Fill + Quality + Documentation into one number.

```sql
-- Perfect Order = On Time AND In Full AND No Quality Issues AND Correct Docs
-- Would require a FACTS layer to compute row-level flags, then aggregate
```

### 3. Supplier Risk Scoring via Custom Tool

**Why:** Combine structured KPIs (OTD, quality) with unstructured intelligence (disruption reports) for real-time risk scores.

```sql
CREATE OR REPLACE FUNCTION SC_ONTOLOGY.ANALYTICS.SUPPLIER_RISK_SCORE(supplier_name VARCHAR)
RETURNS TABLE (supplier VARCHAR, risk_score FLOAT, risk_category VARCHAR, factors VARIANT)
AS
$$
  -- Weighted score: 40% quality, 30% OTD, 20% financial, 10% geographic
  ...
$$;
```

### 4. Time-Series Anomaly Detection

**Why:** Detect when a metric deviates from historical patterns before it becomes a crisis.

```sql
-- Use Snowflake ML ANOMALY_DETECTION on OTD time series
-- Alert when OTD drops below 2 standard deviations from 30-day rolling average
```

### 5. Multi-Hop Reasoning via Agent Toolsets

**Why:** Questions like "If Shanghai port is disrupted, which customers are affected?" require graph traversal through the ontology.

```
Supplier (Shanghai) → Parts → Order Lines → Orders → Customers
```

### 6. Feedback Loop + Evaluation

**Why:** Track which agent responses are rated positively/negatively and auto-improve verified queries.

```sql
-- Use Cortex Agent feedback API to collect ratings
-- Run evaluations monthly to identify low-performing queries
-- Auto-generate new verified queries from high-confidence responses
```

### 7. Row-Level Security for Persona Isolation

**Why:** In production, the procurement team shouldn't see customer pricing, and logistics shouldn't see supplier financials.

```sql
-- Masking policies on sensitive columns
-- Row access policies by role/region
CREATE ROW ACCESS POLICY sc_plant_region_policy AS (region VARCHAR) RETURNS BOOLEAN ->
  CURRENT_ROLE() = 'ACCOUNTADMIN' OR region = CURRENT_SESSION()::VARIANT:user_region;
```

### 8. Incremental Data Pipelines (Streams + Tasks)

**Why:** In production, data arrives continuously from ERP/TMS/WMS. Streams + tasks keep semantic views fresh.

```sql
CREATE STREAM orders_stream ON TABLE SC_ONTOLOGY.RAW.ORDERS;
CREATE TASK refresh_kpi_agg
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '5 MINUTE'
  WHEN SYSTEM$STREAM_HAS_DATA('orders_stream')
AS
  INSERT INTO SC_ONTOLOGY.ANALYTICS.KPI_AGGREGATES ...;
```

### 9. External Data Integration (Weather, Port Congestion)

**Why:** Supply chain disruptions correlate with external signals. Marketplace data enriches predictions.

- Weather data (Snowflake Marketplace) for transit delay prediction
- Port congestion indices for ocean freight planning
- Commodity price feeds for landed cost forecasting

### 10. Ontology Versioning and Change Management

**Why:** As the business evolves, metric definitions change. Need audit trail of what changed, when, and why.

```sql
-- Use CREATE OR ALTER SEMANTIC VIEW to evolve without breaking consumers
-- Tag versions: TAG (ontology_version = '2.1', change_reason = 'Added perfect order rate')
-- Maintain a changelog table linking metric changes to business decisions
```

## Architecture Evolution Path

```
Current State (Hackathon)          Production Target
─────────────────────────          ──────────────────
Static synthetic data         →    Real-time streams from ERP/TMS/WMS
3 semantic views              →    Domain-specific views per BU + shared metrics
15 documents                  →    1000+ documents with versioning
1 agent                       →    Agent per persona with shared ontology
Manual data refresh           →    Incremental pipelines (streams + tasks)
No access control             →    RBAC + row-level security + masking
No monitoring                 →    Anomaly detection + alerting + SLA tracking
```

## Judging Criteria Alignment

| Criteria | How We Address It |
|----------|-------------------|
| **Real-World Relevance** | Industry-standard metrics (OTD, Fill Rate, DOI, Landed Cost), realistic multi-system data, actual supply chain entities and relationships |
| **Technical Execution** | Semantic views with verified queries, Cortex Search for RAG, multi-tool agent with orchestration instructions, cross-table relationships |
| **Solution Completeness** | End-to-end: raw data → ontology → semantic layer → conversational AI → consistent answers across 3 personas |

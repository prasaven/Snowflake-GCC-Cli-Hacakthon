# Solution Document
## Supply Chain Ontology on Snowflake — Complete Solution

**Version:** 3.0  
**Date:** August 19, 2026

---

## 1. Solution Overview

We built an **industry supply chain ontology** expressed as **governed Snowflake semantic views**, with a **Cortex Agent** providing natural language analytics that returns consistent, trustworthy answers across all teams.

**Key Innovation:** The same metric formula is defined ONCE in the semantic view and enforced for ALL users — eliminating the "3 teams, 3 answers" problem permanently.

---

## 2. End-to-End Architecture

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                    SUPPLY CHAIN INTELLIGENCE PLATFORM                         ║
╚═══════════════════════════════════════════════════════════════════════════════╝

┌───────────────────────── USER LAYER ──────────────────────────────────────────┐
│                                                                               │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────┐    ┌────────────┐   │
│  │  PLANNING   │    │ PROCUREMENT  │    │  LOGISTICS  │    │ EXECUTIVE  │   │
│  │  (Demand,   │    │  (Suppliers, │    │  (Carriers, │    │ (KPI Dash, │   │
│  │   Capacity) │    │   Spend)     │    │   Freight)  │    │  Strategy) │   │
│  └──────┬──────┘    └──────┬───────┘    └──────┬──────┘    └─────┬──────┘   │
│         │                  │                    │                  │          │
│         └──────────────────┼────────────────────┼──────────────────┘          │
│                            ▼                    ▼                              │
│              ┌─────────────────────────────────────────┐                     │
│              │       STREAMLIT ADMIN CONSOLE            │                     │
│              │  7 pages: Dashboard, AI, Monitoring,     │                     │
│              │  Governance, Quality, Alerts, Ontology   │                     │
│              └─────────────────┬───────────────────────┘                     │
└────────────────────────────────┼──────────────────────────────────────────────┘
                                 │
                                 ▼
┌───────────────────── AGENT LAYER (Orchestration) ─────────────────────────────┐
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │              SUPPLY_CHAIN_AGENT (claude-sonnet-4-5)                      │ │
│  │                                                                         │ │
│  │   PLAN ──► SELECT TOOL ──► EXECUTE ──► REFLECT ──► RESPOND             │ │
│  │                                                                         │ │
│  │   8 TOOLS:                                                              │ │
│  │   [SupplyChainAnalyst] [ProcurementAnalyst] [LogisticsAnalyst]         │ │
│  │   [KnowledgeSearch] [SupplierRiskAssessment] [TransitDelayPredictor]   │ │
│  │   [OrderPrioritizer] [data_to_chart]                                    │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌───────────────────── SEMANTIC LAYER (Ontology) ───────────────────────────────┐
│                                                                               │
│  ┌───────────────────┐  ┌─────────────────┐  ┌──────────────────┐           │
│  │ SUPPLY_CHAIN_VIEW │  │ PROCUREMENT_VIEW │  │  LOGISTICS_VIEW  │           │
│  │ (Full Ontology)   │  │ (Supplier Focus) │  │ (Carrier Focus)  │           │
│  │ 8 tables          │  │ 4 tables         │  │ 3 tables         │           │
│  │ 13 metrics        │  │ 6 metrics        │  │ 6 metrics        │           │
│  │ 29 dimensions     │  │ 13 dimensions    │  │ 10 dimensions    │           │
│  │ 5 verified queries│  │                  │  │                  │           │
│  └───────────────────┘  └─────────────────┘  └──────────────────┘           │
│                                                                               │
│  CANONICAL METRICS (defined ONCE, enforced EVERYWHERE):                       │
│  • OTD% = delivered_on_time / total_delivered * 100                          │
│  • Fill Rate = qty_fulfilled / qty_ordered * 100                             │
│  • DOI = avg(qty_on_hand) / avg(daily_demand)                                │
│  • Landed Cost = material + freight + duties + handling                      │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌───────────────────── DATA & ML LAYER ─────────────────────────────────────────┐
│                                                                               │
│  STRUCTURED (RAW)          UNSTRUCTURED          ML MODELS                   │
│  ┌──────────────────┐     ┌──────────────┐     ┌──────────────────────┐     │
│  │ SUPPLIERS   (200)│     │ 15 Documents │     │ ORDER_VOLUME_FORECAST│     │
│  │ PARTS      (1000)│     │ • Contracts  │     │ ORDER_ANOMALY_DETECT │     │
│  │ PLANTS       (12)│     │ • Policies   │     │ WEATHER_TRANSIT_DATA │     │
│  │ CUSTOMERS   (500)│     │ • NCRs       │     │                      │     │
│  │ ORDERS    (10000)│     │ • Procedures │     │ AI FUNCTIONS:        │     │
│  │ ORDER_LINES(25K) │     │              │     │ • CORTEX.COMPLETE    │     │
│  │ SHIPMENTS  (8000)│     │ Cortex Search│     │ • CORTEX.SENTIMENT   │     │
│  │ INVENTORY  (5000)│     │ Service      │     │ • CORTEX.CLASSIFY    │     │
│  │ IOT_SENSORS(20K) │     └──────────────┘     │ • CORTEX.SUMMARIZE   │     │
│  └──────────────────┘                           └──────────────────────┘     │
│                                                                               │
│  DYNAMIC TABLES (auto-refresh 30 min):                                       │
│  • DT_SUPPLIER_SCORECARD • DT_INVENTORY_HEALTH • DT_OTD_BY_PLANT            │
│                                                                               │
│  GOVERNANCE:                                                                  │
│  • 3 Roles (Planning, Procurement, Logistics)                                │
│  • 3 Masking Policies • 1 Row Access Policy • 3 DMFs                         │
│  • 4 Tags • 3 Alerts • Ontology Changelog                                    │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌───────────────────── EVALUATION LAYER ────────────────────────────────────────┐
│                                                                               │
│  EXECUTE_AI_EVALUATION (Native Snowflake Agent Evaluation)                    │
│  • 8 ground-truth questions • 5 metrics scored by LLM judges                │
│  • Results: answer_correctness=0.876, tool_selection=1.0,                    │
│             logical_consistency=1.0, tool_execution=0.994                     │
│                                                                               │
└───────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. User Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         USER JOURNEY FLOW                                    │
└─────────────────────────────────────────────────────────────────────────────┘

USER ASKS QUESTION (Natural Language)
         │
         ▼
┌─────────────────────┐
│ Agent Receives Query │
│ (Parse + Classify)   │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────┐
│              ROUTING DECISION                             │
│                                                          │
│  Is it quantitative?  ──YES──► Which domain?            │
│         │                       ├─ Cross-domain → SupplyChainAnalyst
│         │                       ├─ Supplier → ProcurementAnalyst
│         │                       └─ Carrier → LogisticsAnalyst
│         │                                    │
│         NO                                   ▼
│         │                       ┌──────────────────────┐
│         ▼                       │ Semantic View executes│
│  Is it policy/contract? ─YES──► │ canonical formula     │
│         │                       │ (never overridden)    │
│         │                       └──────────────────────┘
│         NO                               │
│         │                                ▼
│         ▼                       ┌──────────────────────┐
│  Is it risk assessment? ──YES─► │ SQL generated +       │
│         │                       │ Results returned      │
│         │                       └──────────────────────┘
│         NO                               │
│         │                                ▼
│         ▼                       ┌──────────────────────┐
│  Is it prediction? ──────YES──► │ Agent REFLECTS:       │
│         │                       │ Is answer complete?   │
│         │                       │ Need another tool?    │
│         NO                      └──────────┬───────────┘
│         │                                  │
│         ▼                                  ▼
│  Out of scope → Politely decline   FINAL RESPONSE
│                                    (with source citation,
│                                     canonical definition,
│                                     and suggested follow-ups)
└─────────────────────────────────────────────────────────┘

         ║
         ▼
┌─────────────────────────────────────────────────────────┐
│              CONSISTENCY GUARANTEE                        │
│                                                          │
│  Regardless of WHO asks or HOW they phrase it:           │
│                                                          │
│  "What's OTD?"          ─┐                              │
│  "Delivery performance?" ─┼──► SAME formula ──► 47.95%  │
│  "How often are we late?"─┘    SAME number    ──► 47.95% │
│                                SAME source    ──► 47.95% │
│                                                          │
│  BECAUSE: Formula encoded ONCE in semantic view,         │
│  enforced by AI_SQL_GENERATION, validated by             │
│  AI_VERIFIED_QUERIES, evaluated by EXECUTE_AI_EVALUATION │
└─────────────────────────────────────────────────────────┘
```

---

## 4. Data Flow

```
SOURCE SYSTEMS                    SNOWFLAKE                         CONSUMERS
──────────────                    ─────────                         ─────────

SAP/Oracle ERP ──────► ORDERS, ORDER_LINES, PARTS ──┐
                                                     │
TMS (Blue Yonder) ───► SHIPMENTS ───────────────────┤
                                                     │
WMS (Manhattan) ─────► INVENTORY ───────────────────┤──► Semantic ──► Agent ──► Users
                                                     │    Views          │
Supplier Portal ─────► SUPPLIERS ───────────────────┤                   │
                                                     │              Streamlit
IoT Platform ────────► IOT_SENSOR_READINGS ─────────┤              Dashboard
                                                     │
Documents ───────────► SUPPLY_CHAIN_KNOWLEDGE ──────┤──► Cortex
(SharePoint, etc.)                                        Search

Weather APIs ────────► WEATHER_TRANSIT_DATA ────────┘──► ML Models
(Marketplace)                                             (Forecast,
                                                           Anomaly)
```

---

## 5. Ontology Entity-Relationship Model

```
                         ┌─────────────────┐
                         │    SUPPLIER      │
                         │─────────────────│
                         │ supplier_id (PK) │
                         │ name, tier       │
                         │ country, region  │
                         │ quality_score    │
                         │ lead_time_days   │
                         └────────┬────────┘
                                  │ supplies (1:N)
                                  ▼
┌─────────────────┐        ┌─────────────────┐        ┌─────────────────┐
│    CUSTOMER      │        │      PART        │        │     PLANT        │
│─────────────────│        │─────────────────│        │─────────────────│
│ customer_id (PK) │        │ part_id (PK)     │        │ plant_id (PK)    │
│ name, segment    │        │ name, category   │        │ name, region     │
│ region, country  │        │ unit_cost        │        │ country, type    │
│ annual_revenue   │        │ abc_class        │        │ capacity         │
└────────┬────────┘        │ parent_part_id   │◄───────│                  │
         │                  │ bom_level (0-3)  │stocked │                  │
         │ places (1:N)     └────────┬────────┘  at    └────────┬────────┘
         │                           │                           │
         ▼                           ▼                           │
┌─────────────────┐        ┌─────────────────┐                  │
│     ORDER        │        │   ORDER_LINE     │                  │
│─────────────────│        │─────────────────│                  │
│ order_id (PK)    │◄───────│ order_line_id    │──────────────────┘
│ order_date       │contains│ qty_ordered      │ fulfilled_from
│ requested_date   │        │ qty_fulfilled    │
│ actual_date      │        │ unit_price       │
│ status, priority │        │ part_id (FK)     │
└────────┬────────┘        │ plant_id (FK)    │
         │                  └─────────────────┘
         │ fulfilled_via (1:N)
         ▼
┌─────────────────┐        ┌─────────────────┐
│    SHIPMENT      │        │    INVENTORY     │
│─────────────────│        │─────────────────│
│ shipment_id (PK) │        │ inventory_id(PK) │
│ carrier          │        │ part_id (FK)     │
│ transport_mode   │        │ plant_id (FK)    │
│ ship_date        │        │ qty_on_hand      │
│ actual_arrival   │        │ avg_daily_demand │
│ freight_cost     │        │ safety_stock     │
│ origin_plant(FK) │        │ reorder_point    │
└─────────────────┘        └─────────────────┘

BOM HIERARCHY (within PARTS):
  Raw Material (level 0) ──► Component (level 1) ──► Sub-Assembly (level 2) ──► Finished Good (level 3)
```

---

## 6. Snowflake Features Utilized (28 Total)

| # | Feature | Category | Purpose |
|---|---------|----------|---------|
| 1 | Semantic Views (3) | Governance | Ontology encoding |
| 2 | Cortex Agent | AI | Natural language orchestration |
| 3 | Cortex Analyst | AI | Text-to-SQL via semantic views |
| 4 | Cortex Search | AI | RAG over documents |
| 5 | CORTEX.COMPLETE | AI | LLM risk summaries |
| 6 | CORTEX.SENTIMENT | AI | Document sentiment scoring |
| 7 | CORTEX.CLASSIFY_TEXT | AI | Supplier/document classification |
| 8 | CORTEX.SUMMARIZE | AI | Auto document summaries |
| 9 | ML.FORECAST | ML | Demand prediction |
| 10 | ML.ANOMALY_DETECTION | ML | Unusual pattern detection |
| 11 | Dynamic Tables (3) | Performance | Auto-refresh KPIs |
| 12 | Streams | Data Eng | Change data capture |
| 13 | Tasks | Automation | Scheduled processing |
| 14 | Alerts (3) | Monitoring | Proactive KPI watching |
| 15 | Data Metric Functions (3) | Quality | Automated data quality |
| 16 | Object Tags (4) | Governance | Metadata classification |
| 17 | Row Access Policy | Security | Region-based filtering |
| 18 | Masking Policies (3) | Security | Column-level protection |
| 19 | Roles (3) | RBAC | Persona-based access |
| 20 | AI_VERIFIED_QUERIES | Governance | Pre-validated SQL |
| 21 | AI_SQL_GENERATION | Governance | Formula enforcement |
| 22 | Custom Tools (UDFs) | Extensibility | ML + LLM as agent tools |
| 23 | EXECUTE_AI_EVALUATION | Quality | Formal agent scoring |
| 24 | Streamlit in Snowflake | Application | Interactive admin console |
| 25 | Internal Stages | Infrastructure | Config/app storage |
| 26 | Views (computed) | Analytics | Derived insights |
| 27 | Stored Procedures | Automation | Evaluation runner |
| 28 | SYSTEM$CREATE_EVALUATION_DATASET | Quality | Evaluation dataset mgmt |

---

## 7. Cross-Persona Consistency Proof

### The Problem (Without Ontology)
```
Planning asks "What's OTD?"  ──► 47.70%  (uses shipment arrival date)
Procurement asks "What's OTD?" ► 62.75%  (adds 5-day grace period)
Logistics asks "What's OTD?"  ──► 48.51%  (excludes express orders)
```

### The Solution (With Ontology)
```
Planning asks "What's OTD?"  ──┐
Procurement asks "What's OTD?" ─┼──► 47.95% (canonical formula, always)
Logistics asks "What's OTD?"  ──┘
```

**How It's Enforced:**
1. Formula in SEMANTIC VIEW → cannot be overridden by ad-hoc SQL
2. AI_SQL_GENERATION instructions → forces agent to use canonical definition
3. VERIFIED_QUERIES → pre-validated SQL for exact match questions
4. EVALUATION → proves 100% tool selection accuracy across personas

---

## 8. Agent Tool Architecture (12 Tools)

The agent orchestrates 12 specialized tools, each implemented as the correct Snowflake object type:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                 SUPPLY_CHAIN_AGENT (12 TOOLS)                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  CORTEX ANALYST (Text-to-SQL via Semantic Views)                        │
│  ┌───────────────────┐ ┌──────────────────┐ ┌────────────────────┐    │
│  │SupplyChainAnalyst │ │ProcurementAnalyst│ │ LogisticsAnalyst   │    │
│  │(Full ontology)    │ │(Supplier focus)  │ │ (Carrier focus)    │    │
│  └───────────────────┘ └──────────────────┘ └────────────────────┘    │
│                                                                         │
│  CORTEX SEARCH (RAG)            VISUALIZATION                           │
│  ┌───────────────────┐         ┌────────────────────┐                  │
│  │ KnowledgeSearch   │         │ data_to_chart      │                  │
│  │ (15 documents)    │         │ (auto-generate)    │                  │
│  └───────────────────┘         └────────────────────┘                  │
│                                                                         │
│  CUSTOM TOOLS (Scalar UDFs returning VARCHAR)                           │
│  ┌───────────────────┐ ┌──────────────────┐ ┌────────────────────┐    │
│  │SupplierRisk       │ │TransitDelay      │ │ OrderPrioritizer   │    │
│  │Assessment         │ │Predictor         │ │ (scoring engine)   │    │
│  │(CORTEX.COMPLETE)  │ │(Weather+ML)      │ │                    │    │
│  └───────────────────┘ └──────────────────┘ └────────────────────┘    │
│  ┌───────────────────┐ ┌──────────────────┐ ┌────────────────────┐    │
│  │LandedCostAnalyzer │ │BOMExplorer       │ │ PerfectOrderRate   │    │
│  │(material+freight  │ │(4-level hierarchy│ │ (composite metric) │    │
│  │ +duties+handling) │ │ traversal)       │ │                    │    │
│  └───────────────────┘ └──────────────────┘ └────────────────────┘    │
│  ┌───────────────────┐                                                  │
│  │ConsistencyProof   │                                                  │
│  │(before/after demo)│                                                  │
│  └───────────────────┘                                                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Custom Tool Design Pattern

**Critical Learning:** Cortex Agent custom tools only support **scalar UDFs returning VARCHAR**.
Table functions (RETURNS TABLE) fail at runtime. The pattern is:

```sql
-- CORRECT: Scalar UDF returning formatted text
CREATE FUNCTION my_tool(param VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS $$
  SELECT LISTAGG(col1 || ' | ' || col2, '\n')
  FROM my_table WHERE ...
$$;
```

### Tool Routing Matrix

| User Question Pattern | Tool Selected | Data Source |
|----------------------|---------------|-------------|
| "What is OTD/fill rate/DOI?" | SupplyChainAnalyst | Semantic View (canonical) |
| "Supplier quality/spend/lead time?" | ProcurementAnalyst | Semantic View |
| "Carrier cost/shipment volume?" | LogisticsAnalyst | Semantic View |
| "What does the policy say?" | KnowledgeSearch | Cortex Search (RAG) |
| "Assess risk for [supplier]" | SupplierRiskAssessment | CORTEX.COMPLETE + metrics |
| "Predict delays from X to Y" | TransitDelayPredictor | Weather data + model |
| "Which orders to expedite?" | OrderPrioritizer | Scoring algorithm |
| "What is landed cost for X?" | LandedCostAnalyzer | material+freight+duties+handling |
| "Show BOM for [part]" | BOMExplorer | Parts hierarchy (4 levels) |
| "What is perfect order rate?" | PerfectOrderRate | Composite: OTD+InFull+Quality |
| "Prove OTD is consistent" | ConsistencyProof | Before/after comparison |
| "Show me a chart" | data_to_chart | Visualization engine |


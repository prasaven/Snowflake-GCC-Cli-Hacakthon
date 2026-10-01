# End-to-End Architecture & Solution Documentation

## End-to-End Architecture Diagram

```
╔══════════════════════════════════════════════════════════════════════════════════════════╗
║                           SUPPLY CHAIN INTELLIGENCE PLATFORM                             ║
║                         Snowflake-Native AI/ML Ontology Solution                         ║
╚══════════════════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ LAYER 1: USER INTERFACE (Natural Language)                                                │
│                                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐   │
│  │   PLANNING   │  │ PROCUREMENT  │  │  LOGISTICS   │  │     EXECUTIVE TEAM       │   │
│  │   "What is   │  │  "Risk for   │  │  "Predict    │  │  "Perfect order rate     │   │
│  │   our DOI?"  │  │   Quantum?"  │  │   delays?"   │  │   by customer segment?"  │   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────────┘   │
│         │                  │                  │                      │                    │
└─────────┼──────────────────┼──────────────────┼──────────────────────┼────────────────────┘
          │                  │                  │                      │
          ▼                  ▼                  ▼                      ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ LAYER 2: CORTEX AGENT (Orchestration + Reasoning)                                        │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │  SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT                                          │ │
│  │  Model: claude-sonnet-4-5 | Budget: 120s / 64K tokens                             │ │
│  │                                                                                    │ │
│  │  Orchestration Logic:                                                              │ │
│  │  ┌─────────┐    ┌──────────┐    ┌──────────┐    ┌─────────┐    ┌──────────────┐  │ │
│  │  │ PLAN    │───►│ SELECT   │───►│ EXECUTE  │───►│ REFLECT │───►│  RESPOND     │  │ │
│  │  │ (Parse) │    │ (Route)  │    │ (Tools)  │    │ (Verify)│    │  (Format)    │  │ │
│  │  └─────────┘    └──────────┘    └──────────┘    └─────────┘    └──────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ LAYER 3: TOOL LAYER (7 Specialized Tools)                                                │
│                                                                                          │
│  ┌─────────────────── STRUCTURED DATA (Cortex Analyst) ───────────────────────────┐    │
│  │                                                                                 │    │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐             │    │
│  │  │ SupplyChainAnalyst│  │ProcurementAnalyst│  │ LogisticsAnalyst │             │    │
│  │  │ (Full Ontology)  │  │ (Supplier Focus) │  │ (Carrier Focus)  │             │    │
│  │  │ 8 tables, 9 rels │  │ 4 tables, 3 rels │  │ 3 tables, 2 rels │             │    │
│  │  │ 13 metrics       │  │ 6 metrics        │  │ 6 metrics        │             │    │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘             │    │
│  │                                                                                 │    │
│  │  ALL USE SAME CANONICAL METRIC FORMULAS (Ontology-Governed)                     │    │
│  └─────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                          │
│  ┌─────── UNSTRUCTURED DATA (Cortex Search) ──┐  ┌──── AI/ML TOOLS (Custom) ──────┐   │
│  │                                             │  │                                 │   │
│  │  ┌───────────────────────────────────────┐  │  │  ┌────────────────────────────┐│   │
│  │  │ KnowledgeSearch                       │  │  │  │ SupplierRiskAssessment     ││   │
│  │  │ 15 docs: contracts, policies,        │  │  │  │ (CORTEX.COMPLETE + metrics) ││   │
│  │  │ quality reports, procedures           │  │  │  │ LLM-generated risk reports ││   │
│  │  │ Filterable: category, type, entity    │  │  │  └────────────────────────────┘│   │
│  │  └───────────────────────────────────────┘  │  │  ┌────────────────────────────┐│   │
│  └─────────────────────────────────────────────┘  │  │ TransitDelayPredictor      ││   │
│                                                    │  │ (Weather + ML forecast)    ││   │
│  ┌─────── VISUALIZATION ──────────────────────┐   │  │ Predicts delays by route   ││   │
│  │  data_to_chart: Auto-generates charts      │   │  └────────────────────────────┘│   │
│  └────────────────────────────────────────────┘   └─────────────────────────────────┘   │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ LAYER 4: SEMANTIC LAYER (Ontology - Single Source of Truth)                              │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │ SUPPLY_CHAIN_VIEW (Primary Semantic View)                                          │ │
│  │                                                                                    │ │
│  │  ENTITIES:    Supplier → Part → Plant → Order → Customer → Shipment → Inventory   │ │
│  │  RELATIONSHIPS: 9 governed joins                                                   │ │
│  │  DIMENSIONS:   29 (time, geography, entity attributes)                             │ │
│  │  METRICS:      13 canonical (OTD%, Fill Rate, DOI, Freight/Unit, Revenue, etc.)    │ │
│  │  VERIFIED:     5 pre-validated SQL queries                                         │ │
│  │  AI INSTRUCTIONS: Canonical formula enforcement                                    │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ LAYER 5: DATA & ML LAYER                                                                 │
│                                                                                          │
│  ┌─── RAW TABLES ──────┐  ┌── DYNAMIC TABLES ──────┐  ┌── ML MODELS ──────────────┐   │
│  │ SUPPLIERS    (200)   │  │ DT_SUPPLIER_SCORECARD  │  │ ORDER_VOLUME_FORECAST     │   │
│  │ PARTS       (1000)   │  │ DT_INVENTORY_HEALTH    │  │ (SNOWFLAKE.ML.FORECAST)   │   │
│  │ PLANTS       (12)    │  │ DT_OTD_BY_PLANT        │  │                           │   │
│  │ CUSTOMERS   (500)    │  │ (30-min auto-refresh)  │  │ ORDER_ANOMALY_DETECTOR    │   │
│  │ ORDERS     (10000)   │  └────────────────────────┘  │ (SNOWFLAKE.ML.ANOMALY)    │   │
│  │ ORDER_LINES(25000)   │                               │                           │   │
│  │ SHIPMENTS  (8000)    │  ┌── AI VIEWS ────────────┐  │ WEATHER_TRANSIT_DATA      │   │
│  │ INVENTORY  (5000)    │  │ V_DOCUMENT_SENTIMENT   │  │ (365 days, 4 regions)     │   │
│  │ IOT_SENSORS(20000)   │  │ V_DOCUMENT_AI_ENRICHED │  └───────────────────────────┘   │
│  └──────────────────────┘  │ V_SUPPLIER_AI_CLASS    │                                   │
│                             │ V_PERFECT_ORDER_RATE   │  ┌── GOVERNANCE ──────────────┐  │
│  ┌── DOCUMENTS ─────────┐  │ V_OTD_DAILY_TIMESERIES │  │ ONTOLOGY_CHANGELOG        │  │
│  │ 15 unstructured docs │  └────────────────────────┘  │ PERSONA_REGION_ACCESS     │  │
│  │ (contracts, policies,│                               │ KPI_ALERT_LOG             │  │
│  │  quality reports)    │  ┌── STREAMS/TASKS ────────┐  │ COUNTRY_RISK_INDEX        │  │
│  └──────────────────────┘  │ ORDERS_STREAM           │  └───────────────────────────┘  │
│                             │ TASK_REFRESH_KPI_ALERTS │                                  │
│                             └────────────────────────┘                                   │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│ LAYER 6: EVALUATION & OBSERVABILITY                                                      │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │ CORTEX AGENT EVALUATION (EXECUTE_AI_EVALUATION)                                    │ │
│  │                                                                                    │ │
│  │  Dataset: 8 ground-truth questions (SC_AGENT_EVAL_DATASET_V1)                     │ │
│  │  Metrics: answer_correctness (0.876), logical_consistency (1.0),                   │ │
│  │           tool_selection_accuracy (1.0), tool_execution_accuracy (0.994)            │ │
│  │  Custom:  metric_consistency (formula adherence scoring)                           │ │
│  │  Results: GET_AI_EVALUATION_DATA → V_EVAL_SUMMARY                                 │ │
│  └────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## End-to-End Requirements Table

| # | Requirement | Category | Priority |
|---|-------------|----------|----------|
| R1 | Define supply chain ontology with core entities and relationships | Ontology | Critical |
| R2 | Establish canonical metrics (OTD, Fill Rate, DOI, Landed Cost) with single definitions | Governance | Critical |
| R3 | Encode ontology as semantic views so business meaning drives answers | Semantic Layer | Critical |
| R4 | Support natural language queries across Planning, Procurement, Logistics personas | Conversational AI | Critical |
| R5 | Prove same metric resolves identically regardless of who asks | Consistency | Critical |
| R6 | Integrate unstructured data (contracts, policies, quality reports) | Knowledge Base | High |
| R7 | Provide AI-powered supplier risk assessments | AI/ML | High |
| R8 | Predict transit delays based on weather and historical data | AI/ML | High |
| R9 | Auto-refresh KPIs without manual intervention | Automation | High |
| R10 | Detect anomalies in delivery performance | AI/ML | Medium |
| R11 | Trace impact of disruptions across the supply chain graph | Analytics | Medium |
| R12 | Classify documents and suppliers using AI | AI/ML | Medium |
| R13 | Implement role-based access control by persona | Security | Medium |
| R14 | Version and audit all ontology changes | Governance | Medium |
| R15 | Evaluate agent accuracy with formal metrics | Quality | High |
| R16 | Forecast future demand volumes | AI/ML | Medium |
| R17 | Enrich data with external risk indices | Integration | Low |
| R18 | Generate visualizations from data | UX | Low |

---

## End-to-End Solution Table

| # | Requirement | Solution Implemented | Snowflake Feature | Object |
|---|-------------|---------------------|-------------------|--------|
| R1 | Ontology entities | 8 tables: Supplier, Part, Plant, Customer, Order, OrderLine, Shipment, Inventory | Tables | `SC_ONTOLOGY.RAW.*` |
| R2 | Canonical metrics | 4 KPIs defined once in semantic view with verified queries | Semantic View + AI_VERIFIED_QUERIES | `SUPPLY_CHAIN_VIEW` |
| R3 | Semantic encoding | 3 semantic views with synonyms, comments, relationships | CREATE SEMANTIC VIEW | `ANALYTICS.*_VIEW` |
| R4 | Natural language | Multi-tool Cortex Agent with orchestration instructions | CREATE AGENT + DATA_AGENT_RUN | `SUPPLY_CHAIN_AGENT` |
| R5 | Cross-persona consistency | Same OTD formula in all 3 views + verified queries + AI_SQL_GENERATION | Semantic View governance | All 3 views |
| R6 | Unstructured data | 15 documents + Cortex Search service | CORTEX SEARCH SERVICE | `SC_KNOWLEDGE_SEARCH` |
| R7 | AI risk assessment | LLM-powered function combining metrics + documents + country risk | CORTEX.COMPLETE + Custom Tool | `SUPPLIER_RISK_ASSESSMENT` |
| R8 | Transit delay prediction | Weather data + historical delays + prediction function | Custom Function + Agent Tool | `PREDICT_TRANSIT_DELAY` |
| R9 | Auto-refresh | 3 Dynamic Tables with 30-min target lag | DYNAMIC TABLE | `DT_SUPPLIER_SCORECARD`, etc. |
| R10 | Anomaly detection | Time series view + ML anomaly detector + alerting task | SNOWFLAKE.ML.ANOMALY_DETECTION | `ORDER_ANOMALY_DETECTOR` |
| R11 | Impact analysis | Multi-hop graph traversal function (Supplier→Parts→Customers) | Table Function | `SUPPLY_CHAIN_IMPACT_ANALYSIS` |
| R12 | AI classification | CLASSIFY_TEXT for suppliers + SENTIMENT for documents | CORTEX.CLASSIFY_TEXT + SENTIMENT | `V_SUPPLIER_AI_CLASSIFICATION` |
| R13 | RBAC | Persona access table with region/financial permissions | Table + Policy | `PERSONA_REGION_ACCESS` |
| R14 | Versioning | Changelog table with version tags and breaking change flags | Table | `ONTOLOGY_CHANGELOG` |
| R15 | Evaluation | 8-question ground truth dataset + 5 metrics + EXECUTE_AI_EVALUATION | Agent Evaluation Framework | `SC_AGENT_EVAL_DATASET_V1` |
| R16 | Demand forecast | ML forecast model trained on daily order volume | SNOWFLAKE.ML.FORECAST | `ORDER_VOLUME_FORECAST` |
| R17 | External risk data | Country risk index + weather transit data | Tables (simulated Marketplace) | `COUNTRY_RISK_INDEX` |
| R18 | Visualizations | data_to_chart tool integrated in agent | Agent Tool | Built-in |

---

## Snowflake AI/ML Features Used

| Feature | Category | How Used | Business Value |
|---------|----------|----------|---------------|
| **Cortex Agent** | Agentic AI | Multi-tool orchestration with reasoning loop | One interface for all supply chain questions |
| **Cortex Analyst** | Text-to-SQL | Semantic view-grounded SQL generation | Consistent metrics from natural language |
| **Cortex Search** | RAG | Document retrieval over policies/contracts | Knowledge base accessible via conversation |
| **CORTEX.COMPLETE** | LLM | Supplier risk narrative generation | Executive-ready AI assessments |
| **CORTEX.SENTIMENT** | NLP | Document sentiment scoring | Triage quality reports by tone |
| **CORTEX.CLASSIFY_TEXT** | Classification | Supplier risk tiering + document urgency | Auto-categorization without rules |
| **CORTEX.SUMMARIZE** | NLP | Document auto-summarization | Quick digest of long documents |
| **SNOWFLAKE.ML.FORECAST** | Time Series | 30-day order volume prediction | Demand planning and capacity allocation |
| **SNOWFLAKE.ML.ANOMALY_DETECTION** | Anomaly | Unusual order pattern detection | Early warning for disruptions |
| **Semantic Views** | Governance | Ontology encoding with verified queries | Single source of truth for metrics |
| **Dynamic Tables** | Materialization | Auto-refreshing KPI aggregations | Sub-second dashboard queries |
| **AI_SQL_GENERATION** | Governance | Custom instructions for metric consistency | Prevent formula drift |
| **AI_VERIFIED_QUERIES** | Governance | Pre-validated SQL for critical questions | Guaranteed accuracy for top queries |
| **EXECUTE_AI_EVALUATION** | Quality | Batch evaluation with LLM judges | Automated quality regression testing |
| **Streams + Tasks** | Automation | Change capture + scheduled alerting | Real-time anomaly monitoring |
| **Custom Tools (Generic)** | Extensibility | UDFs as agent tools | AI + ML accessible via conversation |

---

## Data Flow Summary

```
External Systems          Snowflake Platform              User Experience
────────────────         ────────────────────            ────────────────

ERP System ─────────────► RAW.ORDERS ──────┐
                          RAW.ORDER_LINES   │
                                            │
TMS (Transport) ────────► RAW.SHIPMENTS ────┤
                                            │
WMS (Warehouse) ────────► RAW.INVENTORY ────┤──► Semantic Views ──► Agent ──► Natural Language
                                            │   (Ontology)          │        Answers
Supplier Portal ────────► RAW.SUPPLIERS ────┤                       │
                          RAW.PARTS         │                       │
                                            │                       ▼
IoT Platform ───────────► RAW.IOT_SENSORS ──┘               ┌──────────────┐
                                                             │  Evaluation  │
Contracts/Policies ─────► DOCUMENTS.KNOWLEDGE ──► Search ──► │  Framework   │
                                                             │  (Scoring)   │
Weather Feed ───────────► ADVANCED.WEATHER_DATA ──► ML ─────►└──────────────┘
                                                    │
Country Risk Data ──────► ADVANCED.COUNTRY_RISK ────┘
```

---

## Agent Tool Routing Decision Tree

```
User Question
     │
     ├─ Contains numbers/KPI/metric words? ──────────► Cortex Analyst
     │   (OTD, fill rate, DOI, cost, count, trend)      │
     │                                                    ├─ Cross-domain? → SupplyChainAnalyst
     │                                                    ├─ Supplier-specific? → ProcurementAnalyst
     │                                                    └─ Carrier/freight? → LogisticsAnalyst
     │
     ├─ Asks about policy/contract/procedure? ──────► KnowledgeSearch
     │   (terms, rules, process, what should we do)
     │
     ├─ Asks for risk assessment/AI analysis? ──────► SupplierRiskAssessment
     │   (risk, assess, evaluate supplier, AI summary)
     │
     ├─ Asks about weather/delay/transit prediction? ► TransitDelayPredictor
     │   (predict, delay, weather, transit time)
     │
     └─ Asks for visualization? ────────────────────► data_to_chart
         (show me a chart, visualize, graph)
```

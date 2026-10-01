# Requirements Document
## Supply Chain Ontology on Snowflake — Hackathon Submission

**Version:** 3.0  
**Date:** August 19, 2026  
**Project:** Supply Chain Industry Ontology with Governed Conversational Analytics

---

## 1. Problem Statement

Supply chain data is scattered across ERP, logistics, supplier, and IoT systems with inconsistent definitions. The same question ("What is our on-time delivery rate?") yields different answers depending on which team asks, which system they query, and which formula they use.

**Evidence of the Problem (from our demo data):**
| Persona | Their OTD Calculation | Result | Why It's Wrong |
|---------|----------------------|--------|----------------|
| Planning | Shipment arrival vs requested | 47.70% | Uses transit arrival, not customer delivery |
| Procurement | Adds 5-day grace period | 62.75% | Grace period not in customer SLA |
| Logistics | Excludes express orders | 48.51% | Misses 33% of orders |
| **Governed (Ontology)** | **actual_delivery <= requested** | **47.95%** | **Canonical — single source of truth** |

---

## 2. Functional Requirements

### FR-01: Ontology Definition
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-01.1 | Define core entities: Supplier, Part, Plant, Customer, Order, Shipment, Inventory | Critical |
| FR-01.2 | Define relationships between entities (at least 8 governed joins) | Critical |
| FR-01.3 | Define hierarchies: Part BOM (Raw Material → Component → Sub-Assembly → Finished Good) | High |
| FR-01.4 | Define hierarchies: Geography (Region → Country → Plant) | High |
| FR-01.5 | Include IoT/sensor entity for real-time condition monitoring | Medium |

### FR-02: Canonical Metrics
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-02.1 | OTD%: orders delivered on/before requested / total delivered * 100 | Critical |
| FR-02.2 | Fill Rate: sum(qty_fulfilled) / sum(qty_ordered) * 100 | Critical |
| FR-02.3 | Days of Inventory: avg(qty_on_hand) / avg(daily_demand) | Critical |
| FR-02.4 | Landed Cost: unit_cost + freight_per_unit + duties + handling | Critical |
| FR-02.5 | Perfect Order Rate: on_time AND in_full AND no_quality_issues | High |
| FR-02.6 | Each metric has ONE definition that cannot be overridden by teams | Critical |

### FR-03: Semantic Layer
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-03.1 | Encode ontology as Snowflake Semantic Views | Critical |
| FR-03.2 | Include business synonyms (e.g., "OTD" = "on time rate" = "delivery performance") | High |
| FR-03.3 | Include verified queries for critical KPIs | High |
| FR-03.4 | Include AI_SQL_GENERATION instructions to enforce canonical formulas | High |
| FR-03.5 | Support multiple domain-specific views sharing the same metric definitions | Medium |

### FR-04: Conversational Analytics
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-04.1 | Natural language interface via Cortex Agent | Critical |
| FR-04.2 | Route structured questions to Cortex Analyst (semantic views) | Critical |
| FR-04.3 | Route qualitative questions to Cortex Search (document RAG) | High |
| FR-04.4 | Support AI-powered risk assessments via custom tools | High |
| FR-04.5 | Support ML-powered predictions (delay, demand forecast) | Medium |
| FR-04.6 | Generate visualizations from query results | Medium |

### FR-05: Cross-Persona Consistency
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-05.1 | Same metric resolves identically for Planning, Procurement, Logistics | Critical |
| FR-05.2 | Demonstrate "before vs. after" — show inconsistency without ontology | Critical |
| FR-05.3 | Provide formal evaluation proving consistency (agent evaluation framework) | High |

### FR-06: Data Governance
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-06.1 | Role-based access control (3 personas with different permissions) | High |
| FR-06.2 | Column masking for sensitive financial and PII data | High |
| FR-06.3 | Row access policies for regional data isolation | Medium |
| FR-06.4 | Object tagging (domain, sensitivity, owner, refresh frequency) | Medium |
| FR-06.5 | Data quality monitoring via DMFs | Medium |
| FR-06.6 | Ontology versioning with changelog | Medium |

### FR-07: Monitoring & Alerting
| ID | Requirement | Priority |
|----|-------------|----------|
| FR-07.1 | Proactive alerts when KPIs breach thresholds | High |
| FR-07.2 | Anomaly detection on time series data | Medium |
| FR-07.3 | Agent evaluation and traceability | High |

---

## 3. Non-Functional Requirements

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-01 | Query response time for KPIs | < 5 seconds via Dynamic Tables |
| NFR-02 | Agent response time | < 60 seconds for complex multi-tool |
| NFR-03 | Data freshness | 30-minute lag via Dynamic Tables |
| NFR-04 | Evaluation pass rate | > 85% answer correctness |
| NFR-05 | Tool routing accuracy | > 95% (actual: 100%) |
| NFR-06 | Scalability | Support 69K+ rows with no degradation |

---

## 4. Acceptance Criteria

| # | Criteria | Verification Method |
|---|---------|-------------------|
| AC-01 | Ask "What is OTD?" from 3 personas → get same number | Run V_INCONSISTENCY_DEMO, verify WITH ONTOLOGY row |
| AC-02 | Agent routes KPI question to Analyst, policy question to Search | Check EXECUTE_AI_EVALUATION tool_selection = 1.0 |
| AC-03 | Landed cost includes material + freight + duties + handling | Query V_LANDED_COST, verify all 4 components |
| AC-04 | BOM hierarchy shows 4 levels (Raw→Component→Sub-Assembly→Finished) | Query PARTS WHERE bom_level IN (0,1,2,3) |
| AC-05 | Roles SC_PLANNING/PROCUREMENT/LOGISTICS exist with proper grants | SHOW GRANTS TO ROLE each role |
| AC-06 | DMFs fire on data changes | Check DATA_QUALITY_MONITORING_RESULTS |
| AC-07 | Alerts exist and are configured | SHOW ALERTS IN SC_ONTOLOGY.ADVANCED |
| AC-08 | Forecast model produces 30-day prediction | CALL ORDER_VOLUME_FORECAST!FORECAST(30) |

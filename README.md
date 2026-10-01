# Supply Chain Ontology on Snowflake

A governed semantic layer that encodes supply chain domain knowledge as Snowflake semantic views,
enabling natural language analytics with consistent, trustworthy answers across Planning, Procurement, and Logistics teams.

## Problem Statement

Supply chain data is scattered across ERP, logistics, supplier, and IoT systems with inconsistent definitions.
The same question ("What is our on-time delivery rate?") yields different answers depending on which team asks,
which system they query, and which ad-hoc formula they use.

## Solution

An **industry ontology** expressed as **governed semantic views** + a **Cortex Agent**, so that:
- Business meaning (not raw column names) drives answers
- Metrics are defined ONCE and resolve identically across all personas
- Natural language questions get consistent, auditable SQL grounded in shared definitions

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CORTEX AGENT                                         │
│              "Supply Chain Intelligence Agent"                                │
│   Natural Language → Consistent Answers → Any Persona                        │
└──────────────┬──────────────────────────────────────┬───────────────────────┘
               │                                      │
    ┌──────────┴──────────┐              ┌────────────┴────────────┐
    │   SEMANTIC VIEWS    │              │     CORTEX SEARCH       │
    │  (Structured Data)  │              │   (Unstructured Data)   │
    │                     │              │                         │
    │  SUPPLY_CHAIN_VIEW  │              │  Supplier Contracts     │
    │  PROCUREMENT_VIEW   │              │  Quality Reports        │
    │  LOGISTICS_VIEW     │              │  Logistics Policies     │
    └──────────┬──────────┘              └────────────┬────────────┘
               │                                      │
    ┌──────────┴──────────────────────────────────────┴───────────┐
    │                    SNOWFLAKE DATA LAYER                       │
    │                                                              │
    │  ┌─────────┐ ┌─────────┐ ┌──────────┐ ┌──────────────────┐ │
    │  │   ERP   │ │Logistics│ │ Supplier │ │   IoT/Sensors    │ │
    │  │ Tables  │ │  Tables │ │  Tables  │ │     Tables       │ │
    │  └─────────┘ └─────────┘ └──────────┘ └──────────────────┘ │
    │                                                              │
    │  SC_ONTOLOGY.RAW (8 structured tables, ~69K rows)           │
    │  SC_ONTOLOGY.DOCUMENTS (unstructured knowledge base)        │
    └──────────────────────────────────────────────────────────────┘
```

## Ontology Model

```
                    ┌──────────┐
                    │ SUPPLIER │
                    │----------│
                    │ tier     │
                    │ country  │
                    │ quality  │
                    │ lead_time│
                    └────┬─────┘
                         │ supplies
                         ▼
┌──────────┐       ┌──────────┐        ┌──────────┐
│ CUSTOMER │       │   PART   │        │  PLANT   │
│----------│       │----------│        │----------│
│ segment  │       │ category │◄───────│ region   │
│ region   │       │ abc_class│stocked │ type     │
│ country  │       │ unit_cost│   at   │ capacity │
└────┬─────┘       └────┬─────┘        └──┬───┬───┘
     │                   │                 │   │
     │ places            │ ordered_in      │   │ ships_from
     │                   ▼                 │   │
     │            ┌────────────┐           │   │
     └───────────►│   ORDER    │           │   │
                  │------------│           │   │
                  │ order_date │           │   │
                  │ status     │           │   │
                  │ priority   │           │   │
                  └──────┬─────┘           │   │
                         │ fulfilled_via   │   │
                         ▼                 │   │
                  ┌────────────┐           │   │
                  │  SHIPMENT  │◄──────────┘   │
                  │------------│               │
                  │ carrier    │◄──────────────┘
                  │ mode       │
                  │ freight    │
                  └────────────┘

  ┌────────────┐
  │ INVENTORY  │──► Part + Plant (stock positions)
  │------------│
  │ qty_on_hand│
  │ demand     │
  │ safety_stk │
  └────────────┘

  ┌────────────┐
  │ IoT SENSOR │──► Shipment + Plant (condition monitoring)
  │------------│
  │ temperature│
  │ humidity   │
  │ vibration  │
  └────────────┘
```

## Canonical Metrics (Defined Once, Used Everywhere)

| # | Metric | Formula | Used By |
|---|--------|---------|---------|
| 1 | **On-Time Delivery (OTD%)** | `COUNT(actual <= requested) / COUNT(delivered) * 100` | All teams |
| 2 | **Fill Rate%** | `SUM(qty_fulfilled) / SUM(qty_ordered) * 100` | All teams |
| 3 | **Days of Inventory (DOI)** | `AVG(qty_on_hand) / AVG(daily_demand)` | Planning, Procurement |
| 4 | **Freight Cost/Unit** | `AVG(freight_cost / qty_shipped)` | Logistics, Procurement |

## Cross-Persona Consistency Proof

The SAME OTD% formula resolves identically regardless of who asks:

| Persona | Question | Grouping Dimension | Result Source |
|---------|----------|-------------------|---------------|
| Planning | "OTD by plant?" | `plants.plant_name` | Same formula |
| Procurement | "Worst supplier OTD?" | `suppliers.supplier_name` | Same formula |
| Logistics | "OTD by carrier?" | `shipments.carrier` | Same formula |

## Project Structure

```
D:\clihackathon\
├── README.md                          # This file
├── sql/
│   ├── 01_infrastructure.sql          # Database, schemas, warehouse
│   ├── 02_synthetic_data.sql          # All 8 source tables
│   ├── 03_unstructured_data.sql       # Document tables for Cortex Search
│   ├── 04_cortex_search.sql           # Cortex Search service creation
│   ├── 05_semantic_view_main.sql      # Primary supply chain semantic view
│   ├── 06_semantic_view_procurement.sql # Procurement-focused view
│   ├── 07_semantic_view_logistics.sql # Logistics-focused view
│   ├── 08_cortex_agent.sql            # Intelligent agent with all tools
│   └── 09_demo_queries.sql            # Cross-persona consistency demos
├── docs/
│   ├── architecture.md                # Detailed architecture documentation
│   ├── ontology.md                    # Ontology specification
│   └── improvements.md                # Roadmap and improvement suggestions
```

## Quick Start

```sql
-- Run scripts in order:
-- 1. Infrastructure
-- 2. Synthetic data
-- 3. Unstructured data
-- 4. Cortex Search
-- 5-7. Semantic views
-- 8. Agent
-- 9. Demo queries to validate

-- Or interact with the agent directly:
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
  'SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT',
  $${"messages": [{"role": "user", "content": [{"type": "text", "text": "What is our fill rate by plant?"}]}]}$$
);
```

## Key Snowflake Features Used

- **Semantic Views** — Ontology encoded as governed business definitions
- **Cortex Agent** — Natural language interface with tool orchestration
- **Cortex Analyst** — Text-to-SQL grounded in semantic views
- **Cortex Search** — RAG over unstructured supply chain documents
- **Verified Queries** — Pre-validated SQL for critical KPIs
- **AI_SQL_GENERATION** — Custom instructions for metric consistency

-- ============================================================
-- 08_cortex_agent.sql
-- Supply Chain Intelligence Agent
-- Multi-tool: 3 Semantic Views + Cortex Search + Charts
-- ============================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA ANALYTICS;

CREATE OR REPLACE AGENT SUPPLY_CHAIN_AGENT
  COMMENT = 'Supply Chain Intelligence Agent - governed conversational analytics'
  PROFILE = '{"display_name": "Supply Chain Intelligence", "avatar": "chain", "color": "blue"}'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5

orchestration:
  budget:
    seconds: 90
    tokens: 48000

instructions:
  response: "You are the Supply Chain Intelligence Agent serving Planning, Procurement, and Logistics teams. You provide governed, consistent answers by combining structured analytics (via semantic views) with unstructured knowledge (via document search). Always cite which data source answered the question. Present metrics with canonical definitions. Format: percentages 2 decimals, costs 2 decimals, days 1 decimal."
  orchestration: "Route questions as follows: 1) Quantitative KPI questions (OTD, fill rate, DOI, costs, volumes) -> Use SupplyChainAnalyst (primary), ProcurementAnalyst (supplier-specific), or LogisticsAnalyst (carrier/freight-specific). 2) Policy, contract, procedure, or qualitative questions -> Use KnowledgeSearch. 3) Combined questions -> Use both analyst and search tools. CRITICAL: All three analyst tools use the SAME canonical metric formulas. OTD is ALWAYS: delivered on/before requested / total delivered * 100. Fill Rate is ALWAYS: qty_fulfilled / qty_ordered * 100."
  sample_questions:
    - question: "What is our on-time delivery rate by plant this quarter?"
    - question: "Which suppliers have the worst OTD performance?"
    - question: "What are DHL's contract terms for express shipments?"
    - question: "What is our inventory policy for A-class items?"
    - question: "Show me fill rate trends by carrier"
    - question: "What corrective actions were taken for Quantum Plastics?"
    - question: "How many days of inventory do we have by region?"
    - question: "What is our expedite request approval process?"

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "SupplyChainAnalyst"
      description: "Primary supply chain analytics - cross-domain KPI questions using the full ontology (suppliers, parts, plants, orders, shipments, inventory, customers)."
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "ProcurementAnalyst"
      description: "Procurement-focused - supplier performance, spend, quality scores, lead times, vendor risk."
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "LogisticsAnalyst"
      description: "Logistics-focused - carrier performance, freight costs, transit times, transport mode analysis."
  - tool_spec:
      type: "cortex_search"
      name: "KnowledgeSearch"
      description: "Searches supply chain knowledge base: contracts, quality reports, policies, procedures, and compliance docs."
  - tool_spec:
      type: "data_to_chart"
      name: "data_to_chart"
      description: "Generates visualizations from data returned by analyst tools"

tool_resources:
  SupplyChainAnalyst:
    semantic_view: "SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_VIEW"
    execution_environment:
      type: "warehouse"
      warehouse: "COMPUTE_WH"
  ProcurementAnalyst:
    semantic_view: "SC_ONTOLOGY.ANALYTICS.PROCUREMENT_VIEW"
    execution_environment:
      type: "warehouse"
      warehouse: "COMPUTE_WH"
  LogisticsAnalyst:
    semantic_view: "SC_ONTOLOGY.ANALYTICS.LOGISTICS_VIEW"
    execution_environment:
      type: "warehouse"
      warehouse: "COMPUTE_WH"
  KnowledgeSearch:
    name: "SC_ONTOLOGY.DOCUMENTS.SC_KNOWLEDGE_SEARCH"
    max_results: "5"
    title_column: "title"
    id_column: "doc_id"
    columns_and_descriptions:
      CONTENT:
        description: "Full document text including contract terms, policies, reports"
        type: "string"
        searchable: true
        filterable: false
      CATEGORY:
        description: "Category: Procurement, Logistics, Planning, Quality, Compliance, Risk Management, Governance"
        type: "string"
        searchable: false
        filterable: true
      DOC_TYPE:
        description: "Type: Contract, Policy, Quality Report, Planning Guide, Report, Procedure, Technical Spec, KPI Definition"
        type: "string"
        searchable: false
        filterable: true
      RELATED_ENTITY:
        description: "Related entity: supplier name, plant name, or All"
        type: "string"
        searchable: false
        filterable: true
$$;

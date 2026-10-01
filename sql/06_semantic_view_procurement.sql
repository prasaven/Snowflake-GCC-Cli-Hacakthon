-- ============================================================
-- 06_semantic_view_procurement.sql
-- Procurement-Focused Semantic View
-- Supplier performance, spend analysis, risk
-- ============================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA ANALYTICS;

CREATE OR REPLACE SEMANTIC VIEW PROCUREMENT_VIEW

  TABLES (
    suppliers AS SC_ONTOLOGY.RAW.SUPPLIERS PRIMARY KEY (supplier_id)
      WITH SYNONYMS = ('vendor', 'source', 'provider')
      COMMENT = 'Supplier master data',
    parts AS SC_ONTOLOGY.RAW.PARTS PRIMARY KEY (part_id)
      WITH SYNONYMS = ('material', 'component', 'SKU')
      COMMENT = 'Part catalog',
    order_lines AS SC_ONTOLOGY.RAW.ORDER_LINES PRIMARY KEY (order_line_id)
      COMMENT = 'Order line items for spend analysis',
    orders AS SC_ONTOLOGY.RAW.ORDERS PRIMARY KEY (order_id)
      COMMENT = 'Orders for delivery performance'
  )

  RELATIONSHIPS (
    parts (primary_supplier_id) REFERENCES suppliers (supplier_id),
    order_lines (part_id) REFERENCES parts (part_id),
    order_lines (order_id) REFERENCES orders (order_id)
  )

  DIMENSIONS (
    suppliers.supplier_name AS suppliers.supplier_name
      WITH SYNONYMS = ('vendor name')
      COMMENT = 'Supplier organization name',
    suppliers.supplier_tier AS suppliers.supplier_tier
      WITH SYNONYMS = ('tier', 'vendor tier')
      COMMENT = 'Tier 1 critical, Tier 2 important, Tier 3 commodity',
    suppliers.supplier_country AS suppliers.country
      WITH SYNONYMS = ('supplier origin')
      COMMENT = 'Country where supplier is based',
    suppliers.supplier_region AS suppliers.region
      COMMENT = 'Geographic region of supplier',
    suppliers.quality_score AS suppliers.quality_score
      WITH SYNONYMS = ('supplier rating')
      COMMENT = 'Quality performance score 0-100',
    suppliers.lead_time_days AS suppliers.lead_time_days
      WITH SYNONYMS = ('procurement lead time')
      COMMENT = 'Average days from PO to receipt',
    suppliers.supplier_status AS suppliers.status
      WITH SYNONYMS = ('vendor status')
      COMMENT = 'Active or Probation',
    parts.part_name AS parts.part_name
      WITH SYNONYMS = ('material name')
      COMMENT = 'Part name',
    parts.part_category AS parts.category
      WITH SYNONYMS = ('material type')
      COMMENT = 'Part classification',
    parts.abc_class AS parts.abc_class
      WITH SYNONYMS = ('ABC classification')
      COMMENT = 'Inventory value class A/B/C',
    orders.order_date AS orders.order_date
      WITH SYNONYMS = ('PO date')
      COMMENT = 'Date order was placed',
    orders.actual_delivery_date AS orders.actual_delivery_date
      COMMENT = 'Actual delivery date',
    orders.requested_delivery_date AS orders.requested_delivery_date
      COMMENT = 'Requested delivery date'
  )

  METRICS (
    suppliers.avg_quality_score AS AVG(suppliers.quality_score)
      WITH SYNONYMS = ('average quality', 'supplier quality')
      COMMENT = 'Average quality score across suppliers',
    suppliers.avg_lead_time AS AVG(suppliers.lead_time_days)
      WITH SYNONYMS = ('average lead time')
      COMMENT = 'Average procurement lead time in days',
    order_lines.total_spend AS SUM(order_lines.qty_ordered * order_lines.unit_price)
      WITH SYNONYMS = ('procurement spend', 'total cost', 'purchase volume')
      COMMENT = 'Total procurement spend',
    order_lines.fill_rate AS SUM(order_lines.qty_fulfilled) * 100.0 / NULLIF(SUM(order_lines.qty_ordered), 0)
      WITH SYNONYMS = ('fulfillment rate', 'service level')
      COMMENT = 'Fill Rate pct: qty_fulfilled / qty_ordered * 100',
    orders.supplier_otd AS
      COUNT(CASE WHEN orders.actual_delivery_date <= orders.requested_delivery_date THEN 1 END)
      * 100.0 / NULLIF(COUNT(orders.actual_delivery_date), 0)
      WITH SYNONYMS = ('OTD', 'on time delivery', 'vendor delivery performance')
      COMMENT = 'On-Time Delivery Rate for supplier evaluation',
    order_lines.order_line_count AS COUNT(order_lines.order_line_id)
      WITH SYNONYMS = ('number of POs', 'transaction count')
      COMMENT = 'Number of order line transactions'
  )

  COMMENT = 'Procurement-focused view - supplier performance, spend, and risk'

  AI_SQL_GENERATION 'You are a procurement analytics expert. Focus on supplier performance: quality, lead times, OTD, spend. OTD = delivered on/before requested / total delivered * 100. Fill rate = qty_fulfilled / qty_ordered * 100.';

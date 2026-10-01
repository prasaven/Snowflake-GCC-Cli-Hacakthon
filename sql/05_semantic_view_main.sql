-- ============================================================
-- 05_semantic_view_main.sql
-- Primary Supply Chain Semantic View (Full Ontology)
-- 8 entities, 9 relationships, 29 dimensions, 13 metrics
-- ============================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA ANALYTICS;

CREATE OR REPLACE SEMANTIC VIEW SUPPLY_CHAIN_VIEW

  TABLES (
    suppliers AS SC_ONTOLOGY.RAW.SUPPLIERS PRIMARY KEY (supplier_id)
      WITH SYNONYMS = ('vendor', 'source', 'provider')
      COMMENT = 'Supplier master data from procurement system',
    parts AS SC_ONTOLOGY.RAW.PARTS PRIMARY KEY (part_id)
      WITH SYNONYMS = ('material', 'component', 'SKU', 'item', 'product')
      COMMENT = 'Part/material catalog from ERP',
    plants AS SC_ONTOLOGY.RAW.PLANTS PRIMARY KEY (plant_id)
      WITH SYNONYMS = ('facility', 'factory', 'warehouse', 'site', 'location')
      COMMENT = 'Manufacturing and distribution facilities',
    customers AS SC_ONTOLOGY.RAW.CUSTOMERS PRIMARY KEY (customer_id)
      WITH SYNONYMS = ('buyer', 'client', 'account')
      COMMENT = 'Customer master data',
    orders AS SC_ONTOLOGY.RAW.ORDERS PRIMARY KEY (order_id)
      WITH SYNONYMS = ('purchase order', 'PO', 'demand signal')
      COMMENT = 'Customer orders from ERP',
    order_lines AS SC_ONTOLOGY.RAW.ORDER_LINES PRIMARY KEY (order_line_id)
      WITH SYNONYMS = ('line item', 'order detail', 'order item')
      COMMENT = 'Order line items linking orders to parts and plants',
    shipments AS SC_ONTOLOGY.RAW.SHIPMENTS PRIMARY KEY (shipment_id)
      WITH SYNONYMS = ('delivery', 'consignment', 'freight', 'transport')
      COMMENT = 'Logistics shipment records from TMS',
    inventory AS SC_ONTOLOGY.RAW.INVENTORY PRIMARY KEY (inventory_id)
      WITH SYNONYMS = ('stock', 'on-hand', 'warehouse inventory')
      COMMENT = 'Inventory positions from WMS'
  )

  RELATIONSHIPS (
    parts (primary_supplier_id) REFERENCES suppliers (supplier_id),
    order_lines (order_id) REFERENCES orders (order_id),
    order_lines (part_id) REFERENCES parts (part_id),
    order_lines (plant_id) REFERENCES plants (plant_id),
    orders (customer_id) REFERENCES customers (customer_id),
    shipments (order_id) REFERENCES orders (order_id),
    shipments (origin_plant_id) REFERENCES plants (plant_id),
    inventory (part_id) REFERENCES parts (part_id),
    inventory (plant_id) REFERENCES plants (plant_id)
  )

  DIMENSIONS (
    orders.order_date AS orders.order_date COMMENT = 'Date the order was placed',
    orders.requested_delivery_date AS orders.requested_delivery_date COMMENT = 'Customer-requested delivery date',
    orders.actual_delivery_date AS orders.actual_delivery_date COMMENT = 'Actual date goods were delivered',
    orders.order_status AS orders.status COMMENT = 'Pending, Processing, Shipped, Delivered',
    orders.shipping_priority AS orders.shipping_priority COMMENT = 'Standard, Express, Economy',
    shipments.ship_date AS shipments.ship_date COMMENT = 'Date shipment left origin plant',
    shipments.actual_arrival AS shipments.actual_arrival COMMENT = 'Actual arrival date at destination',
    shipments.carrier AS shipments.carrier COMMENT = 'Carrier or logistics provider',
    shipments.transport_mode AS shipments.transport_mode COMMENT = 'Ocean, Air, Ground, Rail',
    shipments.shipment_status AS shipments.status COMMENT = 'Delivered, In Transit, Pending Pickup',
    inventory.snapshot_date AS inventory.snapshot_date COMMENT = 'Date of inventory snapshot',
    suppliers.supplier_country AS suppliers.country COMMENT = 'Country where supplier is based',
    suppliers.supplier_region AS suppliers.region COMMENT = 'Geographic region of supplier',
    suppliers.supplier_name AS suppliers.supplier_name COMMENT = 'Supplier organization name',
    suppliers.supplier_tier AS suppliers.supplier_tier COMMENT = 'Tier 1 critical, Tier 2 important, Tier 3 commodity',
    suppliers.quality_score AS suppliers.quality_score COMMENT = 'Quality performance score 0-100',
    suppliers.lead_time_days AS suppliers.lead_time_days COMMENT = 'Average days from PO to receipt',
    parts.part_name AS parts.part_name COMMENT = 'Descriptive name of the part',
    parts.part_category AS parts.category COMMENT = 'Mechanical, Electronic, Structural, etc.',
    parts.part_type AS parts.part_type COMMENT = 'Raw Material, Component, Sub-Assembly, Finished Good',
    parts.abc_class AS parts.abc_class COMMENT = 'ABC inventory class: A high, B medium, C low',
    parts.unit_cost AS parts.unit_cost COMMENT = 'Unit cost of the part',
    plants.plant_name AS plants.plant_name COMMENT = 'Name of plant or distribution center',
    plants.plant_region AS plants.region COMMENT = 'Geographic region of the plant',
    plants.plant_country AS plants.country COMMENT = 'Country where plant is located',
    plants.plant_type AS plants.plant_type COMMENT = 'Assembly, Distribution, or Manufacturing',
    customers.customer_name AS customers.customer_name COMMENT = 'Customer organization name',
    customers.customer_segment AS customers.segment COMMENT = 'Enterprise, Mid-Market, SMB, Strategic',
    customers.customer_region AS customers.region COMMENT = 'Geographic region of customer',
    customers.customer_country AS customers.country COMMENT = 'Country of the customer'
  )

  METRICS (
    -- CANONICAL METRIC 1: On-Time Delivery Rate
    orders.on_time_delivery_rate AS
      COUNT(CASE WHEN orders.actual_delivery_date <= orders.requested_delivery_date THEN 1 END)
      * 100.0 / NULLIF(COUNT(orders.actual_delivery_date), 0)
      WITH SYNONYMS = ('OTD', 'on time rate', 'delivery performance', 'OTIF')
      COMMENT = 'On-Time Delivery Rate pct: delivered_on_time / total_delivered * 100',

    -- CANONICAL METRIC 2: Fill Rate
    order_lines.fill_rate AS
      SUM(order_lines.qty_fulfilled) * 100.0 / NULLIF(SUM(order_lines.qty_ordered), 0)
      WITH SYNONYMS = ('fulfillment rate', 'order fill', 'service level')
      COMMENT = 'Fill Rate pct: sum(qty_fulfilled) / sum(qty_ordered) * 100',

    -- CANONICAL METRIC 3: Days of Inventory
    inventory.days_of_inventory AS
      AVG(inventory.qty_on_hand) / NULLIF(AVG(inventory.avg_daily_demand), 0)
      WITH SYNONYMS = ('DOI', 'days on hand', 'inventory days', 'stock cover', 'days of supply')
      COMMENT = 'Days of Inventory: avg(qty_on_hand) / avg(daily_demand)',

    -- CANONICAL METRIC 4: Freight Cost Per Unit
    shipments.freight_cost_per_unit AS
      AVG(shipments.freight_cost / NULLIF(shipments.qty_shipped, 0))
      WITH SYNONYMS = ('landed cost', 'freight per unit', 'shipping cost per unit', 'all-in cost')
      COMMENT = 'Freight Cost Per Unit: avg(freight_cost / qty_shipped)',

    -- Supporting metrics
    order_lines.total_revenue AS
      SUM(order_lines.qty_fulfilled * order_lines.unit_price * (1 - order_lines.discount_pct))
      WITH SYNONYMS = ('revenue', 'sales', 'net revenue')
      COMMENT = 'Total net revenue from fulfilled order lines',
    orders.total_orders AS COUNT(orders.order_id)
      WITH SYNONYMS = ('order count', 'number of orders')
      COMMENT = 'Total number of orders',
    orders.delivered_orders AS COUNT(orders.actual_delivery_date)
      WITH SYNONYMS = ('completed orders', 'fulfilled orders')
      COMMENT = 'Number of delivered orders',
    shipments.total_shipments AS COUNT(shipments.shipment_id)
      WITH SYNONYMS = ('shipment count', 'number of shipments')
      COMMENT = 'Total number of shipments',
    shipments.avg_freight_cost AS AVG(shipments.freight_cost)
      WITH SYNONYMS = ('average shipping cost', 'freight per shipment')
      COMMENT = 'Average freight cost per shipment',
    shipments.total_freight_cost AS SUM(shipments.freight_cost)
      WITH SYNONYMS = ('total shipping cost', 'freight spend')
      COMMENT = 'Total freight cost across all shipments',
    inventory.avg_stock_on_hand AS AVG(inventory.qty_on_hand)
      WITH SYNONYMS = ('inventory level', 'stock level', 'average inventory')
      COMMENT = 'Average quantity on hand',
    order_lines.avg_order_value AS AVG(order_lines.qty_ordered * order_lines.unit_price)
      WITH SYNONYMS = ('AOV', 'average order size')
      COMMENT = 'Average order line value',
    parts.avg_unit_cost AS AVG(parts.unit_cost)
      WITH SYNONYMS = ('average material cost', 'avg part cost')
      COMMENT = 'Average unit cost across parts'
  )

  COMMENT = 'Supply Chain Industry Ontology - canonical metrics for consistent cross-team analytics'

  AI_SQL_GENERATION 'You are a supply chain analytics expert. ALWAYS use canonical metric definitions: 1) OTD = orders delivered on/before requested date / total delivered orders, only count where actual_delivery_date IS NOT NULL. 2) Fill Rate = qty_fulfilled / qty_ordered as percentage. 3) Days of Inventory = qty_on_hand / daily_demand. 4) Landed Cost = unit_cost + freight_cost/qty_shipped per unit. Same formula regardless of grouping dimension.'

  AI_VERIFIED_QUERIES (
    otd_overall AS (
      QUESTION 'What is the on-time delivery rate?'
      SQL 'SELECT ROUND(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 / NULLIF(COUNT(o.actual_delivery_date), 0), 2) AS otd_pct FROM SC_ONTOLOGY.RAW.ORDERS o WHERE o.actual_delivery_date IS NOT NULL'
    ),
    fill_rate_by_plant AS (
      QUESTION 'What is the fill rate by plant?'
      SQL 'SELECT p.plant_name, ROUND(SUM(ol.qty_fulfilled) * 100.0 / NULLIF(SUM(ol.qty_ordered), 0), 2) AS fill_rate_pct FROM SC_ONTOLOGY.RAW.ORDER_LINES ol JOIN SC_ONTOLOGY.RAW.PLANTS p ON ol.plant_id = p.plant_id GROUP BY p.plant_name ORDER BY fill_rate_pct DESC'
    ),
    doi_by_plant AS (
      QUESTION 'What are the days of inventory by plant?'
      SQL 'SELECT p.plant_name, ROUND(AVG(i.qty_on_hand) / NULLIF(AVG(i.avg_daily_demand), 0), 1) AS days_of_inventory FROM SC_ONTOLOGY.RAW.INVENTORY i JOIN SC_ONTOLOGY.RAW.PLANTS p ON i.plant_id = p.plant_id GROUP BY p.plant_name ORDER BY days_of_inventory DESC'
    ),
    otd_by_carrier AS (
      QUESTION 'Show on-time delivery by carrier'
      SQL 'SELECT sh.carrier, ROUND(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 / NULLIF(COUNT(o.actual_delivery_date), 0), 2) AS otd_pct, COUNT(*) AS shipment_count FROM SC_ONTOLOGY.RAW.SHIPMENTS sh JOIN SC_ONTOLOGY.RAW.ORDERS o ON sh.order_id = o.order_id WHERE o.actual_delivery_date IS NOT NULL GROUP BY sh.carrier ORDER BY otd_pct DESC'
    ),
    otd_by_supplier AS (
      QUESTION 'Which suppliers have the worst on-time delivery?'
      SQL 'SELECT s.supplier_name, s.supplier_tier, ROUND(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 / NULLIF(COUNT(o.actual_delivery_date), 0), 2) AS otd_pct FROM SC_ONTOLOGY.RAW.ORDERS o JOIN SC_ONTOLOGY.RAW.ORDER_LINES ol ON o.order_id = ol.order_id JOIN SC_ONTOLOGY.RAW.PARTS pt ON ol.part_id = pt.part_id JOIN SC_ONTOLOGY.RAW.SUPPLIERS s ON pt.primary_supplier_id = s.supplier_id WHERE o.actual_delivery_date IS NOT NULL GROUP BY s.supplier_name, s.supplier_tier ORDER BY otd_pct ASC LIMIT 20'
    )
  );

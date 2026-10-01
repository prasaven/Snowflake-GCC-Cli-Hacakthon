-- ============================================================
-- 07_semantic_view_logistics.sql
-- Logistics-Focused Semantic View
-- Carrier performance, freight optimization, transit analytics
-- ============================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA ANALYTICS;

CREATE OR REPLACE SEMANTIC VIEW LOGISTICS_VIEW

  TABLES (
    shipments AS SC_ONTOLOGY.RAW.SHIPMENTS PRIMARY KEY (shipment_id)
      WITH SYNONYMS = ('delivery', 'consignment', 'freight')
      COMMENT = 'Shipment records from TMS',
    orders AS SC_ONTOLOGY.RAW.ORDERS PRIMARY KEY (order_id)
      WITH SYNONYMS = ('purchase order', 'PO')
      COMMENT = 'Orders linked to shipments',
    plants AS SC_ONTOLOGY.RAW.PLANTS PRIMARY KEY (plant_id)
      WITH SYNONYMS = ('facility', 'warehouse', 'DC')
      COMMENT = 'Origin facilities'
  )

  RELATIONSHIPS (
    shipments (order_id) REFERENCES orders (order_id),
    shipments (origin_plant_id) REFERENCES plants (plant_id)
  )

  DIMENSIONS (
    shipments.carrier AS shipments.carrier
      WITH SYNONYMS = ('logistics provider', 'freight carrier')
      COMMENT = 'Carrier handling the shipment',
    shipments.transport_mode AS shipments.transport_mode
      WITH SYNONYMS = ('shipping mode', 'freight mode')
      COMMENT = 'Ocean, Air, Ground, Rail',
    shipments.shipment_status AS shipments.status
      WITH SYNONYMS = ('delivery status')
      COMMENT = 'Delivered, In Transit, Pending Pickup',
    shipments.ship_date AS shipments.ship_date
      WITH SYNONYMS = ('dispatch date')
      COMMENT = 'Date shipment left origin',
    shipments.actual_arrival AS shipments.actual_arrival
      WITH SYNONYMS = ('arrival date', 'receipt date')
      COMMENT = 'Actual arrival at destination',
    plants.plant_name AS plants.plant_name
      WITH SYNONYMS = ('origin facility')
      COMMENT = 'Origin plant name',
    plants.plant_region AS plants.region
      WITH SYNONYMS = ('origin region')
      COMMENT = 'Region of origin plant',
    orders.order_date AS orders.order_date
      COMMENT = 'Order date',
    orders.requested_delivery_date AS orders.requested_delivery_date
      COMMENT = 'Requested delivery date',
    orders.actual_delivery_date AS orders.actual_delivery_date
      COMMENT = 'Actual delivery date'
  )

  METRICS (
    shipments.total_shipments AS COUNT(shipments.shipment_id)
      WITH SYNONYMS = ('shipment volume', 'number of shipments')
      COMMENT = 'Total shipment count',
    shipments.total_freight_cost AS SUM(shipments.freight_cost)
      WITH SYNONYMS = ('freight spend', 'shipping cost')
      COMMENT = 'Total freight expenditure',
    shipments.avg_freight_cost AS AVG(shipments.freight_cost)
      WITH SYNONYMS = ('average shipping cost')
      COMMENT = 'Average cost per shipment',
    shipments.freight_cost_per_unit AS AVG(shipments.freight_cost / NULLIF(shipments.qty_shipped, 0))
      WITH SYNONYMS = ('cost per unit shipped', 'unit freight cost')
      COMMENT = 'Average freight cost per unit shipped',
    shipments.avg_weight AS AVG(shipments.weight_tons)
      WITH SYNONYMS = ('average shipment weight')
      COMMENT = 'Average shipment weight in tons',
    orders.logistics_otd AS
      COUNT(CASE WHEN orders.actual_delivery_date <= orders.requested_delivery_date THEN 1 END)
      * 100.0 / NULLIF(COUNT(orders.actual_delivery_date), 0)
      WITH SYNONYMS = ('OTD', 'on time delivery', 'carrier performance')
      COMMENT = 'On-Time Delivery Rate - same canonical formula as all views'
  )

  COMMENT = 'Logistics-focused view - carrier performance, freight costs, transit analytics'

  AI_SQL_GENERATION 'You are a logistics analytics expert. Focus on carrier performance, freight optimization, transit reliability. OTD = delivered on/before requested / total delivered * 100. Same formula across all views.';

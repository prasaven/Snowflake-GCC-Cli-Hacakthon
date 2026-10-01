-- ============================================================
-- 02_synthetic_data.sql
-- Supply Chain Ontology - Synthetic Structured Data
-- 8 tables, ~69K rows simulating multi-system supply chain
-- ============================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA RAW;

-- PLANTS (12 facilities across 4 regions)
CREATE OR REPLACE TABLE PLANTS AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS plant_id,
    'PLT-' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4())::STRING, 3, '0') AS plant_code,
    CASE MOD(SEQ4(), 12)
        WHEN 0 THEN 'Detroit Assembly' WHEN 1 THEN 'Shanghai Hub' WHEN 2 THEN 'Munich Factory'
        WHEN 3 THEN 'Monterrey Plant' WHEN 4 THEN 'Chennai Works' WHEN 5 THEN 'Sao Paulo Center'
        WHEN 6 THEN 'Tokyo Precision' WHEN 7 THEN 'Dallas Logistics' WHEN 8 THEN 'Rotterdam DC'
        WHEN 9 THEN 'Seoul Tech Plant' WHEN 10 THEN 'Birmingham Assembly' WHEN 11 THEN 'Guadalajara Electronics'
    END AS plant_name,
    CASE MOD(SEQ4(), 12)
        WHEN 0 THEN 'North America' WHEN 1 THEN 'Asia Pacific' WHEN 2 THEN 'Europe'
        WHEN 3 THEN 'North America' WHEN 4 THEN 'Asia Pacific' WHEN 5 THEN 'Latin America'
        WHEN 6 THEN 'Asia Pacific' WHEN 7 THEN 'North America' WHEN 8 THEN 'Europe'
        WHEN 9 THEN 'Asia Pacific' WHEN 10 THEN 'Europe' WHEN 11 THEN 'North America'
    END AS region,
    CASE MOD(SEQ4(), 12)
        WHEN 0 THEN 'United States' WHEN 1 THEN 'China' WHEN 2 THEN 'Germany'
        WHEN 3 THEN 'Mexico' WHEN 4 THEN 'India' WHEN 5 THEN 'Brazil'
        WHEN 6 THEN 'Japan' WHEN 7 THEN 'United States' WHEN 8 THEN 'Netherlands'
        WHEN 9 THEN 'South Korea' WHEN 10 THEN 'United Kingdom' WHEN 11 THEN 'Mexico'
    END AS country,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Assembly' WHEN 1 THEN 'Distribution' ELSE 'Manufacturing' END AS plant_type,
    ROUND(5000 + UNIFORM(0::FLOAT, 45000::FLOAT, RANDOM()), 0)::INT AS capacity_units_per_day,
    ROUND(55 + UNIFORM(0::FLOAT, 40::FLOAT, RANDOM()), 1) AS utilization_pct
FROM TABLE(GENERATOR(ROWCOUNT => 12));

-- SUPPLIERS (200 vendors across tiers)
CREATE OR REPLACE TABLE SUPPLIERS AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS supplier_id,
    'SUP-' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4())::STRING, 4, '0') AS supplier_code,
    CASE MOD(SEQ4(), 20)
        WHEN 0 THEN 'Apex Manufacturing' WHEN 1 THEN 'GlobalParts Inc' WHEN 2 THEN 'PrecisionTech Ltd'
        WHEN 3 THEN 'SteelWorks Corp' WHEN 4 THEN 'ChemSupply AG' WHEN 5 THEN 'ElectroParts GmbH'
        WHEN 6 THEN 'Pacific Components' WHEN 7 THEN 'Nordic Materials' WHEN 8 THEN 'Atlas Metals'
        WHEN 9 THEN 'Quantum Plastics' WHEN 10 THEN 'RiverStone Mining' WHEN 11 THEN 'TechAlloy Systems'
        WHEN 12 THEN 'Vertex Chemicals' WHEN 13 THEN 'Onda Electronics' WHEN 14 THEN 'Fuji Precision'
        WHEN 15 THEN 'Rhine Composites' WHEN 16 THEN 'Delta Fasteners' WHEN 17 THEN 'Omega Bearings'
        WHEN 18 THEN 'Summit Polymers' WHEN 19 THEN 'Cascade Semiconductors'
    END AS supplier_name,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'China' WHEN 1 THEN 'Germany' WHEN 2 THEN 'United States' WHEN 3 THEN 'Japan'
        WHEN 4 THEN 'South Korea' WHEN 5 THEN 'India' WHEN 6 THEN 'Mexico' WHEN 7 THEN 'Brazil'
    END AS country,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'APAC' WHEN 1 THEN 'EMEA' WHEN 2 THEN 'NA' WHEN 3 THEN 'APAC'
        WHEN 4 THEN 'APAC' WHEN 5 THEN 'APAC' WHEN 6 THEN 'NA' WHEN 7 THEN 'LATAM'
    END AS region,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Tier 1' WHEN 1 THEN 'Tier 2' ELSE 'Tier 3' END AS supplier_tier,
    ROUND(5 + UNIFORM(0::FLOAT, 45::FLOAT, RANDOM()), 0)::INT AS lead_time_days,
    ROUND(60 + UNIFORM(0::FLOAT, 39::FLOAT, RANDOM()), 1) AS quality_score,
    CASE MOD(SEQ4(), 5) WHEN 4 THEN 'Probation' ELSE 'Active' END AS status,
    DATEADD('day', -UNIFORM(365, 3650, RANDOM()), CURRENT_DATE()) AS onboarded_date
FROM TABLE(GENERATOR(ROWCOUNT => 200));

-- PARTS (1000 items)
CREATE OR REPLACE TABLE PARTS AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS part_id,
    'PRT-' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4())::STRING, 5, '0') AS part_code,
    CASE MOD(SEQ4(), 25)
        WHEN 0 THEN 'Bearing Assembly A1' WHEN 1 THEN 'Control Module X7' WHEN 2 THEN 'Steel Frame Panel'
        WHEN 3 THEN 'Hydraulic Pump Unit' WHEN 4 THEN 'Wiring Harness B3' WHEN 5 THEN 'Sensor Array Module'
        WHEN 6 THEN 'Aluminum Housing' WHEN 7 THEN 'PCB Board v2.1' WHEN 8 THEN 'Rubber Gasket Set'
        WHEN 9 THEN 'Carbon Fiber Sheet' WHEN 10 THEN 'Motor Drive Unit' WHEN 11 THEN 'Thermal Insulator'
        WHEN 12 THEN 'Pneumatic Valve' WHEN 13 THEN 'Copper Connector' WHEN 14 THEN 'Gear Assembly G4'
        WHEN 15 THEN 'Optical Lens Array' WHEN 16 THEN 'Battery Cell Pack' WHEN 17 THEN 'Titanium Bracket'
        WHEN 18 THEN 'Polymer Seal Ring' WHEN 19 THEN 'Microchip MC-500' WHEN 20 THEN 'Coolant Tube'
        WHEN 21 THEN 'Brake Pad Composite' WHEN 22 THEN 'LED Display Panel' WHEN 23 THEN 'Stainless Filter'
        WHEN 24 THEN 'Power Inverter Unit'
    END AS part_name,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'Mechanical' WHEN 1 THEN 'Electronic' WHEN 2 THEN 'Structural'
        WHEN 3 THEN 'Hydraulic' WHEN 4 THEN 'Electrical' WHEN 5 THEN 'Composite'
    END AS category,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'Raw Material' WHEN 1 THEN 'Component' WHEN 2 THEN 'Sub-Assembly' ELSE 'Finished Good'
    END AS part_type,
    ROUND(1.5 + UNIFORM(0::FLOAT, 498::FLOAT, RANDOM()), 2) AS unit_cost,
    ROUND(0.05 + UNIFORM(0::FLOAT, 24.95::FLOAT, RANDOM()), 2) AS weight_kg,
    MOD(UNIFORM(1, 200, RANDOM()), 200) + 1 AS primary_supplier_id,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'A' WHEN 1 THEN 'B' ELSE 'C' END AS abc_class
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

-- CUSTOMERS (500 accounts)
CREATE OR REPLACE TABLE CUSTOMERS AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS customer_id,
    'CUST-' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4())::STRING, 5, '0') AS customer_code,
    CASE MOD(SEQ4(), 15)
        WHEN 0 THEN 'Acme Corp' WHEN 1 THEN 'TechGlobal Inc' WHEN 2 THEN 'RetailMax'
        WHEN 3 THEN 'AutoDrive Systems' WHEN 4 THEN 'MediHealth Solutions' WHEN 5 THEN 'AeroSpace Dynamics'
        WHEN 6 THEN 'GreenEnergy Co' WHEN 7 THEN 'BuildRight Construction' WHEN 8 THEN 'FoodChain Industries'
        WHEN 9 THEN 'PharmaCare Ltd' WHEN 10 THEN 'Stellar Electronics' WHEN 11 THEN 'OceanFreight Corp'
        WHEN 12 THEN 'SmartHome Tech' WHEN 13 THEN 'IndustrialWorks' WHEN 14 THEN 'NextGen Mobility'
    END AS customer_name,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'Enterprise' WHEN 1 THEN 'Mid-Market' WHEN 2 THEN 'SMB' ELSE 'Strategic'
    END AS segment,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'North America' WHEN 1 THEN 'Europe' WHEN 2 THEN 'Asia Pacific'
        WHEN 3 THEN 'North America' WHEN 4 THEN 'Europe' WHEN 5 THEN 'Latin America'
    END AS region,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'United States' WHEN 1 THEN 'Germany' WHEN 2 THEN 'Japan'
        WHEN 3 THEN 'Canada' WHEN 4 THEN 'United Kingdom' WHEN 5 THEN 'Brazil'
    END AS country,
    ROUND(100000 + UNIFORM(0::FLOAT, 9900000::FLOAT, RANDOM()), 0) AS annual_revenue
FROM TABLE(GENERATOR(ROWCOUNT => 500));

-- ORDERS (10000 purchase orders)
CREATE OR REPLACE TABLE ORDERS AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS order_id,
    'ORD-' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4())::STRING, 7, '0') AS order_code,
    MOD(UNIFORM(1, 500, RANDOM()), 500) + 1 AS customer_id,
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), CURRENT_DATE()) AS order_date,
    NULL::DATE AS requested_delivery_date,
    NULL::DATE AS actual_delivery_date,
    CASE 
        WHEN UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.70 THEN 'Delivered'
        WHEN UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.50 THEN 'Shipped'
        WHEN UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.50 THEN 'Processing'
        ELSE 'Pending'
    END AS status,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Standard' WHEN 1 THEN 'Express' ELSE 'Economy' END AS shipping_priority
FROM TABLE(GENERATOR(ROWCOUNT => 10000));

-- Fix dates to be logically consistent
UPDATE ORDERS SET 
    requested_delivery_date = DATEADD('day', UNIFORM(5, 30, RANDOM()), order_date),
    actual_delivery_date = CASE 
        WHEN status = 'Delivered' THEN DATEADD('day', UNIFORM(3, 35, RANDOM()), order_date)
        ELSE NULL
    END;

-- ORDER_LINES (25000 line items)
CREATE OR REPLACE TABLE ORDER_LINES AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS order_line_id,
    MOD(UNIFORM(1, 10000, RANDOM()), 10000) + 1 AS order_id,
    MOD(UNIFORM(1, 1000, RANDOM()), 1000) + 1 AS part_id,
    MOD(UNIFORM(1, 12, RANDOM()), 12) + 1 AS plant_id,
    GREATEST(1, ROUND(UNIFORM(1::FLOAT, 500::FLOAT, RANDOM()), 0)::INT) AS qty_ordered,
    GREATEST(0, ROUND(UNIFORM(0::FLOAT, 500::FLOAT, RANDOM()), 0)::INT) AS qty_fulfilled,
    ROUND(5 + UNIFORM(0::FLOAT, 495::FLOAT, RANDOM()), 2) AS unit_price,
    ROUND(0.05 + UNIFORM(0::FLOAT, 0.15::FLOAT, RANDOM()), 3) AS discount_pct
FROM TABLE(GENERATOR(ROWCOUNT => 25000));

UPDATE ORDER_LINES SET qty_fulfilled = LEAST(qty_fulfilled, qty_ordered);

-- SHIPMENTS (8000 logistics records)
CREATE OR REPLACE TABLE SHIPMENTS AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS shipment_id,
    'SHP-' || LPAD(ROW_NUMBER() OVER (ORDER BY SEQ4())::STRING, 7, '0') AS shipment_code,
    MOD(UNIFORM(1, 10000, RANDOM()), 10000) + 1 AS order_id,
    MOD(UNIFORM(1, 12, RANDOM()), 12) + 1 AS origin_plant_id,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'DHL Express' WHEN 1 THEN 'Maersk Logistics' WHEN 2 THEN 'FedEx Freight'
        WHEN 3 THEN 'UPS Supply Chain' WHEN 4 THEN 'DB Schenker' WHEN 5 THEN 'Kuehne+Nagel'
        WHEN 6 THEN 'XPO Logistics' WHEN 7 THEN 'CMA CGM'
    END AS carrier,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'Ocean' WHEN 1 THEN 'Air' WHEN 2 THEN 'Ground' ELSE 'Rail'
    END AS transport_mode,
    DATEADD('day', -UNIFORM(0, 350, RANDOM()), CURRENT_DATE()) AS ship_date,
    DATEADD('day', -UNIFORM(0, 350, RANDOM()) + UNIFORM(1, 30, RANDOM()), CURRENT_DATE()) AS estimated_arrival,
    CASE 
        WHEN UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.85
        THEN DATEADD('day', -UNIFORM(0, 350, RANDOM()) + UNIFORM(1, 35, RANDOM()), CURRENT_DATE())
        ELSE NULL
    END AS actual_arrival,
    ROUND(50 + UNIFORM(0::FLOAT, 4950::FLOAT, RANDOM()), 2) AS freight_cost,
    GREATEST(1, ROUND(UNIFORM(1::FLOAT, 500::FLOAT, RANDOM()), 0)::INT) AS qty_shipped,
    ROUND(0.5 + UNIFORM(0::FLOAT, 24.5::FLOAT, RANDOM()), 1) AS weight_tons,
    CASE 
        WHEN UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.75 THEN 'Delivered'
        WHEN UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.60 THEN 'In Transit'
        ELSE 'Pending Pickup'
    END AS status
FROM TABLE(GENERATOR(ROWCOUNT => 8000));

-- INVENTORY (5000 stock positions)
CREATE OR REPLACE TABLE INVENTORY AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS inventory_id,
    MOD(UNIFORM(1, 1000, RANDOM()), 1000) + 1 AS part_id,
    MOD(UNIFORM(1, 12, RANDOM()), 12) + 1 AS plant_id,
    GREATEST(0, ROUND(UNIFORM(0::FLOAT, 5000::FLOAT, RANDOM()), 0)::INT) AS qty_on_hand,
    GREATEST(0, ROUND(UNIFORM(0::FLOAT, 1000::FLOAT, RANDOM()), 0)::INT) AS qty_reserved,
    GREATEST(10, ROUND(UNIFORM(10::FLOAT, 500::FLOAT, RANDOM()), 0)::INT) AS reorder_point,
    GREATEST(50, ROUND(UNIFORM(50::FLOAT, 2000::FLOAT, RANDOM()), 0)::INT) AS safety_stock,
    ROUND(UNIFORM(10::FLOAT, 200::FLOAT, RANDOM()), 1) AS avg_daily_demand,
    DATEADD('day', -UNIFORM(0, 30, RANDOM()), CURRENT_DATE()) AS snapshot_date
FROM TABLE(GENERATOR(ROWCOUNT => 5000));

-- IOT_SENSOR_READINGS (20000 telemetry records)
CREATE OR REPLACE TABLE IOT_SENSOR_READINGS AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS reading_id,
    MOD(UNIFORM(1, 8000, RANDOM()), 8000) + 1 AS shipment_id,
    MOD(UNIFORM(1, 12, RANDOM()), 12) + 1 AS plant_id,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'Temperature' WHEN 1 THEN 'Humidity' WHEN 2 THEN 'Vibration' ELSE 'Pressure'
    END AS sensor_type,
    ROUND(UNIFORM(-20::FLOAT, 80::FLOAT, RANDOM()), 2) AS reading_value,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'Celsius' WHEN 1 THEN 'Percent' WHEN 2 THEN 'G-force' ELSE 'PSI'
    END AS unit_of_measure,
    CASE 
        WHEN UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.92 THEN 'Normal'
        WHEN UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) < 0.70 THEN 'Warning'
        ELSE 'Critical'
    END AS alert_status,
    DATEADD('minute', -UNIFORM(0, 525600, RANDOM()), CURRENT_TIMESTAMP()) AS reading_timestamp
FROM TABLE(GENERATOR(ROWCOUNT => 20000));

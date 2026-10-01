-- ============================================================
-- 03_unstructured_data.sql
-- Supply Chain Knowledge Base - Contracts, Policies, Reports
-- ============================================================

USE DATABASE SC_ONTOLOGY;
USE SCHEMA DOCUMENTS;

CREATE OR REPLACE TABLE SUPPLY_CHAIN_KNOWLEDGE (
    doc_id INT AUTOINCREMENT,
    doc_type VARCHAR(50),
    title VARCHAR(500),
    content VARCHAR(16000),
    category VARCHAR(100),
    related_entity VARCHAR(200),
    effective_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO SUPPLY_CHAIN_KNOWLEDGE (doc_type, title, content, category, related_entity, effective_date)
VALUES
('Contract', 'Master Supply Agreement - Apex Manufacturing', 'This Master Supply Agreement between OurCorp and Apex Manufacturing establishes terms for supply of mechanical components. Key terms: Payment terms NET-30. Minimum order quantity 500 units. Lead time guarantee 14 business days. Quality threshold 98.5% acceptance rate. Penalty for late delivery: 2% of order value per day beyond 5 days late. Force majeure clause covers natural disasters, pandemics, and trade embargoes. Annual volume commitment: 50,000 units minimum. Price escalation capped at 3% annually tied to PPI index.', 'Procurement', 'Apex Manufacturing', '2025-01-15'),

('Contract', 'Logistics Service Agreement - DHL Express', 'Service Level Agreement with DHL Express for global freight forwarding. Coverage: All plants in North America and Europe. Service levels: Express (2-day) 99.5% on-time target, Standard (5-day) 97% on-time target, Economy (10-day) 95% on-time target. Pricing: Per-kg rates by lane with fuel surcharge adjustment quarterly. Claims process: File within 48 hours, resolution within 14 business days. Temperature-controlled shipments available at 15% premium. Real-time tracking via API integration mandatory.', 'Logistics', 'DHL Express', '2025-03-01'),

('Contract', 'Carrier Rate Agreement - Maersk Logistics', 'Ocean freight rate agreement with Maersk Logistics. Lanes covered: Shanghai-Rotterdam, Shanghai-Los Angeles, Mumbai-Rotterdam. Container types: 20ft standard, 40ft standard, 40ft high-cube, refrigerated. Transit times: Asia-Europe 28-32 days, Asia-USWC 14-18 days. Volume commitment: 200 TEU per quarter minimum. Demurrage and detention: 5 free days at origin, 7 free days at destination. Rate validity: 12 months with quarterly BAF adjustment.', 'Logistics', 'Maersk Logistics', '2025-02-01'),

('Quality Report', 'Q1 2025 Supplier Quality Summary', 'Quarterly supplier quality assessment results. Top performers: Fuji Precision (99.2% acceptance), PrecisionTech Ltd (98.8%), Nordic Materials (98.5%). Underperformers requiring corrective action: Quantum Plastics (87.3% - issued SCAR), RiverStone Mining (89.1% - material contamination issues), Delta Fasteners (90.2% - dimensional non-conformance). Root cause analysis: 45% of defects traced to raw material variability, 30% to process control gaps, 25% to packaging/handling damage during transit.', 'Quality', 'Multiple Suppliers', '2025-04-01'),

('Quality Report', 'Critical Non-Conformance Report - NCR-2025-0847', 'Non-conformance report for batch B-2025-3847 from Quantum Plastics. Part: Polymer Seal Ring (PRT-00019). Defect: Material hardness out of specification (Shore A 55 vs required 65-70). Quantity affected: 2,400 units. Impact: Production line stoppage at Detroit Assembly for 6 hours. Root cause: Supplier used recycled polymer feedstock without authorization. Corrective action: Supplier placed on probation, 100% incoming inspection required, alternative supplier qualification initiated. Cost impact: $47,000 in production losses plus $12,000 in expedited replacement shipment.', 'Quality', 'Quantum Plastics', '2025-03-15'),

('Policy', 'Inbound Logistics Routing Guide', 'Standard routing instructions for all inbound shipments to OurCorp facilities. Rule 1: All shipments over 10,000 lbs must use ocean freight for cost optimization unless lead time is less than 15 days. Rule 2: Temperature-sensitive materials require monitored containers with IoT sensors. Rule 3: Hazardous materials must route through certified carriers only (DHL, DB Schenker). Rule 4: Consolidation required for LTL shipments - use Dallas Logistics as cross-dock hub for North America. Rule 5: All international shipments require commercial invoice, packing list, and certificate of origin. Rule 6: Preferred carriers by region - NA: FedEx/UPS, EMEA: DHL/DB Schenker, APAC: Maersk/Kuehne+Nagel.', 'Logistics', 'All Plants', '2025-01-01'),

('Policy', 'Inventory Management Policy', 'Corporate inventory management standards. Safety stock calculation: 1.65 * SQRT(avg_lead_time_days) * daily_demand_stddev. Reorder point: safety_stock + (avg_daily_demand * avg_lead_time_days). ABC classification review: quarterly based on annual dollar usage. A-items (top 20% by value): weekly cycle count, B-items: monthly, C-items: quarterly. Maximum days of inventory targets: A-items 15 days, B-items 30 days, C-items 60 days. Dead stock threshold: no movement in 180 days triggers disposition review.', 'Planning', 'All Plants', '2025-01-01'),

('Policy', 'Supplier Risk Management Framework', 'Risk assessment methodology for supply base. Risk categories: Financial (Dun and Bradstreet score), Operational (quality score + OTD), Geographic (country risk index), Concentration (single-source flag). Risk scoring: Critical (score > 80), High (60-80), Medium (40-60), Low (< 40). Mitigation requirements: Critical - dual source within 90 days or safety stock 45 days. High - qualification of backup supplier within 180 days. Tier 1 suppliers must maintain business continuity plans with 72-hour recovery time objective.', 'Procurement', 'All Suppliers', '2025-01-01'),

('Planning Guide', 'Demand Forecasting Methodology', 'Standard demand forecasting approach. Method: Weighted combination of statistical forecast (60%) and sales team input (40%). Statistical models: ARIMA for stable demand, exponential smoothing for trending products, Croston method for intermittent demand. Forecast accuracy target: MAPE < 15% at SKU-month level, < 10% at product family-month level. Bias monitoring: trigger re-calibration if bias exceeds +/- 5% for 3 consecutive months. Forecast freeze: 4 weeks before production month.', 'Planning', 'All Products', '2025-01-01'),

('Planning Guide', 'S&OP Process Guide', 'Sales and Operations Planning monthly cadence. Week 1: Statistical forecast generation + demand sensing. Week 2: Demand review with sales/marketing. Week 3: Supply review - capacity constraints, material availability. Week 4: Executive S&OP - resolve gaps, approve plan. Key outputs: Consensus demand plan, production plan, procurement plan, inventory targets. Horizon: 18-month rolling plan with monthly buckets.', 'Planning', 'Cross-functional', '2025-01-01'),

('Policy', 'Supplier Code of Conduct', 'All suppliers must comply with this Code of Conduct. Environmental: ISO 14001 certification required for Tier 1 suppliers by 2026. Carbon reporting mandatory. Conflict minerals: Full CMRT required for electronics suppliers. Labor: No child labor, no forced labor, fair wages. Working hours not to exceed 60 per week. Safety: Zero tolerance for workplace fatalities. Audit rights: OurCorp reserves right to conduct unannounced audits with 48-hour notice.', 'Compliance', 'All Suppliers', '2025-01-01'),

('Report', 'Supply Chain Disruption Analysis - Q1 2025', 'Summary of supply chain disruptions in Q1 2025. Total disruption events: 23. Critical (production impact): 4. Major causes: Port congestion Shanghai (7 events), Semiconductor allocation Cascade Semiconductors (3 events), Quality escapes Quantum Plastics (2 events), Weather delays Northern Europe (5 events), Customs delays Mexico-US (6 events). Financial impact: $2.3M expediting, $890K lost production, $450K customer penalties.', 'Risk Management', 'Multiple', '2025-04-10'),

('Procedure', 'Expedite Request Process', 'Process for requesting expedited shipments. Step 1: Submit expedite form with justification. Step 2: Planning evaluates impact on other orders. Step 3: Logistics quotes expedite cost (typically 3-5x standard). Step 4: Approval authority: < $5K dept manager, $5K-$25K plant director, > $25K VP Supply Chain. Step 5: Execute and track. KPI: Expedite rate target < 5% of total shipments.', 'Logistics', 'All Plants', '2025-01-01'),

('Technical Spec', 'IoT Sensor Requirements for Cold Chain', 'Requirements for IoT monitoring on temperature-controlled shipments. Sensors: Temperature (+/- 0.5C), Humidity (+/- 3%), Shock (threshold 3G). Reporting: Every 15 minutes. Alert: Temperature excursion > 2C from setpoint for > 30 min = critical alert. Data retention: 2 years (FDA compliance). Integration: REST API push within 5 minutes. Battery: 30 days minimum. Certifications: IP67, ATEX Zone 2.', 'Quality', 'Cold Chain Shipments', '2025-02-01'),

('KPI Definition', 'Supply Chain KPI Dictionary', 'Official KPI definitions. OTD%: Orders delivered on/before requested date / total delivered * 100. FILL RATE: qty_shipped / qty_ordered * 100 at line level. DOI: avg inventory on hand / avg daily demand. LANDED COST: material + freight + duties + handling per unit. PERFECT ORDER RATE: on time + in full + correct docs + no damage. CASH-TO-CASH: DOI + DSO - DPO.', 'Governance', 'All Metrics', '2025-01-01');

import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Supply Chain Intelligence - Admin Console", layout="wide")

session = get_active_session()

st.title("Supply Chain Intelligence Platform")
st.caption("Governed Ontology | Canonical Metrics | AI-Powered Insights | Admin Console")

page = st.sidebar.radio("Navigation", [
    "Executive Dashboard",
    "AI Intelligence",
    "Agent Monitoring & Traceability",
    "Data Governance & Policies",
    "Data Quality (DMFs)",
    "Alerts & Anomalies",
    "Ontology Management"
])

# ============================================================
# PAGE 1: EXECUTIVE DASHBOARD
# ============================================================
if page == "Executive Dashboard":
    st.header("Executive Dashboard - Canonical KPIs")

    col1, col2, col3, col4 = st.columns(4)

    otd = session.sql("""
        SELECT ROUND(COUNT(CASE WHEN actual_delivery_date <= requested_delivery_date THEN 1 END) * 100.0 
            / NULLIF(COUNT(actual_delivery_date), 0), 2) AS otd
        FROM SC_ONTOLOGY.RAW.ORDERS WHERE actual_delivery_date IS NOT NULL
    """).collect()[0]['OTD']

    fill_rate = session.sql("""
        SELECT ROUND(SUM(qty_fulfilled) * 100.0 / NULLIF(SUM(qty_ordered), 0), 2) AS fr
        FROM SC_ONTOLOGY.RAW.ORDER_LINES
    """).collect()[0]['FR']

    doi = session.sql("""
        SELECT ROUND(AVG(qty_on_hand) / NULLIF(AVG(avg_daily_demand), 0), 1) AS doi
        FROM SC_ONTOLOGY.RAW.INVENTORY
    """).collect()[0]['DOI']

    freight = session.sql("""
        SELECT ROUND(AVG(freight_cost / NULLIF(qty_shipped, 0)), 2) AS fpu
        FROM SC_ONTOLOGY.RAW.SHIPMENTS
    """).collect()[0]['FPU']

    col1.metric("On-Time Delivery (OTD%)", f"{otd}%", delta="-47.05 vs 95% target", delta_color="inverse")
    col2.metric("Fill Rate", f"{fill_rate}%", delta="-31.34 vs 98% target", delta_color="inverse")
    col3.metric("Days of Inventory", f"{doi} days", delta="Target: 15-30 days")
    col4.metric("Freight Cost/Unit", f"${freight}", delta="Target: <$25", delta_color="inverse")

    st.divider()

    st.subheader("OTD by Plant")
    otd_plant = session.sql("""
        SELECT p.plant_name, p.region,
            ROUND(COUNT(CASE WHEN o.actual_delivery_date <= o.requested_delivery_date THEN 1 END) * 100.0 
                / NULLIF(COUNT(o.actual_delivery_date), 0), 2) AS otd_pct
        FROM SC_ONTOLOGY.RAW.ORDERS o
        JOIN SC_ONTOLOGY.RAW.ORDER_LINES ol ON o.order_id = ol.order_id
        JOIN SC_ONTOLOGY.RAW.PLANTS p ON ol.plant_id = p.plant_id
        WHERE o.actual_delivery_date IS NOT NULL
        GROUP BY p.plant_name, p.region ORDER BY otd_pct DESC
    """).to_pandas()
    st.bar_chart(otd_plant.set_index('PLANT_NAME')['OTD_PCT'])

    col_left, col_right = st.columns(2)
    with col_left:
        st.subheader("Supplier Scorecard (Bottom 15 by OTD)")
        supplier_data = session.sql("""
            SELECT supplier_name, supplier_tier, 
                ROUND(otd_pct, 1) AS otd_pct, 
                ROUND(fill_rate_pct, 1) AS fill_rate_pct,
                quality_score
            FROM SC_ONTOLOGY.ADVANCED.DT_SUPPLIER_SCORECARD
            ORDER BY otd_pct ASC LIMIT 15
        """).to_pandas()
        st.dataframe(supplier_data, use_container_width=True)

    with col_right:
        st.subheader("Inventory Health")
        inv_data = session.sql("""
            SELECT plant_name, abc_class, 
                ROUND(days_of_inventory, 1) AS doi,
                below_reorder_point AS below_rop,
                stockout_count
            FROM SC_ONTOLOGY.ADVANCED.DT_INVENTORY_HEALTH
            ORDER BY days_of_inventory DESC LIMIT 15
        """).to_pandas()
        st.dataframe(inv_data, use_container_width=True)

# ============================================================
# PAGE 2: AI INTELLIGENCE
# ============================================================
elif page == "AI Intelligence":
    st.header("AI-Powered Intelligence")

    ai_tab1, ai_tab2, ai_tab3, ai_tab4 = st.tabs([
        "Supplier Risk Assessment", "Document Intelligence", 
        "Transit Prediction", "Order Prioritization"
    ])

    with ai_tab1:
        st.subheader("AI Supplier Risk Assessment")
        st.info("Uses CORTEX.COMPLETE to analyze supplier metrics + quality documents + country risk")
        supplier_input = st.text_input("Enter supplier name:", "Quantum Plastics")
        if st.button("Generate AI Risk Report"):
            with st.spinner("Running AI analysis (CORTEX.COMPLETE)..."):
                result = session.sql(f"""
                    SELECT SC_ONTOLOGY.ADVANCED.SUPPLIER_RISK_ASSESSMENT('{supplier_input}') AS assessment
                """).collect()[0]['ASSESSMENT']
                st.markdown(result)

    with ai_tab2:
        st.subheader("Document Sentiment & Classification")
        st.info("Uses CORTEX.SENTIMENT + CORTEX.CLASSIFY_TEXT on supply chain documents")
        sentiment_data = session.sql("""
            SELECT title, doc_type, category, 
                ROUND(SNOWFLAKE.CORTEX.SENTIMENT(content), 3) AS sentiment,
                CASE WHEN SNOWFLAKE.CORTEX.SENTIMENT(content) > 0.3 THEN 'Positive'
                     WHEN SNOWFLAKE.CORTEX.SENTIMENT(content) < -0.3 THEN 'Negative'
                     ELSE 'Neutral' END AS sentiment_label
            FROM SC_ONTOLOGY.DOCUMENTS.SUPPLY_CHAIN_KNOWLEDGE
            ORDER BY sentiment ASC
        """).to_pandas()
        st.dataframe(sentiment_data, use_container_width=True)

    with ai_tab3:
        st.subheader("ML Transit Delay Prediction")
        st.info("Uses historical weather + congestion data to predict delays")
        col_o, col_d, col_w = st.columns(3)
        origin = col_o.selectbox("Origin Region", ["Asia Pacific", "Europe", "North America", "Latin America"])
        dest = col_d.selectbox("Destination Region", ["North America", "Europe", "Asia Pacific"])
        weather = col_w.selectbox("Weather Severity", ["Normal", "Moderate", "Severe", "Extreme"])
        if st.button("Predict Transit Delay"):
            pred = session.sql(f"""
                SELECT * FROM TABLE(SC_ONTOLOGY.ADVANCED.PREDICT_TRANSIT_DELAY('{origin}', '{dest}', '{weather}'))
            """).to_pandas()
            st.dataframe(pred, use_container_width=True)

    with ai_tab4:
        st.subheader("AI Order Prioritization")
        st.info("Scores pending orders by urgency: customer segment + days until due + priority")
        if st.button("Get Priority Orders"):
            priority_data = session.sql("""
                SELECT * FROM TABLE(SC_ONTOLOGY.ADVANCED.AI_PRIORITIZE_ORDERS())
            """).to_pandas()
            st.dataframe(priority_data, use_container_width=True)

# ============================================================
# PAGE 3: AGENT MONITORING & TRACEABILITY
# ============================================================
elif page == "Agent Monitoring & Traceability":
    st.header("Cortex Agent - Monitoring & Traceability")

    st.subheader("Agent Configuration")
    agent_info = session.sql("""
        DESCRIBE AGENT SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT
    """).to_pandas()
    st.dataframe(agent_info.head(20), use_container_width=True)

    st.divider()

    st.subheader("Evaluation Run Results")
    eval_summary = session.sql("""
        SELECT 
            METRIC_NAME,
            ROUND(AVG(EVAL_AGG_SCORE), 3) AS avg_score,
            COUNT(DISTINCT INPUT_ID) AS questions_evaluated
        FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
            'SC_ONTOLOGY', 'ANALYTICS', 'SUPPLY_CHAIN_AGENT', 'CORTEX AGENT', 'sc-ontology-eval-v1'
        ))
        WHERE METRIC_NAME IS NOT NULL
        GROUP BY METRIC_NAME
        ORDER BY METRIC_NAME
    """).to_pandas()
    st.dataframe(eval_summary, use_container_width=True)

    st.divider()

    st.subheader("Per-Question Evaluation Detail")
    eval_detail = session.sql("""
        SELECT 
            INPUT AS question,
            METRIC_NAME,
            EVAL_AGG_SCORE AS score,
            DURATION_MS
        FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
            'SC_ONTOLOGY', 'ANALYTICS', 'SUPPLY_CHAIN_AGENT', 'CORTEX AGENT', 'sc-ontology-eval-v1'
        ))
        WHERE METRIC_NAME = 'answer_correctness'
        ORDER BY EVAL_AGG_SCORE ASC
    """).to_pandas()
    st.dataframe(eval_detail, use_container_width=True)

    st.divider()

    st.subheader("Agent Tool Usage Analysis")
    st.markdown("""
    | Tool | Type | Routes To |
    |------|------|-----------|
    | SupplyChainAnalyst | Cortex Analyst | Cross-domain KPI queries |
    | ProcurementAnalyst | Cortex Analyst | Supplier-specific queries |
    | LogisticsAnalyst | Cortex Analyst | Carrier/freight queries |
    | KnowledgeSearch | Cortex Search | Policy/contract questions |
    | SupplierRiskAssessment | Custom (LLM) | AI risk reports |
    | TransitDelayPredictor | Custom (ML) | Weather delay predictions |
    | OrderPrioritizer | Custom (Scoring) | Expedite recommendations |
    | data_to_chart | Built-in | Visualizations |
    """)

    st.subheader("Live Agent Test")
    agent_question = st.text_input("Ask the agent:", "What is our OTD rate?")
    if st.button("Run Agent"):
        with st.spinner("Agent is thinking..."):
            response = session.sql(f"""
                SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
                    'SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT',
                    '{{"messages": [{{"role": "user", "content": [{{"type": "text", "text": "{agent_question}"}}]}}]}}'
                ) AS resp
            """).collect()[0]['RESP']
            import json
            try:
                parsed = json.loads(response)
                for item in parsed.get('content', []):
                    if item.get('type') == 'text':
                        st.markdown(item.get('text', ''))
                st.caption(f"Status: {parsed.get('status', 'unknown')}")
            except:
                st.code(response[:2000])

# ============================================================
# PAGE 4: DATA GOVERNANCE & POLICIES
# ============================================================
elif page == "Data Governance & Policies":
    st.header("Data Governance - Policies & Access Control")

    gov_tab1, gov_tab2, gov_tab3 = st.tabs(["Masking Policies", "Row Access Policies", "Object Tags"])

    with gov_tab1:
        st.subheader("Column Masking Policies")
        st.markdown("""
        Active masking policies protect sensitive data by role:
        """)
        masking_data = session.sql("""
            SHOW MASKING POLICIES IN SCHEMA SC_ONTOLOGY.GOVERNANCE
        """).to_pandas()
        st.dataframe(masking_data, use_container_width=True)

        st.divider()
        st.subheader("Policy Details")
        st.markdown("""
        | Policy | Protects | Logic |
        |--------|----------|-------|
        | `MASK_FINANCIAL_DATA` | unit_cost, freight_cost | Only roles with `can_view_financials=TRUE` see values |
        | `MASK_CUSTOMER_PII` | customer_name | ACCOUNTADMIN sees full; Planning/Procurement see first 3 chars; others see RESTRICTED |
        | `MASK_SUPPLIER_DETAILS` | supplier details | Only Procurement role sees full supplier information |
        """)

        st.subheader("Persona Access Matrix")
        persona_data = session.sql("""
            SELECT * FROM SC_ONTOLOGY.GOVERNANCE.PERSONA_REGION_ACCESS
        """).to_pandas()
        st.dataframe(persona_data, use_container_width=True)

    with gov_tab2:
        st.subheader("Row Access Policies")
        rap_data = session.sql("""
            SHOW ROW ACCESS POLICIES IN SCHEMA SC_ONTOLOGY.GOVERNANCE
        """).to_pandas()
        st.dataframe(rap_data, use_container_width=True)

        st.markdown("""
        **Policy: `RAP_REGION_FILTER`**
        
        Enforces region-based data isolation per persona:
        - `ACCOUNTADMIN`: Sees all regions
        - `SC_PLANNING_ROLE`: Sees regions in their `allowed_regions` list
        - `SC_PROCUREMENT_ROLE`: Sees regions in their `allowed_regions` list
        - `SC_LOGISTICS_ROLE`: Sees regions in their `allowed_regions` list
        
        This ensures the Planning team in North America cannot see Asia Pacific plant data unless explicitly granted.
        """)

    with gov_tab3:
        st.subheader("Object Tags Applied")
        st.info("Tags classify every table by domain, sensitivity, owner, and refresh frequency")
        tag_data = session.sql("""
            SELECT 
                OBJECT_NAME AS table_name,
                TAG_NAME,
                TAG_VALUE
            FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
                'SC_ONTOLOGY.RAW.SUPPLIERS', 'TABLE'
            ))
            UNION ALL
            SELECT OBJECT_NAME, TAG_NAME, TAG_VALUE
            FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
                'SC_ONTOLOGY.RAW.ORDERS', 'TABLE'
            ))
            UNION ALL
            SELECT OBJECT_NAME, TAG_NAME, TAG_VALUE
            FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
                'SC_ONTOLOGY.RAW.SHIPMENTS', 'TABLE'
            ))
        """).to_pandas()
        st.dataframe(tag_data, use_container_width=True)

        st.subheader("Tag Definitions")
        st.markdown("""
        | Tag | Purpose | Allowed Values |
        |-----|---------|---------------|
        | `ONTOLOGY_DOMAIN` | Business domain classification | ERP, Logistics, Supplier, IoT, Finance, Planning |
        | `DATA_SENSITIVITY` | Security classification | Public, Internal, Confidential, Restricted |
        | `DATA_OWNER` | Responsible team | Planning, Procurement, Logistics, Sales, Operations |
        | `REFRESH_FREQUENCY` | Data freshness SLA | Real-time, Hourly, Daily, Weekly, Static |
        """)

# ============================================================
# PAGE 5: DATA QUALITY (DMFs)
# ============================================================
elif page == "Data Quality (DMFs)":
    st.header("Data Quality Monitoring - Data Metric Functions")

    st.info("DMFs automatically monitor data quality and fire on every data change (TRIGGER_ON_CHANGES)")

    st.subheader("Active Data Metric Functions")
    st.markdown("""
    | DMF | Attached To | What It Checks | Threshold |
    |-----|-------------|---------------|-----------|
    | `DMF_NEGATIVE_INVENTORY` | `RAW.INVENTORY` | qty_on_hand < 0 | Any occurrence = violation |
    | `DMF_NULL_DELIVERY_DATES` | `RAW.ORDERS` | Delivered status but NULL actual_delivery_date | Any = data issue |
    | `DMF_LOW_FILL_RATE` | `RAW.ORDER_LINES` | fill rate < 50% per line | Count of violations |
    """)

    st.divider()

    st.subheader("Current Quality Check Results")

    col1, col2, col3 = st.columns(3)

    neg_inv = session.sql("""
        SELECT COUNT(*) AS cnt FROM SC_ONTOLOGY.RAW.INVENTORY WHERE qty_on_hand < 0
    """).collect()[0]['CNT']

    null_dates = session.sql("""
        SELECT COUNT(*) AS cnt FROM SC_ONTOLOGY.RAW.ORDERS 
        WHERE status = 'Delivered' AND actual_delivery_date IS NULL
    """).collect()[0]['CNT']

    low_fill = session.sql("""
        SELECT COUNT(*) AS cnt FROM SC_ONTOLOGY.RAW.ORDER_LINES 
        WHERE qty_ordered > 0 AND (qty_fulfilled * 1.0 / qty_ordered) < 0.5
    """).collect()[0]['CNT']

    col1.metric("Negative Inventory Records", neg_inv, delta="0 = healthy", delta_color="off")
    col2.metric("Delivered w/o Date", null_dates, delta="0 = healthy", delta_color="off")
    col3.metric("Lines Below 50% Fill", low_fill, delta="Lower is better", delta_color="inverse")

    st.divider()
    st.subheader("DMF Execution History")
    dmf_history = session.sql("""
        SELECT 
            MEASUREMENT_TIME,
            METRIC_DATABASE || '.' || METRIC_SCHEMA || '.' || METRIC_NAME AS dmf_name,
            TABLE_DATABASE || '.' || TABLE_SCHEMA || '.' || TABLE_NAME AS monitored_table,
            VALUE AS violation_count
        FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
        WHERE TABLE_DATABASE = 'SC_ONTOLOGY'
        ORDER BY MEASUREMENT_TIME DESC
        LIMIT 20
    """).to_pandas()
    if len(dmf_history) > 0:
        st.dataframe(dmf_history, use_container_width=True)
    else:
        st.caption("No DMF executions recorded yet. Results appear after data changes trigger the metric functions.")

# ============================================================
# PAGE 6: ALERTS & ANOMALIES
# ============================================================
elif page == "Alerts & Anomalies":
    st.header("Proactive Monitoring - Alerts & Anomaly Detection")

    st.subheader("Active Snowflake Alerts")
    alerts_data = session.sql("""
        SHOW ALERTS IN SCHEMA SC_ONTOLOGY.ADVANCED
    """).to_pandas()
    st.dataframe(alerts_data[['name', 'schedule', 'state', 'condition', 'comment']] if 'name' in alerts_data.columns else alerts_data, use_container_width=True)

    st.divider()

    st.subheader("Alert History (KPI Alert Log)")
    alert_log = session.sql("""
        SELECT alert_time, metric_name, ROUND(current_value, 2) AS value, threshold, alert_type, acknowledged
        FROM SC_ONTOLOGY.ADVANCED.KPI_ALERT_LOG
        ORDER BY alert_time DESC
        LIMIT 20
    """).to_pandas()
    if len(alert_log) > 0:
        st.dataframe(alert_log, use_container_width=True)
    else:
        st.success("No alerts fired - all KPIs within thresholds")

    st.divider()

    st.subheader("OTD Time Series (Anomaly Detection Base)")
    ts_data = session.sql("""
        SELECT delivery_date, otd_pct, otd_7day_avg
        FROM SC_ONTOLOGY.ADVANCED.V_OTD_DAILY_TIMESERIES
        WHERE delivery_date >= DATEADD('day', -90, CURRENT_DATE())
        ORDER BY delivery_date
    """).to_pandas()
    if len(ts_data) > 0:
        st.line_chart(ts_data.set_index('DELIVERY_DATE')[['OTD_PCT', 'OTD_7DAY_AVG']])
    else:
        st.caption("No time series data available in the last 90 days")

    st.divider()

    st.subheader("ML Forecast: Next 30 Days Order Volume")
    st.info("Model: SNOWFLAKE.ML.FORECAST trained on daily order counts")
    try:
        session.sql("CALL SC_ONTOLOGY.ADVANCED.ORDER_VOLUME_FORECAST!FORECAST(FORECASTING_PERIODS => 30)").collect()
        forecast_data = session.sql("SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))").to_pandas()
        st.line_chart(forecast_data.set_index('TS')['FORECAST'])
    except:
        st.caption("Forecast model available - run CALL ORDER_VOLUME_FORECAST!FORECAST(30) to generate predictions")

# ============================================================
# PAGE 7: ONTOLOGY MANAGEMENT
# ============================================================
elif page == "Ontology Management":
    st.header("Ontology Version Control & Management")

    st.subheader("Ontology Changelog")
    changelog = session.sql("""
        SELECT version_tag, change_date, change_type, object_affected, description, breaking_change
        FROM SC_ONTOLOGY.GOVERNANCE.ONTOLOGY_CHANGELOG
        ORDER BY version_id DESC
    """).to_pandas()
    st.dataframe(changelog, use_container_width=True)

    st.divider()

    st.subheader("Semantic Views Registry")
    views = session.sql("""
        SHOW SEMANTIC VIEWS IN SCHEMA SC_ONTOLOGY.ANALYTICS
    """).to_pandas()
    st.dataframe(views, use_container_width=True)

    st.divider()

    st.subheader("Ontology Metrics Catalog")
    metrics = session.sql("""
        SELECT object_name AS metric, parent_entity AS entity, property, property_value
        FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
        WHERE object_kind = 'METRIC'
    """)
    try:
        metrics_df = session.sql("""
            SELECT object_name AS metric_name, parent_entity AS entity, property_value AS expression
            FROM TABLE(RESULT_SCAN(
                (SELECT LAST_QUERY_ID() FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) LIMIT 0)
            ))
        """).to_pandas()
        st.dataframe(metrics_df, use_container_width=True)
    except:
        metrics_static = session.sql("""
            SELECT 'ON_TIME_DELIVERY_RATE' AS metric, 'ORDERS' AS entity, 'COUNT(on_time)/COUNT(delivered)*100' AS formula
            UNION ALL SELECT 'FILL_RATE', 'ORDER_LINES', 'SUM(qty_fulfilled)/SUM(qty_ordered)*100'
            UNION ALL SELECT 'DAYS_OF_INVENTORY', 'INVENTORY', 'AVG(qty_on_hand)/AVG(daily_demand)'
            UNION ALL SELECT 'FREIGHT_COST_PER_UNIT', 'SHIPMENTS', 'AVG(freight_cost/qty_shipped)'
            UNION ALL SELECT 'TOTAL_REVENUE', 'ORDER_LINES', 'SUM(qty_fulfilled*unit_price*(1-discount))'
            UNION ALL SELECT 'TOTAL_ORDERS', 'ORDERS', 'COUNT(order_id)'
            UNION ALL SELECT 'DELIVERED_ORDERS', 'ORDERS', 'COUNT(actual_delivery_date)'
            UNION ALL SELECT 'TOTAL_SHIPMENTS', 'SHIPMENTS', 'COUNT(shipment_id)'
            UNION ALL SELECT 'AVG_FREIGHT_COST', 'SHIPMENTS', 'AVG(freight_cost)'
            UNION ALL SELECT 'TOTAL_FREIGHT_COST', 'SHIPMENTS', 'SUM(freight_cost)'
            UNION ALL SELECT 'AVG_STOCK_ON_HAND', 'INVENTORY', 'AVG(qty_on_hand)'
            UNION ALL SELECT 'AVG_ORDER_VALUE', 'ORDER_LINES', 'AVG(qty_ordered*unit_price)'
            UNION ALL SELECT 'AVG_UNIT_COST', 'PARTS', 'AVG(unit_cost)'
        """).to_pandas()
        st.dataframe(metrics_static, use_container_width=True)

    st.divider()

    st.subheader("Ontology Dimensions Catalog")
    dims_static = session.sql("""
        SELECT 'ORDER_DATE' AS dimension, 'ORDERS' AS entity, 'Date order was placed' AS description
        UNION ALL SELECT 'REQUESTED_DELIVERY_DATE', 'ORDERS', 'Customer-requested delivery date'
        UNION ALL SELECT 'ACTUAL_DELIVERY_DATE', 'ORDERS', 'Actual delivery date'
        UNION ALL SELECT 'CARRIER', 'SHIPMENTS', 'Logistics provider'
        UNION ALL SELECT 'TRANSPORT_MODE', 'SHIPMENTS', 'Ocean, Air, Ground, Rail'
        UNION ALL SELECT 'SUPPLIER_NAME', 'SUPPLIERS', 'Supplier organization name'
        UNION ALL SELECT 'SUPPLIER_TIER', 'SUPPLIERS', 'Tier 1/2/3 classification'
        UNION ALL SELECT 'PLANT_NAME', 'PLANTS', 'Facility name'
        UNION ALL SELECT 'PLANT_REGION', 'PLANTS', 'Geographic region'
        UNION ALL SELECT 'CUSTOMER_NAME', 'CUSTOMERS', 'Customer organization'
        UNION ALL SELECT 'CUSTOMER_SEGMENT', 'CUSTOMERS', 'Enterprise/Mid-Market/SMB/Strategic'
        UNION ALL SELECT 'PART_CATEGORY', 'PARTS', 'Mechanical/Electronic/Structural/etc'
        UNION ALL SELECT 'ABC_CLASS', 'PARTS', 'A (high value) / B / C (low value)'
    """).to_pandas()
    st.dataframe(dims_static, use_container_width=True)

    st.divider()

    st.subheader("Country Risk Index (External Data)")
    risk_data = session.sql("""
        SELECT * FROM SC_ONTOLOGY.ADVANCED.COUNTRY_RISK_INDEX ORDER BY risk_index DESC
    """).to_pandas()
    st.dataframe(risk_data, use_container_width=True)

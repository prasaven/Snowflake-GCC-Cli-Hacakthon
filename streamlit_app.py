import streamlit as st

import json
import os

import pandas as pd
import requests

st.set_page_config(page_title="Supply Chain Intelligence - Admin Console", layout="wide")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
session = conn.session()

def safe_scalar(query, col, default=0):
    rows = session.sql(query).collect()
    if not rows:
        return default
    val = rows[0][col]
    return val if val is not None else default

# ============================================================
# CORTEX AGENT CHAT HELPERS (REST API, server-sent events)
# ============================================================
AGENT_DB, AGENT_SCHEMA, AGENT_NAME = "SC_ONTOLOGY", "ANALYTICS", "SUPPLY_CHAIN_AGENT"
AGENT_FQN = f"{AGENT_DB}.{AGENT_SCHEMA}.{AGENT_NAME}"
AGENT_HISTORY_TURNS = 10  # prior messages sent back to the agent for context
AGENT_STARTERS = [
    "What is our overall OTD rate?",
    "Show OTD rate by carrier as a bar chart",
    "Which 5 suppliers have the worst OTD?",
    "What does our policy say about expediting orders?",
]

def _agent_post(messages):
    raw = conn.raw_connection
    url = f"https://{raw.host}/api/v2/databases/{AGENT_DB}/schemas/{AGENT_SCHEMA}/agents/{AGENT_NAME}:run"
    headers = {
        "Authorization": f'Snowflake Token="{raw.rest.token}"',
        "Content-Type": "application/json",
        "Accept": "text/event-stream",
    }
    return requests.post(url, json={"messages": messages, "stream": True},
                         headers=headers, stream=True, timeout=(10, 600))

def stream_agent_events(messages):
    """Yield (event_name, payload_dict) tuples from the agent's SSE stream."""
    resp = _agent_post(messages)
    if resp.status_code == 401:
        # Session token expired - reconnect once and retry
        resp.close()
        conn.reset()
        resp = _agent_post(messages)
    with resp:
        if resp.status_code != 200:
            yield "error", {"message": f"HTTP {resp.status_code}: {resp.text[:500]}"}
            return
        event, data_lines = None, []
        for line in resp.iter_lines(decode_unicode=True):
            if line is None:
                continue
            if line.startswith("event:"):
                event = line[6:].strip()
            elif line.startswith("data:"):
                data_lines.append(line[5:].lstrip())
            elif line == "" and event:
                data = "\n".join(data_lines)
                if data and data != "[DONE]":
                    try:
                        yield event, json.loads(data)
                    except json.JSONDecodeError:
                        pass
                event, data_lines = None, []

def result_set_to_df(result_set):
    row_type = result_set.get("resultSetMetaData", {}).get("rowType", [])
    cols = [c["name"] for c in row_type]
    df = pd.DataFrame(result_set.get("data", []), columns=cols or None)
    for meta in row_type:
        if meta.get("type") in ("fixed", "real", "number", "float"):
            df[meta["name"]] = pd.to_numeric(df[meta["name"]], errors="coerce")
    return df

def run_agent_streaming(api_messages):
    """Stream one agent turn into the current chat message; return what to store in history."""
    result = {"text": "", "thinking": "", "steps": [], "tables": [], "charts": [],
              "sql": [], "suggestions": [], "error": None}
    status = st.status("Planning the next steps...", expanded=False)
    with status:
        thinking_ph = st.empty()

    def text_stream():
        for event, data in stream_agent_events(api_messages):
            if event == "response.status":
                status.update(label=data.get("message", "Working..."))
            elif event == "response.thinking.delta":
                result["thinking"] += data.get("text", "")
                thinking_ph.markdown(result["thinking"])
            elif event == "response.tool_use":
                step = f"Tool call: **{data.get('name', 'unknown')}**"
                result["steps"].append(step)
                status.write(step)
            elif event == "response.tool_result":
                for item in data.get("content", []):
                    sql = (item.get("json") or {}).get("sql")
                    if sql and sql not in result["sql"]:
                        result["sql"].append(sql)
            elif event == "response.text.delta":
                yield data.get("text", "")
            elif event == "response.table":
                result["tables"].append({"title": data.get("title") or "Result",
                                         "df": result_set_to_df(data.get("result_set", {}))})
            elif event == "response.chart":
                if data.get("chart_spec"):
                    result["charts"].append(data["chart_spec"])
            elif event == "response.suggested_queries":
                result["suggestions"] = [q["query"] for q in data.get("suggested_queries", []) if q.get("query")]
            elif event == "error":
                result["error"] = data.get("message", str(data))

    try:
        streamed = st.write_stream(text_stream())
        result["text"] = streamed if isinstance(streamed, str) else "".join(str(s) for s in (streamed or []))
    except requests.RequestException as e:
        result["error"] = f"Request to agent failed: {e}"

    if result["error"]:
        status.update(label="Agent returned an error", state="error")
        st.error(result["error"])
    else:
        status.update(label="Response complete", state="complete")
    return result

def render_agent_artifacts(msg, show_suggestions=False, key_prefix=""):
    for t in msg.get("tables", []):
        st.caption(t["title"])
        st.dataframe(t["df"], use_container_width=True)
    for spec in msg.get("charts", []):
        try:
            st.vega_lite_chart(json.loads(spec), use_container_width=True)
        except (json.JSONDecodeError, TypeError):
            st.caption("Chart could not be rendered.")
    if msg.get("sql"):
        with st.expander("SQL generated by the agent"):
            for s in msg["sql"]:
                st.code(s, language="sql")
    if msg.get("steps") or msg.get("thinking"):
        with st.expander("Reasoning & tool calls"):
            for step in msg.get("steps", []):
                st.markdown(step)
            if msg.get("thinking"):
                st.markdown(msg["thinking"])
    if msg.get("error"):
        st.error(msg["error"])
    if show_suggestions and msg.get("suggestions"):
        st.caption("Suggested follow-ups")
        for j, q in enumerate(msg["suggestions"]):
            st.button(q, key=f"{key_prefix}_sugg_{j}", on_click=_queue_agent_prompt, args=(q,))

def _queue_agent_prompt(prompt):
    st.session_state.agent_pending_prompt = prompt

def _clear_agent_chat():
    st.session_state.agent_chat = []
    st.session_state.pop("agent_pending_prompt", None)

st.title("Supply Chain Intelligence Platform")
st.caption("Governed Ontology | Canonical Metrics | AI-Powered Insights | Admin Console")

page = st.sidebar.radio("Navigation", [
    "Executive Dashboard",
    "Agent Chatbot",
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

    otd = safe_scalar("""
        SELECT ROUND(COUNT(CASE WHEN actual_delivery_date <= requested_delivery_date THEN 1 END) * 100.0 
            / NULLIF(COUNT(actual_delivery_date), 0), 2) AS otd
        FROM SC_ONTOLOGY.RAW.ORDERS WHERE actual_delivery_date IS NOT NULL
    """, 'OTD')

    fill_rate = safe_scalar("""
        SELECT ROUND(SUM(qty_fulfilled) * 100.0 / NULLIF(SUM(qty_ordered), 0), 2) AS fr
        FROM SC_ONTOLOGY.RAW.ORDER_LINES
    """, 'FR')

    doi = safe_scalar("""
        SELECT ROUND(AVG(qty_on_hand) / NULLIF(AVG(avg_daily_demand), 0), 1) AS doi
        FROM SC_ONTOLOGY.RAW.INVENTORY
    """, 'DOI')

    freight = safe_scalar("""
        SELECT ROUND(AVG(freight_cost / NULLIF(qty_shipped, 0)), 2) AS fpu
        FROM SC_ONTOLOGY.RAW.SHIPMENTS
    """, 'FPU')

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
    st.bar_chart(otd_plant.set_index('PLANT_NAME')['OTD_PCT'].astype(float))

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
# PAGE: AGENT CHATBOT (streamed)
# ============================================================
elif page == "Agent Chatbot":
    head_l, head_r = st.columns([5, 1])
    head_l.header("Supply Chain Agent")
    head_r.button("Clear chat", on_click=_clear_agent_chat, use_container_width=True)
    st.caption(f"Streaming responses from Cortex Agent `{AGENT_FQN}`")

    if "agent_chat" not in st.session_state:
        st.session_state.agent_chat = []
    chat = st.session_state.agent_chat

    for i, msg in enumerate(chat):
        with st.chat_message(msg["role"]):
            if msg["text"]:
                st.markdown(msg["text"])
            if msg["role"] == "assistant":
                render_agent_artifacts(msg, show_suggestions=(i == len(chat) - 1), key_prefix=f"m{i}")

    if not chat:
        st.markdown("**Try asking:**")
        starter_cols = st.columns(len(AGENT_STARTERS))
        for col, q in zip(starter_cols, AGENT_STARTERS):
            col.button(q, on_click=_queue_agent_prompt, args=(q,), use_container_width=True)

    typed_prompt = st.chat_input("Ask about OTD, suppliers, inventory, freight, policies...")
    prompt = typed_prompt or st.session_state.pop("agent_pending_prompt", None)

    if prompt:
        # Send prior context as completed user/assistant text pairs only
        api_messages = []
        for user_msg, asst_msg in zip(chat[::2], chat[1::2]):
            if user_msg["role"] == "user" and asst_msg["role"] == "assistant" and asst_msg["text"]:
                api_messages += [
                    {"role": "user", "content": [{"type": "text", "text": user_msg["text"]}]},
                    {"role": "assistant", "content": [{"type": "text", "text": asst_msg["text"]}]},
                ]
        api_messages = api_messages[-AGENT_HISTORY_TURNS:]
        api_messages.append({"role": "user", "content": [{"type": "text", "text": prompt}]})

        chat.append({"role": "user", "text": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)
        with st.chat_message("assistant"):
            reply = run_agent_streaming(api_messages)
        chat.append({"role": "assistant", **reply})
        st.rerun()

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
        st.info("Uses CORTEX.COMPLETE (AI_SUPPLIER_SUMMARY) for the narrative + CALC_SUPPLIER_RISK for the risk scorecard")
        supplier_input = st.text_input("Enter supplier name:", "Quantum Plastics")
        if st.button("Generate AI Risk Report"):
            with st.spinner("Running AI analysis (CORTEX.COMPLETE)..."):
                result = session.sql(
                    "SELECT SC_ONTOLOGY.ADVANCED.AI_SUPPLIER_SUMMARY(?) AS assessment",
                    params=[supplier_input],
                ).collect()[0]['ASSESSMENT']
                risk_scores = session.sql(
                    "SELECT * FROM TABLE(SC_ONTOLOGY.ADVANCED.CALC_SUPPLIER_RISK(?)) ORDER BY risk_score DESC",
                    params=[supplier_input],
                ).to_pandas()
            st.markdown(result)
            st.subheader("Risk Scorecard")
            if len(risk_scores) > 0:
                st.dataframe(risk_scores, use_container_width=True)
            else:
                st.caption(f"No supplier records found matching '{supplier_input}'.")

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
            try:
                pred = session.sql(
                    "SELECT * FROM TABLE(SC_ONTOLOGY.ADVANCED.PREDICT_TRANSIT_DELAY(?, ?, ?))",
                    params=[origin, dest, weather],
                ).to_pandas()
                st.dataframe(pred, use_container_width=True)
            except Exception as e:
                if "Unknown user-defined" in str(e):
                    st.warning("SC_ONTOLOGY.ADVANCED.PREDICT_TRANSIT_DELAY has not been created yet. "
                               "Create the function to enable transit delay predictions.")
                else:
                    st.error(f"Prediction failed: {e}")

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

    neg_inv = safe_scalar("""
        SELECT COUNT(*) AS cnt FROM SC_ONTOLOGY.RAW.INVENTORY WHERE qty_on_hand < 0
    """, 'CNT')

    null_dates = safe_scalar("""
        SELECT COUNT(*) AS cnt FROM SC_ONTOLOGY.RAW.ORDERS 
        WHERE status = 'Delivered' AND actual_delivery_date IS NULL
    """, 'CNT')

    low_fill = safe_scalar("""
        SELECT COUNT(*) AS cnt FROM SC_ONTOLOGY.RAW.ORDER_LINES 
        WHERE qty_ordered > 0 AND (qty_fulfilled * 1.0 / qty_ordered) < 0.5
    """, 'CNT')

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
    desired_cols = ['name', 'schedule', 'state', 'condition', 'comment']
    available_cols = [c for c in desired_cols if c in alerts_data.columns]
    st.dataframe(alerts_data[available_cols] if available_cols else alerts_data, use_container_width=True)

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
        st.line_chart(ts_data.set_index('DELIVERY_DATE')[['OTD_PCT', 'OTD_7DAY_AVG']].astype(float))
    else:
        st.caption("No time series data available in the last 90 days")

    st.divider()

    st.subheader("ML Forecast: Next 30 Days Order Volume")
    st.info("Model: SNOWFLAKE.ML.FORECAST trained on daily order counts")
    try:
        session.sql("CALL SC_ONTOLOGY.ADVANCED.ORDER_VOLUME_FORECAST!FORECAST(FORECASTING_PERIODS => 30)").collect()
        forecast_data = session.sql("SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))").to_pandas()
        st.line_chart(forecast_data.set_index('TS')['FORECAST'].astype(float))
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

    st.subheader("Country Risk Index")
    risk_data = session.sql("""
        SELECT country, risk_index, climate_risk, geopolitical_risk, logistics_reliability, last_updated
        FROM SC_ONTOLOGY.ADVANCED.COUNTRY_RISK_INDEX
        ORDER BY risk_index DESC
    """).to_pandas()
    if len(risk_data) > 0:
        st.dataframe(risk_data, use_container_width=True)
    else:
        st.caption("No country risk data available yet.")

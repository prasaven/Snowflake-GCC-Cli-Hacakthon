# Supply Chain Ontology - Demo Access Guide

## Snowflake Account

| Field | Value |
|-------|-------|
| **Organization** | OPFQFPR |
| **Account** | PW91439 |
| **Login URL** | https://app.snowflake.com/OPFQFPR/PW91439 |
| **Warehouse** | `COMPUTE_WH` |
| **Database** | `SC_ONTOLOGY` |

---

## Demo Users & Credentials

### 1. Planning User

| Field | Value |
|-------|-------|
| **Username** | `SC_PLANNING_USER` |
| **Password** | `Planning@2026!` |
| **Role** | `SC_PLANNING_ROLE` |
| **Persona** | Supply Chain Planning |
| **Focus** | Demand, inventory, capacity, order management |

**What to test:**
- "What is our on-time delivery rate by plant?"
- "How many days of inventory do we have by region?"
- "What is fill rate for A-class parts?"
- "What is our inventory policy for A-class items?"

**Data access:**
- Tables: ORDERS, ORDER_LINES, INVENTORY, PARTS, PLANTS, CUSTOMERS
- Can view financials: YES
- Can view supplier details: NO

---

### 2. Procurement User

| Field | Value |
|-------|-------|
| **Username** | `SC_PROCUREMENT_USER` |
| **Password** | `Procurement@2026!` |
| **Role** | `SC_PROCUREMENT_ROLE` |
| **Persona** | Procurement |
| **Focus** | Supplier performance, spend analysis, quality, risk |

**What to test:**
- "Top 5 suppliers by spend and their quality scores"
- "What is OTD for supplier Quantum Plastics?"
- "What corrective actions were taken for Quantum Plastics?"
- "Which suppliers have the worst OTD performance?"

**Data access:**
- Tables: SUPPLIERS, PARTS, ORDER_LINES, ORDERS
- Can view financials: YES
- Can view supplier details: YES

---

### 3. Logistics User

| Field | Value |
|-------|-------|
| **Username** | `SC_LOGISTICS_USER` |
| **Password** | `Logistics@2026!` |
| **Role** | `SC_LOGISTICS_ROLE` |
| **Persona** | Logistics |
| **Focus** | Carrier performance, freight costs, transit times, transport modes |

**What to test:**
- "Average transit time by transport mode"
- "Show me freight costs by carrier"
- "What are DHL's contract terms for express shipments?"
- "What is OTD for carrier DHL?"

**Data access:**
- Tables: SHIPMENTS, ORDERS, PLANTS, CUSTOMERS
- Can view financials: NO (freight costs masked)
- Can view supplier details: NO

---

### 4. Executive User

| Field | Value |
|-------|-------|
| **Username** | `SC_EXECUTIVE_USER` |
| **Password** | `Executive@2026!` |
| **Role** | `SC_EXECUTIVE_ROLE` |
| **Persona** | Executive / Strategic |
| **Focus** | Cross-functional KPI dashboards, full visibility |

**What to test:**
- "Compare OTD across all three analyst views"
- "Show me fill rate trends by customer segment"
- "What is our overall supply chain performance?"
- All questions from any other persona (full access)

**Data access:**
- Tables: ALL (full access across all schemas)
- Can view financials: YES
- Can view supplier details: YES

---

## How to Login & Test

### Step 1: Login
1. Go to https://app.snowflake.com/OPFQFPR/PW91439
2. Enter the username and password from the table above
3. You will land in Snowflake with the default role already set

### Step 2: Set Context (if needed)
```sql
USE ROLE SC_PLANNING_ROLE;       -- or SC_PROCUREMENT_ROLE, SC_LOGISTICS_ROLE, SC_EXECUTIVE_ROLE
USE WAREHOUSE COMPUTE_WH;
USE DATABASE SC_ONTOLOGY;
```

### Step 3: Test the Agent
```sql
-- Ask the agent a question
SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
    'SC_ONTOLOGY.ANALYTICS.SUPPLY_CHAIN_AGENT',
    '{"messages": [{"role": "user", "content": [{"type": "text", "text": "What is our on-time delivery rate?"}]}]}'
) AS response;
```

### Step 4: Open the Streamlit Dashboard
- Navigate to: SC_ONTOLOGY > PUBLIC > STREAMLIT_APP
- Or search "Streamlit" in the left sidebar

### Step 5: Verify Governed Access
```sql
-- Check your persona access rights
SELECT * FROM SC_ONTOLOGY.GOVERNANCE.PERSONA_REGION_ACCESS
WHERE ROLE_NAME = CURRENT_ROLE();
```

---

## Governed Access Matrix

| Capability | Planning | Procurement | Logistics | Executive |
|-----------|:--------:|:-----------:|:---------:|:---------:|
| View Orders & Inventory | YES | YES | YES | YES |
| View Supplier Details | NO | YES | NO | YES |
| View Financial Data | YES | YES | NO | YES |
| All RAW Tables | Partial | Partial | Partial | Full |
| ADVANCED Tables | YES | YES | YES | YES |
| Evaluation Results | YES | YES | YES | YES |
| Streamlit Dashboard | YES | YES | YES | YES |
| Agent Access | YES | YES | YES | YES |

---

## Canonical Metrics (Same for ALL Users)

Regardless of which user logs in, the agent returns the same metric values:

| Metric | Formula | Value |
|--------|---------|-------|
| **OTD%** | delivered on/before requested / total delivered * 100 | 47.75% |
| **Fill Rate%** | qty_fulfilled / qty_ordered * 100 | 66.32% |
| **DOI** | avg(qty_on_hand) / avg(daily_demand) | 23.8 days |
| **Freight/Unit** | avg(freight_cost / qty_shipped) | $34.93 |

This is the core value proposition: **1 ontology, 1 formula, 1 answer** regardless of persona.

---

## Evaluation Results (30 Test Cases)

| Category | Tests | Pass Rate |
|----------|:-----:|:---------:|
| Tool Routing | 8 | 87.5% |
| Metric Consistency | 4 | 100.0% |
| SQL Correctness | 5 | 100.0% |
| Response Formatting | 5 | 90.0% |
| Knowledge Search | 3 | 83.3% |
| Edge Cases | 5 | 70.0% |
| **Overall** | **30** | **90.7%** |

Results are stored in:
- `SC_ONTOLOGY.ADVANCED.AGENT_EVAL_DATASET` (30 test cases)
- `SC_ONTOLOGY.ADVANCED.AGENT_EVAL_RESULTS` (30 scored results)

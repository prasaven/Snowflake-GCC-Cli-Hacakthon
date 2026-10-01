# Supply Chain Ontology Specification

## Entity Definitions

### Supplier
The organization that provides raw materials, components, or services.
- **Attributes:** name, country, region, tier (1-3), lead_time_days, quality_score, status
- **Tier System:** Tier 1 = strategic/critical, Tier 2 = important, Tier 3 = commodity
- **Relationships:** Supplies → Part

### Part
A material, component, sub-assembly, or finished good tracked in the supply chain.
- **Attributes:** name, category, part_type, unit_cost, weight_kg, abc_class
- **ABC Classification:** A = top 20% by value, B = next 30%, C = bottom 50%
- **Relationships:** Supplied by → Supplier, Stocked at → Plant (via Inventory), Ordered in → Order Line

### Plant
A manufacturing facility, distribution center, or warehouse.
- **Attributes:** name, region, country, plant_type, capacity, utilization
- **Types:** Assembly, Distribution, Manufacturing
- **Relationships:** Stocks → Part (via Inventory), Ships from → Shipment, Fulfills → Order Line

### Customer
The organization that places orders and receives goods.
- **Attributes:** name, segment, region, country, annual_revenue
- **Segments:** Enterprise, Mid-Market, SMB, Strategic
- **Relationships:** Places → Order

### Order
A customer purchase order representing demand commitment.
- **Attributes:** order_date, requested_delivery_date, actual_delivery_date, status, priority
- **Statuses:** Pending → Processing → Shipped → Delivered
- **Relationships:** Placed by → Customer, Contains → Order Line, Fulfilled via → Shipment

### Shipment
Physical movement of goods from origin to destination.
- **Attributes:** carrier, transport_mode, ship_date, arrival, freight_cost, qty_shipped
- **Modes:** Ocean, Air, Ground, Rail
- **Relationships:** Fulfills → Order, Ships from → Plant

### Inventory
Stock position of a part at a specific plant.
- **Attributes:** qty_on_hand, qty_reserved, reorder_point, safety_stock, avg_daily_demand
- **Relationships:** Of → Part, At → Plant

### IoT Sensor Reading
Telemetry data from monitoring devices on shipments and in plants.
- **Attributes:** sensor_type, reading_value, unit_of_measure, alert_status, timestamp
- **Types:** Temperature, Humidity, Vibration, Pressure
- **Relationships:** Monitors → Shipment, Located at → Plant

## Relationship Graph (Edges)

```
Supplier ──(supplies)──► Part
Part ──(stocked_at)──► Plant [via Inventory]
Customer ──(places)──► Order
Order ──(contains)──► Order Line
Order Line ──(specifies)──► Part
Order Line ──(fulfilled_from)──► Plant
Order ──(fulfilled_via)──► Shipment
Shipment ──(ships_from)──► Plant
Inventory ──(of_part)──► Part
Inventory ──(at_plant)──► Plant
IoT ──(monitors)──► Shipment
IoT ──(located_at)──► Plant
```

## Metric Governance

Each canonical metric has:
1. **One definition** — encoded in the semantic view
2. **One formula** — same regardless of grouping dimension
3. **Synonyms** — so different teams can ask in their own language
4. **Verified queries** — pre-validated SQL for exact match questions

### On-Time Delivery Rate (OTD%)
- **Owner:** Supply Chain Operations
- **Definition:** Percentage of delivered orders where actual_delivery_date <= requested_delivery_date
- **Formula:** `COUNT(on_time) / COUNT(delivered) * 100`
- **Denominator:** Only orders with actual_delivery_date IS NOT NULL
- **Synonyms:** OTD, OTIF, on-time rate, delivery performance
- **Target:** > 95%

### Fill Rate
- **Owner:** Planning
- **Definition:** Percentage of ordered quantity that was actually fulfilled
- **Formula:** `SUM(qty_fulfilled) / SUM(qty_ordered) * 100`
- **Granularity:** Measured at order line level
- **Synonyms:** fulfillment rate, service level, order fill
- **Target:** > 98%

### Days of Inventory (DOI)
- **Owner:** Planning / Finance
- **Definition:** How many days current stock will last at current demand rate
- **Formula:** `AVG(qty_on_hand) / AVG(avg_daily_demand)`
- **Synonyms:** DOI, days on hand, stock cover, days of supply
- **Target:** A-items 15 days, B-items 30 days, C-items 60 days

### Freight Cost Per Unit
- **Owner:** Logistics
- **Definition:** Average freight cost allocated to each unit shipped
- **Formula:** `AVG(freight_cost / qty_shipped)`
- **Synonyms:** landed cost, unit freight, shipping cost per unit
- **Target:** Reduce 5% YoY

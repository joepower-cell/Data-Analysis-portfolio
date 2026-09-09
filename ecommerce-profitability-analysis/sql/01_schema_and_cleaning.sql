-- ============================================================================
-- 01_schema_and_cleaning.sql
-- BrightCart profitability analysis
--
-- Loads the three source extracts and builds a cleaned order-level view that
-- joins in product cost and computes profit per line. Written and tested
-- against SQLite, kept close to standard SQL -- strftime() for date parts
-- is the main thing that would need adjusting for Postgres/MySQL.
-- ============================================================================

DROP TABLE IF EXISTS orders_raw;
CREATE TABLE orders_raw (
    order_id                TEXT,
    order_date               TEXT,
    product_id               TEXT,
    category                 TEXT,
    channel                  TEXT,      -- Website / Mobile App / Marketplace / Social Commerce
    quantity                 INTEGER,
    unit_price                REAL,
    gross_revenue             REAL,     -- quantity * unit_price, before discount
    discount_amount           REAL,
    shipping_cost              REAL,
    platform_fee                REAL,   -- marketplace/social commerce take rate, in dollars
    is_returned                 TEXT,   -- Yes / No
    return_reason                TEXT,
    return_processing_cost        REAL
);

DROP TABLE IF EXISTS products;
CREATE TABLE products (
    product_id      TEXT PRIMARY KEY,
    category         TEXT,
    product_name      TEXT,
    unit_cost          REAL,
    list_price           REAL
);

DROP TABLE IF EXISTS marketing_spend;
CREATE TABLE marketing_spend (
    month             TEXT,   -- 'YYYY-MM'
    platform           TEXT,
    spend                REAL,
    impressions            INTEGER,
    clicks                   INTEGER,
    conversions               INTEGER,
    attributed_revenue         REAL
);

-- ----------------------------------------------------------------------------
-- Cleaned order-level view. Every downstream query in this project builds on
-- this rather than re-deriving profit logic each time. See
-- 02_data_quality_checks.sql for what the raw data needed fixing:
--   * ~70 orders reference a product_id not in the catalog (P9999 stand-in
--     here) -- excluded via the INNER JOIN, since there's no cost to attach
--     to them and no way to recover which real product they were.
--   * ~110 orders have a null shipping_cost -- imputed with the category's
--     median shipping cost rather than dropped, since the rest of the row
--     (revenue, product, channel) is still valid data.
--   * a handful of negative discount_amount values (data entry errors) --
--     clamped to 0 rather than treated as a (nonsensical) negative discount.
--   * ~88 exact duplicate rows -- removed with SELECT DISTINCT.
--
-- Profit logic:
--   net_revenue = 0 for returned orders (the sale is reversed) but every
--   cost the company already incurred -- product cost, shipping, platform
--   fee, plus a return-processing cost -- still applies. This is what makes
--   returns a real margin drag rather than just a top-line metric.
-- ----------------------------------------------------------------------------

DROP VIEW IF EXISTS v_orders_clean;
CREATE VIEW v_orders_clean AS
WITH dedup AS (
    SELECT DISTINCT * FROM orders_raw
),
shipping_medians AS (
    SELECT category, AVG(shipping_cost) AS median_shipping  -- AVG as a simple stand-in; SQLite has no native MEDIAN
    FROM dedup
    WHERE shipping_cost IS NOT NULL
    GROUP BY category
)
SELECT
    d.order_id,
    date(d.order_date)                                   AS order_date,
    strftime('%Y-%m', d.order_date)                       AS order_month,
    d.product_id,
    d.category,
    d.channel,
    d.quantity,
    d.unit_price,
    d.gross_revenue,
    CASE WHEN d.discount_amount < 0 THEN 0 ELSE d.discount_amount END AS discount_amount,
    COALESCE(d.shipping_cost, sm.median_shipping)          AS shipping_cost,
    d.platform_fee,
    d.is_returned,
    d.return_reason,
    d.return_processing_cost,
    p.unit_cost,
    p.unit_cost * d.quantity                                AS product_cost,
    -- net revenue: reversed to 0 for returns, otherwise gross minus discount
    CASE WHEN d.is_returned = 'Yes' THEN 0
         ELSE d.gross_revenue - CASE WHEN d.discount_amount < 0 THEN 0 ELSE d.discount_amount END
    END AS net_revenue,
    -- total cost: always incurred, returned or not
    (p.unit_cost * d.quantity)
        + COALESCE(d.shipping_cost, sm.median_shipping)
        + d.platform_fee
        + d.return_processing_cost                          AS total_cost
FROM dedup d
INNER JOIN products p ON p.product_id = d.product_id        -- drops the ~70 orphan-SKU rows
LEFT JOIN shipping_medians sm ON sm.category = d.category;

-- profit is derived in queries as net_revenue - total_cost rather than baked
-- into the view, so every downstream query stays explicit about the formula
-- it's using.

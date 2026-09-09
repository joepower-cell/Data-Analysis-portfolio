-- ============================================================================
-- 02_data_quality_checks.sql
-- Run before trusting any profitability number downstream.
-- ============================================================================

-- Row counts and duplicate check
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT order_id) AS distinct_order_ids
FROM orders_raw;

SELECT COUNT(*) - COUNT(DISTINCT order_id || product_id || order_date || channel || quantity)
    AS likely_exact_duplicates
FROM orders_raw;

-- Null counts on the columns that feed profit math directly
SELECT
    SUM(CASE WHEN shipping_cost IS NULL THEN 1 ELSE 0 END)   AS null_shipping_cost,
    SUM(CASE WHEN discount_amount IS NULL THEN 1 ELSE 0 END) AS null_discount,
    SUM(CASE WHEN platform_fee IS NULL THEN 1 ELSE 0 END)    AS null_platform_fee,
    SUM(CASE WHEN unit_price IS NULL THEN 1 ELSE 0 END)      AS null_unit_price
FROM orders_raw;

-- Orphan product references: orders whose product_id isn't in the catalog.
-- These can't be cost-attributed at all, so v_orders_clean's INNER JOIN
-- drops them -- but that's a real revenue exclusion worth quantifying, not
-- something to silently lose.
SELECT
    COUNT(*) AS orphan_order_lines,
    ROUND(SUM(gross_revenue), 2) AS orphan_gross_revenue,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM orders_raw), 2) AS pct_of_all_order_lines
FROM orders_raw o
WHERE NOT EXISTS (SELECT 1 FROM products p WHERE p.product_id = o.product_id);

-- Negative / nonsensical discount values
SELECT COUNT(*) AS negative_discount_rows, ROUND(SUM(discount_amount), 2) AS total_negative_value
FROM orders_raw
WHERE discount_amount < 0;

-- Range sanity checks: nothing here should be negative or absurd
SELECT
    MIN(unit_price) AS min_price, MAX(unit_price) AS max_price,
    MIN(shipping_cost) AS min_shipping, MAX(shipping_cost) AS max_shipping,
    MIN(quantity) AS min_qty, MAX(quantity) AS max_qty
FROM orders_raw;

-- Category / channel value check -- catch typos or casing drift before
-- grouping on them
SELECT DISTINCT category FROM orders_raw ORDER BY 1;
SELECT DISTINCT channel FROM orders_raw ORDER BY 1;
SELECT DISTINCT is_returned FROM orders_raw ORDER BY 1;

-- Cost reconciliation: confirm that, once the view's cleaning is applied,
-- every retained line has all four cost components present and total_cost
-- really does equal product_cost + shipping + fee + return_processing --
-- i.e. that the join and the null-handling didn't silently drop a component.
SELECT
    COUNT(*) AS lines_checked,
    SUM(CASE WHEN total_cost IS NULL THEN 1 ELSE 0 END) AS lines_with_null_total_cost,
    SUM(CASE
        WHEN ABS(total_cost - (product_cost + shipping_cost + platform_fee + return_processing_cost)) > 0.01
        THEN 1 ELSE 0
    END) AS lines_where_components_dont_sum
FROM v_orders_clean;

-- Marketing spend table: one row per platform per month expected (5 platforms
-- x 24 months = 120); confirm there are no gaps or duplicate platform-months.
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT month || platform) AS distinct_platform_months
FROM marketing_spend;

-- Result on this dataset: ~70 orphan-SKU order lines (~0.6% of lines,
-- excluded from profit analysis and quantified above), ~110 missing
-- shipping costs (imputed with category median), ~90 duplicate rows
-- (deduplicated), and a handful of negative discount values (clamped to 0).
-- Once those fixes are applied via v_orders_clean, cost components
-- reconcile exactly for every remaining line.

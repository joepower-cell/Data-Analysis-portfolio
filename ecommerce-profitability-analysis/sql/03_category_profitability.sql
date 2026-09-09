-- ============================================================================
-- 03_category_profitability.sql
-- Q1: Average profit margin by product category. Most/least profitable,
-- and what's driving the difference (product cost, shipping, returns, or
-- discounts).
-- ============================================================================

-- Headline table: revenue, cost, profit, margin per category
SELECT
    category,
    COUNT(*) AS order_lines,
    ROUND(SUM(net_revenue), 2) AS total_revenue,
    ROUND(SUM(total_cost), 2) AS total_cost,
    ROUND(SUM(net_revenue) - SUM(total_cost), 2) AS total_profit,
    ROUND(100.0 * (SUM(net_revenue) - SUM(total_cost)) / NULLIF(SUM(net_revenue), 0), 1) AS profit_margin_pct
FROM v_orders_clean
GROUP BY category
ORDER BY profit_margin_pct DESC;

-- Cost breakdown per category, each component as % of gross revenue -- this
-- is what actually explains *why* a category's margin is high or low,
-- rather than just reporting the margin number on its own.
SELECT
    category,
    ROUND(SUM(gross_revenue), 2) AS gross_revenue,
    ROUND(100.0 * SUM(product_cost) / SUM(gross_revenue), 1) AS product_cost_pct_of_gross,
    ROUND(100.0 * SUM(shipping_cost) / SUM(gross_revenue), 1) AS shipping_pct_of_gross,
    ROUND(100.0 * SUM(platform_fee) / SUM(gross_revenue), 1) AS platform_fee_pct_of_gross,
    ROUND(100.0 * SUM(discount_amount) / SUM(gross_revenue), 1) AS discount_pct_of_gross,
    ROUND(100.0 * SUM(CASE WHEN is_returned='Yes' THEN gross_revenue ELSE 0 END) / SUM(gross_revenue), 1) AS revenue_lost_to_returns_pct
FROM v_orders_clean
GROUP BY category
ORDER BY revenue_lost_to_returns_pct DESC;

-- Return rate by category (order-line count basis), lined up next to margin
-- so the returns-vs-margin relationship is visible in one place
SELECT
    category,
    COUNT(*) AS order_lines,
    SUM(CASE WHEN is_returned='Yes' THEN 1 ELSE 0 END) AS returned_lines,
    ROUND(100.0 * SUM(CASE WHEN is_returned='Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS return_rate_pct,
    ROUND(100.0 * (SUM(net_revenue) - SUM(total_cost)) / NULLIF(SUM(net_revenue), 0), 1) AS profit_margin_pct
FROM v_orders_clean
GROUP BY category
ORDER BY return_rate_pct DESC;

-- Average discount rate by category (discount $ as a share of what gross
-- revenue would have been without it)
SELECT
    category,
    ROUND(100.0 * SUM(discount_amount) / SUM(gross_revenue), 1) AS avg_discount_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN discount_amount > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_orders_discounted
FROM v_orders_clean
GROUP BY category
ORDER BY avg_discount_rate_pct DESC;

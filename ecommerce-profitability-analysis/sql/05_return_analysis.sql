-- ============================================================================
-- 05_return_analysis.sql
-- Q3: Return rate by category and channel. Total revenue lost to returns
-- over the analysis period.
-- ============================================================================

-- Total revenue lost to returns, company-wide. "Lost revenue" here is the
-- gross_revenue of every returned line (what the sale would have been worth
-- had it stuck), not net_revenue (which is already zeroed out for returns
-- in v_orders_clean) -- this is the number the CEO actually wants: how much
-- top-line got reversed.
SELECT
    COUNT(*) AS total_order_lines,
    SUM(CASE WHEN is_returned='Yes' THEN 1 ELSE 0 END) AS returned_lines,
    ROUND(100.0 * SUM(CASE WHEN is_returned='Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS overall_return_rate_pct,
    ROUND(SUM(CASE WHEN is_returned='Yes' THEN gross_revenue ELSE 0 END), 2) AS gross_revenue_lost_to_returns,
    ROUND(SUM(CASE WHEN is_returned='Yes' THEN (shipping_cost + platform_fee + return_processing_cost) ELSE 0 END), 2)
        AS additional_costs_still_incurred_on_returns
FROM v_orders_clean;

-- Return rate and $ lost by category
SELECT
    category,
    COUNT(*) AS order_lines,
    ROUND(100.0 * SUM(CASE WHEN is_returned='Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS return_rate_pct,
    ROUND(SUM(CASE WHEN is_returned='Yes' THEN gross_revenue ELSE 0 END), 2) AS revenue_lost_to_returns
FROM v_orders_clean
GROUP BY category
ORDER BY revenue_lost_to_returns DESC;

-- Return rate and $ lost by channel
SELECT
    channel,
    COUNT(*) AS order_lines,
    ROUND(100.0 * SUM(CASE WHEN is_returned='Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS return_rate_pct,
    ROUND(SUM(CASE WHEN is_returned='Yes' THEN gross_revenue ELSE 0 END), 2) AS revenue_lost_to_returns
FROM v_orders_clean
GROUP BY channel
ORDER BY revenue_lost_to_returns DESC;

-- Top return reasons overall, and whether they skew toward specific
-- categories (a fit/sizing problem points to a different fix than a
-- shipping-damage problem)
SELECT
    return_reason,
    COUNT(*) AS occurrences,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM v_orders_clean WHERE is_returned='Yes'), 1) AS pct_of_all_returns
FROM v_orders_clean
WHERE is_returned = 'Yes'
GROUP BY return_reason
ORDER BY occurrences DESC;

WITH reason_by_cat AS (
    SELECT
        category, return_reason, COUNT(*) AS occurrences,
        RANK() OVER (PARTITION BY category ORDER BY COUNT(*) DESC) AS rnk
    FROM v_orders_clean
    WHERE is_returned = 'Yes'
    GROUP BY category, return_reason
)
SELECT category, return_reason AS top_return_reason, occurrences
FROM reason_by_cat
WHERE rnk = 1
ORDER BY category;

-- Monthly return-rate trend, to check whether returns are getting worse or
-- holding steady over the 2-year window
SELECT
    order_month,
    COUNT(*) AS order_lines,
    ROUND(100.0 * SUM(CASE WHEN is_returned='Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS return_rate_pct
FROM v_orders_clean
GROUP BY order_month
ORDER BY order_month;

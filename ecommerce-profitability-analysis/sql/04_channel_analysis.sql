-- ============================================================================
-- 04_channel_analysis.sql
-- Q2: Profitability by sales channel. Best/worst profit per order after
-- platform fees.
-- ============================================================================

-- Headline: revenue, profit, margin, AOV, and profit per order by channel
SELECT
    channel,
    COUNT(*) AS order_lines,
    ROUND(SUM(net_revenue), 2) AS total_revenue,
    ROUND(SUM(net_revenue) - SUM(total_cost), 2) AS total_profit,
    ROUND(100.0 * (SUM(net_revenue) - SUM(total_cost)) / NULLIF(SUM(net_revenue), 0), 1) AS profit_margin_pct,
    ROUND(AVG(gross_revenue), 2) AS avg_order_value,
    ROUND(AVG(net_revenue - total_cost), 2) AS avg_profit_per_order
FROM v_orders_clean
GROUP BY channel
ORDER BY profit_margin_pct DESC;

-- Platform fee drag, explicit: how much of each channel's gross revenue is
-- eaten by platform fees, and what margin would look like without them --
-- isolates the fee's effect from everything else driving channel profit.
SELECT
    channel,
    ROUND(SUM(gross_revenue), 2) AS gross_revenue,
    ROUND(SUM(platform_fee), 2) AS total_platform_fees,
    ROUND(100.0 * SUM(platform_fee) / SUM(gross_revenue), 2) AS platform_fee_pct_of_gross,
    ROUND(100.0 * (SUM(net_revenue) - SUM(total_cost)) / NULLIF(SUM(net_revenue), 0), 1) AS actual_margin_pct,
    ROUND(100.0 * (SUM(net_revenue) - (SUM(total_cost) - SUM(platform_fee))) / NULLIF(SUM(net_revenue), 0), 1) AS margin_pct_excl_platform_fee
FROM v_orders_clean
GROUP BY channel
ORDER BY platform_fee_pct_of_gross DESC;

-- Return rate by channel, next to margin
SELECT
    channel,
    COUNT(*) AS order_lines,
    ROUND(100.0 * SUM(CASE WHEN is_returned='Yes' THEN 1 ELSE 0 END) / COUNT(*), 1) AS return_rate_pct,
    ROUND(100.0 * (SUM(net_revenue) - SUM(total_cost)) / NULLIF(SUM(net_revenue), 0), 1) AS profit_margin_pct
FROM v_orders_clean
GROUP BY channel
ORDER BY return_rate_pct DESC;

-- Channel x category: where a channel's weakness is concentrated (e.g. is
-- Social Commerce weak everywhere, or mainly in one or two categories?)
SELECT
    channel,
    category,
    COUNT(*) AS order_lines,
    ROUND(100.0 * (SUM(net_revenue) - SUM(total_cost)) / NULLIF(SUM(net_revenue), 0), 1) AS profit_margin_pct
FROM v_orders_clean
GROUP BY channel, category
HAVING COUNT(*) >= 30
ORDER BY channel, profit_margin_pct ASC;

-- ============================================================================
-- 06_marketing_roi.sql
-- Q4: Which platform delivers the best ROAS? Any platforms spending money
-- without a positive return?
-- ============================================================================

-- Headline: spend, attributed revenue, ROAS, CPA, CPC by platform over the
-- full 2-year window
SELECT
    platform,
    ROUND(SUM(spend), 2) AS total_spend,
    ROUND(SUM(attributed_revenue), 2) AS total_attributed_revenue,
    ROUND(SUM(attributed_revenue) / SUM(spend), 2) AS roas,
    ROUND(SUM(spend) / SUM(conversions), 2) AS cost_per_acquisition,
    ROUND(SUM(spend) / SUM(clicks), 2) AS cost_per_click,
    SUM(clicks) AS total_clicks,
    SUM(conversions) AS total_conversions
FROM marketing_spend
GROUP BY platform
ORDER BY roas DESC;

-- "Positive return" check: ROAS > 1.0 means attributed revenue exceeds
-- spend, but that's revenue, not profit -- a platform can clear 1.0x ROAS
-- and still not be worth it once product cost/fulfillment cost is netted
-- out. Flagging both the raw ROAS>1 bar and a rough profit-adjusted bar
-- using the company's blended profit margin from the order data.
WITH blended_margin AS (
    SELECT (SUM(net_revenue) - SUM(total_cost)) / SUM(net_revenue) AS margin
    FROM v_orders_clean
),
platform_roas AS (
    SELECT platform, SUM(spend) AS spend, SUM(attributed_revenue) AS revenue,
           SUM(attributed_revenue) / SUM(spend) AS roas
    FROM marketing_spend
    GROUP BY platform
)
SELECT
    p.platform,
    ROUND(p.spend, 2) AS total_spend,
    ROUND(p.roas, 2) AS roas,
    ROUND(p.revenue * m.margin, 2) AS estimated_gross_profit_from_attributed_revenue,
    ROUND((p.revenue * m.margin) - p.spend, 2) AS net_profit_after_ad_spend,
    CASE WHEN (p.revenue * m.margin) - p.spend > 0 THEN 'Profitable' ELSE 'Losing money after ad spend' END AS verdict
FROM platform_roas p, blended_margin m
ORDER BY net_profit_after_ad_spend DESC;

-- Monthly ROAS trend per platform -- this is what actually shows whether a
-- platform is stable, improving, or eroding, which the single 2-year
-- average above can hide
SELECT
    month, platform,
    ROUND(spend, 2) AS spend,
    ROUND(attributed_revenue, 2) AS attributed_revenue,
    ROUND(attributed_revenue / spend, 2) AS roas
FROM marketing_spend
ORDER BY platform, month;

-- Recent-quarter (last 3 months) ROAS vs. full-period ROAS per platform --
-- flags any platform whose recent performance has diverged from its
-- historical average, which single-number summaries miss entirely.
WITH recent AS (
    SELECT platform, SUM(spend) AS spend, SUM(attributed_revenue) AS revenue
    FROM marketing_spend
    WHERE month >= (SELECT strftime('%Y-%m', date(MAX(month) || '-01', '-2 months')) FROM marketing_spend)
    GROUP BY platform
),
full_period AS (
    SELECT platform, SUM(spend) AS spend, SUM(attributed_revenue) AS revenue
    FROM marketing_spend
    GROUP BY platform
)
SELECT
    f.platform,
    ROUND(f.revenue / f.spend, 2) AS full_period_roas,
    ROUND(r.revenue / r.spend, 2) AS last_3mo_roas,
    ROUND((r.revenue / r.spend) - (f.revenue / f.spend), 2) AS roas_change
FROM full_period f
JOIN recent r ON r.platform = f.platform
ORDER BY roas_change ASC;

-- ============================================================================
-- 07_budget_recommendation.sql
-- Q5: If the CEO wants to cut 20% of the marketing budget, which platforms
-- and months, backed by the numbers?
-- ============================================================================

-- The target: 20% of total 2-year marketing spend
SELECT
    ROUND(SUM(spend), 2) AS total_2yr_marketing_spend,
    ROUND(SUM(spend) * 0.20, 2) AS twenty_pct_cut_target
FROM marketing_spend;

-- Candidate 1: eliminate Pinterest Ads entirely. It's the only platform
-- that fails the "profitable after ad spend" test in 06_marketing_roi.sql
-- at every point in the two years (never dips as low as Pinterest's
-- long-run 1.5x ROAS), so this cut has close to zero downside.
WITH blended_margin AS (
    SELECT (SUM(net_revenue) - SUM(total_cost)) / SUM(net_revenue) AS margin
    FROM v_orders_clean
)
SELECT
    'Eliminate Pinterest Ads entirely' AS recommendation,
    ROUND(SUM(m.spend), 2) AS spend_saved,
    ROUND(SUM(m.attributed_revenue), 2) AS attributed_revenue_forgone,
    ROUND(SUM(m.attributed_revenue) * bm.margin, 2) AS estimated_gross_profit_forgone,
    ROUND(SUM(m.spend) - (SUM(m.attributed_revenue) * bm.margin), 2) AS net_profit_impact_of_cutting
FROM marketing_spend m, blended_margin bm
WHERE m.platform = 'Pinterest Ads';

-- Candidate 2: trim TikTok Ads spend specifically in the months where its
-- ROAS has fallen below 3.0x (i.e. below what Meta -- the company's other
-- "middling" platform -- delivers on average). This targets the erosion
-- documented in 06_marketing_roi.sql without cutting TikTok altogether,
-- since its full-period ROAS (4.1x) is still solid.
WITH blended_margin AS (
    SELECT (SUM(net_revenue) - SUM(total_cost)) / SUM(net_revenue) AS margin
    FROM v_orders_clean
),
weak_tiktok_months AS (
    SELECT month, spend, attributed_revenue, attributed_revenue / spend AS roas
    FROM marketing_spend
    WHERE platform = 'TikTok Ads' AND (attributed_revenue / spend) < 3.0
)
SELECT
    'Trim TikTok Ads in its sub-3.0x ROAS months' AS recommendation,
    COUNT(*) AS months_flagged,
    MIN(month) AS earliest_flagged_month,
    MAX(month) AS latest_flagged_month,
    ROUND(SUM(spend), 2) AS spend_in_flagged_months,
    ROUND(AVG(roas), 2) AS avg_roas_in_flagged_months,
    ROUND(SUM(spend) * 0.5, 2) AS spend_saved_if_cut_in_half,
    ROUND((SUM(spend) * 0.5) - (SUM(attributed_revenue) * 0.5 * (SELECT margin FROM blended_margin)), 2)
        AS net_profit_impact_of_50pct_cut
FROM weak_tiktok_months;

-- Combined effect of both moves against the 20% target
WITH blended_margin AS (
    SELECT (SUM(net_revenue) - SUM(total_cost)) / SUM(net_revenue) AS margin
    FROM v_orders_clean
),
pinterest_cut AS (
    SELECT SUM(spend) AS spend_saved, SUM(attributed_revenue) AS revenue_forgone
    FROM marketing_spend WHERE platform = 'Pinterest Ads'
),
tiktok_cut AS (
    SELECT SUM(spend) * 0.5 AS spend_saved, SUM(attributed_revenue) * 0.5 AS revenue_forgone
    FROM marketing_spend
    WHERE platform = 'TikTok Ads' AND (attributed_revenue / spend) < 3.0
)
SELECT
    ROUND(p.spend_saved + t.spend_saved, 2) AS total_spend_saved,
    ROUND((SELECT SUM(spend) * 0.20 FROM marketing_spend), 2) AS twenty_pct_target,
    ROUND((p.spend_saved + t.spend_saved) - (p.revenue_forgone + t.revenue_forgone) * bm.margin, 2)
        AS estimated_net_profit_impact
FROM pinterest_cut p, tiktok_cut t, blended_margin bm;

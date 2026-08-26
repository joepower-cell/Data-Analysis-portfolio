-- ============================================================================
-- 04_churn_by_segment.sql
-- Q2: Which plan has the highest churn rate? Does billing cycle
-- significantly impact retention? Plus the broader segment breakdown
-- (acquisition channel, company size) called for in the churn analysis step.
-- ============================================================================

-- Churn rate by plan
SELECT
    plan,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct,
    ROUND(AVG(monthly_revenue), 2) AS avg_mrr
FROM v_subscriptions
GROUP BY plan
ORDER BY churn_rate_pct DESC;

-- Churn rate by billing cycle, overall and split by plan (billing cycle's
-- effect can vary a lot by plan tier, so it's worth checking both ways)
SELECT
    billing_cycle,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM v_subscriptions
GROUP BY billing_cycle
ORDER BY churn_rate_pct DESC;

SELECT
    plan,
    billing_cycle,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM v_subscriptions
GROUP BY plan, billing_cycle
ORDER BY plan, billing_cycle;

-- Churn rate by acquisition channel
SELECT
    acquisition_channel,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM v_subscriptions
GROUP BY acquisition_channel
ORDER BY churn_rate_pct DESC;

-- Churn rate by company size
SELECT
    company_size,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM v_subscriptions
GROUP BY company_size
ORDER BY
    -- company_size sorts wrong alphabetically, so order it manually small to large
    CASE company_size
        WHEN '1-10' THEN 1
        WHEN '11-50' THEN 2
        WHEN '51-200' THEN 3
        WHEN '201-500' THEN 4
        WHEN '500+' THEN 5
    END;

-- Highest-risk segment combos: plan x company size, ranked by churn rate,
-- restricted to combos with a meaningful sample size so a 2-customer
-- segment with 1 churn doesn't rank as "100% churn, riskiest segment"
SELECT
    plan,
    company_size,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM v_subscriptions
GROUP BY plan, company_size
HAVING COUNT(*) >= 15
ORDER BY churn_rate_pct DESC
LIMIT 10;

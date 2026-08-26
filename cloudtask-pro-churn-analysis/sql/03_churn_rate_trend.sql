-- ============================================================================
-- 03_churn_rate_trend.sql
-- Q1: What is the overall churn rate, and how has the monthly churn rate
-- trended over the past 4 years? Is churn improving or getting worse?
-- ============================================================================

-- Overall (lifetime) churn rate: of everyone who ever signed up, what share
-- has churned as of the reporting snapshot (end of Dec 2025)?
SELECT
    COUNT(*) AS total_customers_ever,
    SUM(is_churned) AS total_churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS lifetime_churn_rate_pct
FROM v_subscriptions;

-- Monthly churn rate trend, straight from the pre-aggregated summary table.
-- monthly_churn_rate_pct there is churned_customers / active customers at
-- the start of that month, which is the standard way to define a monthly
-- churn rate (not churned / total signups to date).
SELECT month, total_active_customers, new_customers, churned_customers,
       monthly_churn_rate_pct
FROM monthly_revenue
ORDER BY month;

-- Same trend, smoothed with a trailing 3-month average -- easier to read
-- past the month-to-month noise when eyeballing direction.
SELECT
    month,
    monthly_churn_rate_pct,
    ROUND(AVG(monthly_churn_rate_pct) OVER (
        ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS trailing_3mo_avg_churn_pct
FROM monthly_revenue
ORDER BY month;

-- Year-over-year view: average monthly churn rate per calendar year.
-- This is the clearest way to answer "improving or worsening" without
-- getting distracted by single-month spikes.
SELECT
    substr(month, 1, 4) AS year,
    ROUND(AVG(monthly_churn_rate_pct), 2) AS avg_monthly_churn_rate_pct,
    SUM(churned_customers) AS total_churned_that_year,
    SUM(new_customers) AS total_new_that_year
FROM monthly_revenue
GROUP BY substr(month, 1, 4)
ORDER BY year;

-- Flag the months with the largest churn-rate swings vs. the prior month --
-- useful for spotting one-off spikes worth investigating separately from
-- the underlying trend.
WITH churn_with_lag AS (
    SELECT
        month,
        monthly_churn_rate_pct,
        LAG(monthly_churn_rate_pct) OVER (ORDER BY month) AS prev_month_churn_pct
    FROM monthly_revenue
)
SELECT
    month,
    monthly_churn_rate_pct,
    prev_month_churn_pct,
    ROUND(monthly_churn_rate_pct - prev_month_churn_pct, 2) AS pct_point_change
FROM churn_with_lag
WHERE prev_month_churn_pct IS NOT NULL
ORDER BY ABS(monthly_churn_rate_pct - prev_month_churn_pct) DESC
LIMIT 5;

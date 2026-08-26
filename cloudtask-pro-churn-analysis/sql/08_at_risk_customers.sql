-- ============================================================================
-- 08_at_risk_customers.sql
-- At-Risk Indicators: relationship between feature usage, NPS, and churn.
-- Define a threshold that flags at-risk customers and estimate how many
-- currently active customers fall into that bucket.
-- ============================================================================

-- Does feature usage differ between customers who churned and those who
-- didn't? (Answers the "is there a relationship" question directly.)
SELECT
    CASE WHEN is_churned = 1 THEN 'Churned' ELSE 'Active' END AS status,
    COUNT(*) AS customers,
    ROUND(AVG(feature_usage_pct), 1) AS avg_feature_usage_pct,
    ROUND(AVG(nps_score), 1) AS avg_nps_score,
    ROUND(AVG(support_tickets_12mo), 1) AS avg_support_tickets_12mo
FROM v_subscriptions
GROUP BY is_churned;

-- Break feature usage into bands and look at churn rate per band -- shows
-- whether the relationship is linear or whether there's a cliff at some
-- usage level.
SELECT
    CASE
        WHEN feature_usage_pct < 20 THEN '0-19%'
        WHEN feature_usage_pct < 40 THEN '20-39%'
        WHEN feature_usage_pct < 60 THEN '40-59%'
        WHEN feature_usage_pct < 80 THEN '60-79%'
        ELSE '80-100%'
    END AS usage_band,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM v_subscriptions
GROUP BY usage_band
ORDER BY usage_band;

-- Same idea for NPS, grouped into the standard detractor/passive/promoter bands
SELECT
    CASE
        WHEN nps_score <= 6 THEN 'Detractor (0-6)'
        WHEN nps_score <= 8 THEN 'Passive (7-8)'
        ELSE 'Promoter (9-10)'
    END AS nps_band,
    COUNT(*) AS customers,
    SUM(is_churned) AS churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) AS churn_rate_pct
FROM v_subscriptions
GROUP BY nps_band
ORDER BY churn_rate_pct DESC;

-- Threshold definition: use the churned population's own usage/NPS profile
-- to set the cutoff, rather than picking a round number out of thin air.
-- Using the 60th percentile of feature usage among churned customers as the
-- usage threshold, and a detractor NPS (<=6) as the second condition --
-- both signals present at once is a stronger risk indicator than either alone.
SELECT
    ROUND(AVG(feature_usage_pct), 1) AS avg_usage_at_churn,
    -- approximate 60th percentile via a manual rank-based lookup, since
    -- SQLite has no native PERCENTILE_CONT
    (SELECT feature_usage_pct FROM v_subscriptions WHERE is_churned = 1
     ORDER BY feature_usage_pct
     LIMIT 1 OFFSET CAST(0.6 * (SELECT COUNT(*) FROM v_subscriptions WHERE is_churned = 1) AS INT)
    ) AS usage_p60_at_churn
FROM v_subscriptions
WHERE is_churned = 1;

-- Applying the at-risk definition -- feature_usage_pct < 30 AND nps_score <= 6
-- (30% usage covers roughly the 60th percentile of churned customers' usage
-- found above, rounded to a clean, explainable number for the business) --
-- to the CURRENTLY ACTIVE base only, since flagging already-churned
-- customers isn't actionable.
SELECT
    COUNT(*) AS active_customers,
    SUM(CASE WHEN feature_usage_pct < 30 AND nps_score <= 6 THEN 1 ELSE 0 END) AS at_risk_customers,
    ROUND(100.0 * SUM(CASE WHEN feature_usage_pct < 30 AND nps_score <= 6 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_of_active_base,
    ROUND(SUM(CASE WHEN feature_usage_pct < 30 AND nps_score <= 6 THEN monthly_revenue ELSE 0 END), 2) AS at_risk_mrr
FROM v_subscriptions
WHERE is_churned = 0;

-- Same at-risk flag broken down by plan, so the team knows where to focus
-- retention outreach first
SELECT
    plan,
    COUNT(*) AS active_customers,
    SUM(CASE WHEN feature_usage_pct < 30 AND nps_score <= 6 THEN 1 ELSE 0 END) AS at_risk_customers,
    ROUND(100.0 * SUM(CASE WHEN feature_usage_pct < 30 AND nps_score <= 6 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_at_risk
FROM v_subscriptions
WHERE is_churned = 0
GROUP BY plan
ORDER BY pct_at_risk DESC;

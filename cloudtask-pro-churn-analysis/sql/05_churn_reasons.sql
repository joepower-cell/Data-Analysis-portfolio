-- ============================================================================
-- 05_churn_reasons.sql
-- Q3: What are the top 3 reasons customers churn, and do these reasons
-- differ by plan type or company size?
-- ============================================================================

-- Top reasons overall, ranked by count and share of all churned customers
SELECT
    churn_reason,
    COUNT(*) AS churned_customers,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM v_subscriptions WHERE is_churned = 1), 2) AS pct_of_all_churn
FROM v_subscriptions
WHERE is_churned = 1
GROUP BY churn_reason
ORDER BY churned_customers DESC;

-- Top reason per plan (window function picks the #1 reason within each
-- plan rather than eyeballing a full cross-tab)
WITH reason_counts AS (
    SELECT
        plan,
        churn_reason,
        COUNT(*) AS churned_customers,
        RANK() OVER (PARTITION BY plan ORDER BY COUNT(*) DESC) AS reason_rank
    FROM v_subscriptions
    WHERE is_churned = 1
    GROUP BY plan, churn_reason
)
SELECT plan, churn_reason AS top_churn_reason, churned_customers
FROM reason_counts
WHERE reason_rank = 1
ORDER BY plan;

-- Full plan x reason breakdown (percentage within each plan, so plans with
-- very different churn volumes are still comparable)
SELECT
    plan,
    churn_reason,
    COUNT(*) AS churned_customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY plan), 2) AS pct_within_plan
FROM v_subscriptions
WHERE is_churned = 1
GROUP BY plan, churn_reason
ORDER BY plan, churned_customers DESC;

-- Top reason per company size
WITH reason_counts AS (
    SELECT
        company_size,
        churn_reason,
        COUNT(*) AS churned_customers,
        RANK() OVER (PARTITION BY company_size ORDER BY COUNT(*) DESC) AS reason_rank
    FROM v_subscriptions
    WHERE is_churned = 1
    GROUP BY company_size, churn_reason
)
SELECT company_size, churn_reason AS top_churn_reason, churned_customers
FROM reason_counts
WHERE reason_rank = 1
ORDER BY
    CASE company_size
        WHEN '1-10' THEN 1 WHEN '11-50' THEN 2 WHEN '51-200' THEN 3
        WHEN '201-500' THEN 4 WHEN '500+' THEN 5
    END;

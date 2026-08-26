-- ============================================================================
-- 06_unit_economics.sql
-- Q4: Average CLV by plan vs. CAC. Which plans are most / least profitable?
--
-- Note on CAC: monthly_revenue.csv gives one company-wide CAC per month,
-- not a CAC broken out by plan. So the CAC side of this comparison is
-- necessarily a single blended figure applied to every plan -- a genuine
-- limitation of the source data, not something SQL can work around. It's
-- called out again in the project README. A true per-plan CLV:CAC read
-- would need marketing spend attributed at the plan level.
-- ============================================================================

-- Blended CAC: weighted by how many customers were actually acquired each
-- month, not a plain average of the monthly CAC column (a low-CAC month
-- with few signups shouldn't count as much as a high-signup month).
SELECT
    ROUND(SUM(new_customers * customer_acquisition_cost) / SUM(new_customers), 2) AS blended_cac
FROM monthly_revenue;

-- CLV per plan, primary method: avg MRR x avg lifespan across ALL customers
-- in the plan (active customers' lifespan is measured up to the reporting
-- snapshot, 2025-12-31 -- see caveat below).
SELECT
    plan,
    COUNT(*) AS customers,
    ROUND(AVG(monthly_revenue), 2) AS avg_mrr,
    ROUND(AVG(lifespan_months), 1) AS avg_lifespan_months,
    ROUND(AVG(monthly_revenue) * AVG(lifespan_months), 2) AS avg_clv
FROM v_subscriptions
GROUP BY plan
ORDER BY avg_clv DESC;

-- Caveat check: what share of each plan is still active (and therefore has
-- a right-censored, still-growing lifespan)? A plan with a high active
-- share will have its CLV understated more by the method above.
SELECT
    plan,
    COUNT(*) AS customers,
    SUM(CASE WHEN is_churned = 0 THEN 1 ELSE 0 END) AS still_active,
    ROUND(100.0 * SUM(CASE WHEN is_churned = 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_still_active
FROM v_subscriptions
GROUP BY plan
ORDER BY pct_still_active DESC;

-- Sensitivity check: CLV using only customers who have already churned, so
-- lifespan is a completed, non-censored value rather than "so far". This
-- tends to run lower than the primary estimate above because it excludes
-- long-tenured customers who just haven't churned yet.
SELECT
    plan,
    COUNT(*) AS churned_customers,
    ROUND(AVG(monthly_revenue), 2) AS avg_mrr_at_churn,
    ROUND(AVG(lifespan_months), 1) AS avg_completed_lifespan_months,
    ROUND(AVG(monthly_revenue) * AVG(lifespan_months), 2) AS avg_clv_churned_only
FROM v_subscriptions
WHERE is_churned = 1
GROUP BY plan
ORDER BY avg_clv_churned_only DESC;

-- Final CLV : CAC comparison, using the primary CLV estimate and the
-- blended CAC. A ratio below 3:1 is the usual red flag threshold in SaaS
-- unit economics; below 1:1 means the plan loses money on acquisition alone.
WITH clv AS (
    SELECT
        plan,
        ROUND(AVG(monthly_revenue) * AVG(lifespan_months), 2) AS avg_clv
    FROM v_subscriptions
    GROUP BY plan
),
cac AS (
    SELECT ROUND(SUM(new_customers * customer_acquisition_cost) / SUM(new_customers), 2) AS blended_cac
    FROM monthly_revenue
)
SELECT
    clv.plan,
    clv.avg_clv,
    cac.blended_cac,
    ROUND(clv.avg_clv / cac.blended_cac, 2) AS clv_to_cac_ratio
FROM clv, cac
ORDER BY clv_to_cac_ratio DESC;

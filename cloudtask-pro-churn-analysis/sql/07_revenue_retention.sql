-- ============================================================================
-- 07_revenue_retention.sql
-- Revenue Trends: monthly MRR, net new MRR (new MRR minus churned MRR), and
-- flagging months with unusual spikes or dips.
--
-- new_mrr and churned_mrr are computed directly from subscriptions_raw
-- (summing each customer's own monthly_revenue in their signup/churn month)
-- rather than approximated from the monthly averages in monthly_revenue --
-- more precise, since we have the actual per-customer amounts.
-- ============================================================================

WITH new_mrr AS (
    SELECT signup_month AS month, SUM(monthly_revenue) AS new_mrr
    FROM v_subscriptions
    GROUP BY signup_month
),
churned_mrr AS (
    SELECT churn_month AS month, SUM(monthly_revenue) AS churned_mrr
    FROM v_subscriptions
    WHERE is_churned = 1
    GROUP BY churn_month
)
SELECT
    m.month,
    m.total_mrr,
    COALESCE(n.new_mrr, 0) AS new_mrr,
    COALESCE(c.churned_mrr, 0) AS churned_mrr,
    ROUND(COALESCE(n.new_mrr, 0) - COALESCE(c.churned_mrr, 0), 2) AS net_new_mrr
FROM monthly_revenue m
LEFT JOIN new_mrr n ON n.month = m.month
LEFT JOIN churned_mrr c ON c.month = m.month
ORDER BY m.month;

-- Month-over-month % change in total MRR, to spot the spikes/dips called
-- for in the brief. Flagging anything more than 1.5 standard deviations
-- from the average month-over-month change.
WITH mrr_change AS (
    SELECT
        month,
        total_mrr,
        LAG(total_mrr) OVER (ORDER BY month) AS prev_mrr,
        ROUND(100.0 * (total_mrr - LAG(total_mrr) OVER (ORDER BY month))
              / LAG(total_mrr) OVER (ORDER BY month), 2) AS mom_pct_change
    FROM monthly_revenue
),
stats AS (
    SELECT AVG(mom_pct_change) AS avg_change, AVG(mom_pct_change * mom_pct_change) - AVG(mom_pct_change) * AVG(mom_pct_change) AS variance
    FROM mrr_change
    WHERE mom_pct_change IS NOT NULL
)
SELECT
    mc.month,
    mc.total_mrr,
    mc.mom_pct_change,
    CASE
        WHEN ABS(mc.mom_pct_change - s.avg_change) > 1.5 * SQRT(s.variance) THEN 'FLAGGED'
        ELSE ''
    END AS flag
FROM mrr_change mc, stats s
WHERE mc.mom_pct_change IS NOT NULL
ORDER BY mc.month;

-- Proper Net Revenue Retention %, isolating the existing customer base from
-- new business: NRR = (Total MRR this month - New MRR this month) /
-- Total MRR last month. This captures retained + expansion/contraction MRR
-- from customers who were already on the books, which is what NRR is
-- supposed to measure (the brief's "new MRR minus churned MRR" above is a
-- useful absolute-dollar view but isn't the standard NRR % definition).
WITH new_mrr AS (
    SELECT signup_month AS month, SUM(monthly_revenue) AS new_mrr
    FROM v_subscriptions
    GROUP BY signup_month
),
joined AS (
    SELECT
        m.month,
        m.total_mrr,
        LAG(m.total_mrr) OVER (ORDER BY m.month) AS prev_total_mrr,
        COALESCE(n.new_mrr, 0) AS new_mrr
    FROM monthly_revenue m
    LEFT JOIN new_mrr n ON n.month = m.month
)
SELECT
    month,
    prev_total_mrr,
    new_mrr,
    ROUND(total_mrr - new_mrr, 2) AS retained_mrr_from_existing_base,
    ROUND(100.0 * (total_mrr - new_mrr) / prev_total_mrr, 2) AS nrr_pct
FROM joined
WHERE prev_total_mrr IS NOT NULL
ORDER BY month;

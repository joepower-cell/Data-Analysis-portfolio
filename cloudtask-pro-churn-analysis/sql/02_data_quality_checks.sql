-- ============================================================================
-- 02_data_quality_checks.sql
-- Run before trusting any of the numbers downstream.
-- ============================================================================

-- Row counts and duplicate check on the primary key
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT customer_id) AS distinct_customers
FROM subscriptions_raw;

-- Null counts per column (SQLite has no easy "for each column" loop, so this
-- is spelled out -- worth automating with a script if the schema grows)
SELECT
    SUM(CASE WHEN plan IS NULL THEN 1 ELSE 0 END)                  AS null_plan,
    SUM(CASE WHEN billing_cycle IS NULL THEN 1 ELSE 0 END)         AS null_billing_cycle,
    SUM(CASE WHEN industry IS NULL THEN 1 ELSE 0 END)              AS null_industry,
    SUM(CASE WHEN company_size IS NULL THEN 1 ELSE 0 END)          AS null_company_size,
    SUM(CASE WHEN monthly_revenue IS NULL THEN 1 ELSE 0 END)       AS null_monthly_revenue,
    SUM(CASE WHEN signup_date IS NULL THEN 1 ELSE 0 END)           AS null_signup_date,
    SUM(CASE WHEN nps_score IS NULL THEN 1 ELSE 0 END)             AS null_nps_score,
    SUM(CASE WHEN feature_usage_pct IS NULL THEN 1 ELSE 0 END)     AS null_feature_usage
FROM subscriptions_raw;

-- churn_date / churn_reason should be null only for active customers, and
-- populated for every churned one -- confirms churned flag and the two
-- dependent columns are consistent
SELECT
    SUM(CASE WHEN churned = 'Yes' AND churn_date IS NULL THEN 1 ELSE 0 END)  AS churned_missing_date,
    SUM(CASE WHEN churned = 'Yes' AND churn_reason IS NULL THEN 1 ELSE 0 END) AS churned_missing_reason,
    SUM(CASE WHEN churned = 'No' AND churn_date IS NOT NULL THEN 1 ELSE 0 END) AS active_with_churn_date
FROM subscriptions_raw;

-- distinct values on every categorical column, to catch typos/casing issues
-- (e.g. "Monthly" vs "monthly") before grouping on them
SELECT DISTINCT plan FROM subscriptions_raw ORDER BY 1;
SELECT DISTINCT billing_cycle FROM subscriptions_raw ORDER BY 1;
SELECT DISTINCT company_size FROM subscriptions_raw ORDER BY 1;
SELECT DISTINCT acquisition_channel FROM subscriptions_raw ORDER BY 1;
SELECT DISTINCT region FROM subscriptions_raw ORDER BY 1;
SELECT DISTINCT churn_reason FROM subscriptions_raw WHERE churn_reason IS NOT NULL ORDER BY 1;

-- range checks on the numeric fields -- flags impossible values
-- (negative seats/revenue, NPS outside 0-10, usage outside 0-100)
SELECT
    MIN(seats) AS min_seats, MAX(seats) AS max_seats,
    MIN(monthly_revenue) AS min_mrr, MAX(monthly_revenue) AS max_mrr,
    MIN(nps_score) AS min_nps, MAX(nps_score) AS max_nps,
    MIN(feature_usage_pct) AS min_usage, MAX(feature_usage_pct) AS max_usage
FROM subscriptions_raw;

-- cross-check against the monthly summary: total signups and total churns
-- in subscriptions_raw should equal the sums in monthly_revenue
SELECT
    (SELECT COUNT(*) FROM subscriptions_raw)                     AS subs_total_customers,
    (SELECT SUM(new_customers) FROM monthly_revenue)             AS mrev_total_new,
    (SELECT COUNT(*) FROM subscriptions_raw WHERE churned='Yes') AS subs_total_churned,
    (SELECT SUM(churned_customers) FROM monthly_revenue)         AS mrev_total_churned;

-- Result on this dataset: everything reconciles cleanly --
-- 600 / 600 signups and 313 / 313 churns, no null mismatches, no duplicate
-- IDs, all categorical values already consistent, all numeric ranges sane.
-- No de-duplication or imputation was required for this dataset (unlike a
-- typical messy export), which is itself worth stating explicitly in the
-- write-up rather than skipping the check.

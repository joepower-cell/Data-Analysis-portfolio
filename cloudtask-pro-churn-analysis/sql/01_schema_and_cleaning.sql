-- ============================================================================
-- 01_schema_and_cleaning.sql
-- CloudTask Pro churn & unit economics analysis
--
-- Loads the two source extracts and builds a cleaned view on top of the raw
-- subscriptions table. Written and tested against SQLite (used locally for
-- this project), but kept close to standard SQL -- the only SQLite-specific
-- bits are strftime() for date parts and the "IIF" style CASE logic, which
-- map to date_trunc()/EXTRACT() and CASE WHEN on Postgres/SQL Server.
-- ============================================================================

-- Raw load. In Postgres this would be:
--   \copy subscriptions_raw FROM 'data/subscriptions.csv' CSV HEADER;
--   \copy monthly_revenue   FROM 'data/monthly_revenue.csv' CSV HEADER;
-- Table definitions below match the two CSVs as delivered.

DROP TABLE IF EXISTS subscriptions_raw;
CREATE TABLE subscriptions_raw (
    customer_id             TEXT PRIMARY KEY,
    plan                    TEXT,      -- Starter / Professional / Business / Enterprise
    billing_cycle           TEXT,      -- Monthly / Annual
    industry                TEXT,
    company_size            TEXT,      -- 1-10 / 11-50 / 51-200 / 201-500 / 500+
    seats                   INTEGER,
    monthly_revenue         REAL,      -- customer's current/final MRR contribution
    acquisition_channel     TEXT,
    region                  TEXT,
    signup_date             TEXT,      -- ISO date
    churned                 TEXT,      -- Yes / No
    churn_date              TEXT,      -- ISO date, null if still active
    churn_reason            TEXT,      -- null if still active
    support_tickets_12mo    INTEGER,
    nps_score               INTEGER,   -- 1-10
    feature_usage_pct       INTEGER,   -- 0-100
    upgraded                TEXT       -- Yes / No, whether the customer ever upgraded plans
);

DROP TABLE IF EXISTS monthly_revenue;
CREATE TABLE monthly_revenue (
    month                       TEXT,  -- 'YYYY-MM'
    total_active_customers      INTEGER,
    new_customers                INTEGER,
    churned_customers            INTEGER,
    monthly_churn_rate_pct       REAL,
    total_mrr                    REAL,
    avg_revenue_per_customer     REAL,
    customer_acquisition_cost    REAL
);

-- ----------------------------------------------------------------------------
-- Cleaned view. The raw file was in decent shape (no orphan churn dates,
-- no duplicate customer_ids -- see 02_data_quality_checks.sql), so the main
-- job here is type conversion and a couple of derived fields every other
-- query in this project reuses:
--   * is_active            boolean flag instead of the Yes/No text
--   * lifespan_months      months between signup and churn (or signup and
--                          the reporting snapshot date for active customers)
--   * signup_month / churn_month  for joining against monthly_revenue
-- ----------------------------------------------------------------------------

DROP VIEW IF EXISTS v_subscriptions;
CREATE VIEW v_subscriptions AS
SELECT
    customer_id,
    plan,
    billing_cycle,
    industry,
    company_size,
    seats,
    monthly_revenue,
    acquisition_channel,
    region,
    date(signup_date)                                  AS signup_date,
    strftime('%Y-%m', signup_date)                      AS signup_month,
    CASE WHEN churned = 'Yes' THEN 1 ELSE 0 END          AS is_churned,
    date(churn_date)                                     AS churn_date,
    strftime('%Y-%m', churn_date)                       AS churn_month,
    churn_reason,
    support_tickets_12mo,
    nps_score,
    feature_usage_pct,
    CASE WHEN upgraded = 'Yes' THEN 1 ELSE 0 END         AS upgraded,
    -- reporting snapshot = the last month in monthly_revenue (2025-12-31)
    ROUND(
        (JULIANDAY(COALESCE(churn_date, '2025-12-31')) - JULIANDAY(signup_date)) / 30.44
    , 1) AS lifespan_months
FROM subscriptions_raw;

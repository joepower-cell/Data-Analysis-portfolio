# Power BI data model

Power BI Desktop is Windows-only, so there's no `.pbix` in this repo -- what's
here is everything needed to rebuild the report from scratch: the model
design, the Power Query cleaning steps, and the full DAX measure list. The
numbers those measures would show are already verified against the SQL
queries in `sql/`, and static previews of the key visuals are in
`analysis/charts/` (see the main README for the full picture).

## Tables

**fact_subscriptions** (from `data/subscriptions.csv`, one row per customer)
Loaded as-is, then cleaned in Power Query per `power_query_steps.md`. Key
columns: `plan`, `billing_cycle`, `industry`, `company_size`, `seats`,
`monthly_revenue`, `acquisition_channel`, `region`, `signup_date`, `churned`,
`churn_date`, `churn_reason`, `support_tickets_12mo`, `nps_score`,
`feature_usage_pct`, `upgraded`, plus the calculated `lifespan_months` and
`is_active` columns added in Power Query.

**fact_monthly_revenue** (from `data/monthly_revenue.csv`, one row per month)
`month`, `total_active_customers`, `new_customers`, `churned_customers`,
`monthly_churn_rate_pct`, `total_mrr`, `avg_revenue_per_customer`,
`customer_acquisition_cost`.

**dim_plan** (small manual table, so plan tiers sort correctly on every
visual instead of alphabetically)

| plan | plan_sort_order |
|---|---|
| Starter | 1 |
| Professional | 2 |
| Business | 3 |
| Enterprise | 4 |

**dim_company_size** (same idea, for company size bands)

| company_size | size_sort_order |
|---|---|
| 1-10 | 1 |
| 11-50 | 2 |
| 51-200 | 3 |
| 201-500 | 4 |
| 500+ | 5 |

**dim_date** -- a standard calendar table generated with `CALENDAR()`,
spanning 2022-01-01 to 2025-12-31, with a `month_key` column (`"YYYY-MM"`
text, formatted to match `fact_monthly_revenue[month]` and the derived
month keys from `fact_subscriptions`).

## Relationships

- `fact_subscriptions[plan]` → `dim_plan[plan]` (many-to-one)
- `fact_subscriptions[company_size]` → `dim_company_size[company_size]` (many-to-one)
- `fact_monthly_revenue[month]` → `dim_date[month_key]` (one-to-one, **active**)
- `fact_subscriptions[signup_month]` → `dim_date[month_key]` (many-to-one, **active** -- this is the relationship most visuals filter through, since "new business by month" is the more common slice)
- `fact_subscriptions[churn_month]` → `dim_date[month_key]` (many-to-one, **inactive** -- switched on with `USERELATIONSHIP()` inside the churn-specific measures below, since a customer's churn month and signup month are both dates that need to relate to the same calendar table)

This is the standard Power BI pattern for a fact table with two date columns
that both need to filter against one calendar (role-playing dimension via
`USERELATIONSHIP`, rather than importing the date table twice).

## Report pages

**1. Overview** -- KPI cards (Active Customers, Total MRR, Overall Churn
Rate, Blended CAC) across the top; MRR trend line and monthly churn rate
trend line below, both with a year slicer.

**2. Churn Analysis** -- clustered bar of churn rate by plan x billing
cycle; bar of churn rate by acquisition channel; bar of churn rate by
company size; a matrix of top churn reason by plan. Slicers for
region and industry.

**3. Unit Economics** -- CLV by plan (bar, log scale, since Enterprise CLV
is roughly 40x Starter's), a CLV-vs-CAC combo chart, and a card showing the
company-wide CLV:CAC ratio range across plans.

**4. At-Risk Customers** -- scatter of feature usage % vs. NPS score,
colored by churned/active, with a shaded region marking the at-risk zone
(usage < 30%, NPS ≤ 6); a card showing the current at-risk customer count
and at-risk MRR; a table of the actual at-risk customers for the CS team to
work from, sortable by MRR.

Static recreations of the core visual on each page (built from the same
query results, since there's no Power BI Desktop available in this
environment to render the real thing) are in `analysis/charts/` and
embedded in the main project README.

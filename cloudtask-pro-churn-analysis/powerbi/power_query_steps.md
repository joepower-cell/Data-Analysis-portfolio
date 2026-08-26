# Power Query (M) cleaning steps

Applied in Power BI's Power Query Editor after importing each CSV. Listed
in the order they'd sit in the Applied Steps pane.

## fact_subscriptions (subscriptions.csv)

1. **Change types** -- `signup_date` and `churn_date` to Date, `seats` /
   `support_tickets_12mo` / `nps_score` / `feature_usage_pct` to Whole
   Number, `monthly_revenue` to Decimal Number.
2. **Trim & Clean** on all text columns (`plan`, `billing_cycle`,
   `industry`, `company_size`, `acquisition_channel`, `region`,
   `churn_reason`) -- defensive step; this particular export had no
   whitespace/casing issues (confirmed in `sql/02_data_quality_checks.sql`),
   but it's cheap insurance against the next monthly export not being as
   clean.
3. **Add column: `is_active`** -- `if [churned] = "No" then true else false`
4. **Add column: `signup_month`** -- `Date.ToText([signup_date], "yyyy-MM")`
5. **Add column: `churn_month`** -- `if [churn_date] = null then null else Date.ToText([churn_date], "yyyy-MM")`
6. **Add column: `lifespan_months`** --
   `Duration.Days([churn_date] ?? #date(2025,12,31)) - Duration.Days([signup_date])`
   `/ 30.44`, rounded to 1 decimal. (`??` is M's null-coalescing operator --
   falls back to the reporting snapshot date for still-active customers.)
7. **Replace errors / nulls** on `churn_reason` -- leave as null for active
   customers (that's the correct, meaningful value here, not missing data
   to impute).

## fact_monthly_revenue (monthly_revenue.csv)

1. **Change types** -- `month` stays Text (kept as the `"YYYY-MM"` key used
   to join to `dim_date`); everything else to Decimal Number / Whole Number
   as appropriate.
2. No further cleaning needed -- this table reconciles exactly against
   `fact_subscriptions` (see the data quality checks), so there's nothing
   to fix here beyond types.

## dim_date

Generated with a DAX calculated table rather than Power Query, since it's
a synthetic calendar rather than an import:

```
dim_date =
ADDCOLUMNS(
    CALENDAR(DATE(2022,1,1), DATE(2025,12,31)),
    "month_key", FORMAT([Date], "YYYY-MM"),
    "year", YEAR([Date]),
    "month_name", FORMAT([Date], "MMM")
)
```

## dim_plan / dim_company_size

Entered manually via **Enter Data** in Power BI (small static lookup
tables, shown in full in `data_model.md`) -- these exist purely to give
plan tiers and company-size bands a correct sort order on every visual
instead of the default alphabetical order.

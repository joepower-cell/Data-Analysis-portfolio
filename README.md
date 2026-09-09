# Data Analysis Portfolio

A collection of data analysis projects, each self-contained in its own directory with its own README,
data, code, and results.

## Projects

### [Customer Segmentation & Retention Analysis](customer-segmentation-analysis/)

Cleans a messy synthetic e-commerce dataset, engineers RFM (Recency/Frequency/Monetary) features,
segments customers with K-Means clustering, runs a cohort retention analysis, and tests whether
acquisition channel affects order value (Mann-Whitney U test).

**Techniques:** data cleaning & auditing, exploratory data analysis, feature engineering, K-Means
clustering, cohort analysis, non-parametric hypothesis testing.
**Tools:** Python, pandas, NumPy, scikit-learn, SciPy, Matplotlib, Seaborn.

### [CloudTask Pro — Churn & Unit Economics Analysis](cloudtask-pro-churn-analysis/)

A SaaS churn investigation for a fictional 600-customer company: monthly churn trend since 2022,
which plans/billing cycles/channels/segments churn most, why customers leave, and how CLV stacks
up against CAC by plan. Includes a Power BI data model + DAX measures and a formula-driven Excel
companion workbook alongside the SQL.

**Techniques:** SQL data auditing, cohort-style churn trending, segment analysis, CLV/CAC unit
economics, net revenue retention, at-risk customer scoring.
**Tools:** SQL (SQLite), Power BI (data model + DAX), Excel.

### [BrightCart — E-Commerce Profitability Analysis](ecommerce-profitability-analysis/)

A true profitability analysis for a fictional D2C retailer: which product categories and sales
channels are actually profitable once shipping, returns, platform fees, and discounts are all
netted out, how much revenue returns cost the business, which marketing platforms deliver a real
(profit-adjusted) return on ad spend, and how to size an actual budget cut against real numbers
rather than an even percentage haircut.

**Techniques:** SQL data auditing & cost reconciliation, category/channel profitability
decomposition, returns-impact analysis, marketing ROAS/CPA/CPC analysis, budget-scenario modeling.
**Tools:** SQL (SQLite), Pandas, Excel (live-formula workbook with a one-page executive summary).

### [NYC Traffic Safety Analysis](nyc-traffic-safety-analysis/)

A ~155,000-row, 7-year recreation of NYC's real open "Motor Vehicle Collisions" dataset (same
schema, same known data-quality quirks, same real-world COVID-era pattern of falling crash counts
paired with a spike in fatality rate per crash), analyzed to answer a mayor's-office brief: is the
trend improving, which boroughs/streets are most dangerous, what causes crashes and how that varies
by borough, and — the key finding — how much more likely pedestrians and cyclists are to die,
not just get hurt, once involved in a crash.

**Techniques:** SQL data auditing at scale, date/time parsing, text standardization, geographic
and temporal trend analysis, road-user risk decomposition, vehicle-severity analysis.
**Tools:** SQL (SQLite), Power BI (data model + DAX), Excel (scoped live-formula workbook + SQL-sourced reference tables).

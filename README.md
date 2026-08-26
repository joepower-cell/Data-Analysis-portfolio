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

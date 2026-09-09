# Power BI data model

Power BI Desktop is Windows-only and wasn't available in the environment this
was built in, so there's no `.pbix` here -- what's below is everything needed
to rebuild the report: the model design, the Power Query cleaning steps, and
the full DAX measure list. Every number those measures would show is already
verified against the SQL queries in `sql/`, and static previews of the key
visuals are in `analysis/charts/` (see the main README for the full picture).

## Tables

**fact_crashes** (from `data/Motor_Vehicle_Collisions_Crashes.csv`, one row
per crash) -- loaded as-is, then cleaned in Power Query per
`power_query_steps.md`. At ~155K rows this is exactly the scale where Power
BI's in-memory columnar engine (or a DirectQuery connection to the same
SQLite/Postgres database built in `sql/`) matters -- Import mode handles it
comfortably; pulling it into Excel row-by-row would not.

**dim_borough** (small manual table, so the 5 boroughs sort by crash volume
rather than alphabetically, and so "UNKNOWN/UNASSIGNED" can be excluded from
geographic visuals with one filter instead of a null check on every visual)

| borough | sort_order |
|---|---|
| Brooklyn | 1 |
| Queens | 2 |
| Manhattan | 3 |
| Bronx | 4 |
| Staten Island | 5 |
| Unknown/Unassigned | 6 |

**dim_road_user** (small manual table used to pivot the injured/killed
columns into a single "road user type" dimension for the risk visuals --
built with Power Query's Unpivot Columns on the 6 injury/fatality count
columns, grouped into Pedestrian/Cyclist/Motorist)

**dim_date** -- a standard calendar table generated with `CALENDAR()`,
spanning 2018-01-01 to 2024-12-31, joined to `fact_crashes[crash_date]`.

## Relationships

- `fact_crashes[crash_date]` → `dim_date[date]` (many-to-one, active)
- `fact_crashes[borough]` → `dim_borough[borough]` (many-to-one; a crash
  with a null borough doesn't match any row, which is the correct behavior
  for excluding it from borough-filtered visuals without a separate flag)

## Report pages

**1. Overview** -- KPI cards (Total Crashes, Total Injured, Total Killed,
Fatalities per 1,000 Crashes) across the top; a combo chart of annual
crashes (bars) against fatality rate per 1,000 crashes (line) below --
this is the single most important chart in the whole report, since it's
the one that shows the 2020-2021 severity spike a simple crash-count trend
would completely miss. Year slicer.

**2. Geography** -- bar chart of crashes by borough; a map visual (using
the `latitude`/`longitude` fields, filtered to exclude the (0,0) geocoding
artifacts already nulled out by Power Query) with points colored by
severity; table of top 10 streets/intersections by crash count, sortable
by injured/killed. Borough slicer.

**3. Causes** -- bar chart of top known contributing factors (Unspecified
excluded, with a callout noting what share of crashes have no recorded
cause); a small-multiples or clustered-bar view of contributing factor mix
by borough, so the Queens-vs-Manhattan speeding comparison from the brief
is visible directly on the page.

**4. Who's at Risk** -- the pedestrian/cyclist/motorist share-of-injuries
vs. share-of-fatalities chart (the report's second most important visual,
for the same reason as the Overview trend line -- it's the one place the
"vulnerable road users are disproportionately killed, not just hurt" finding
is visible at a glance); a fatality-rate-when-involved bar by road user
type; a fatality trend by road user type over the 7 years.

**5. Vehicle Types** -- bar chart of top vehicle types by crash count; a
fatal-crashes-per-1,000 bar by vehicle type (restricted to types with a
meaningful sample size, same as the SQL).

Static recreations of the core visual on each page (built from the same
query results, since there's no Power BI Desktop available in this
environment to render the real thing) are in `analysis/charts/` and
embedded in the main project README.

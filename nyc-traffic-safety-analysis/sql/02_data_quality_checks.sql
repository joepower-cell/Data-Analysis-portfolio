-- ============================================================================
-- 02_data_quality_checks.sql
-- Run before trusting any trend, ranking, or rate calculated downstream.
-- ============================================================================

-- Row counts and duplicate check on the natural key
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT "COLLISION_ID") AS distinct_collision_ids,
    COUNT(*) - COUNT(DISTINCT "COLLISION_ID") AS duplicate_rows
FROM crashes_raw;

-- Missing boroughs, streets, and coordinates -- quantified so downstream
-- geographic breakdowns can state what share of crashes they cover
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN "BOROUGH" IS NULL THEN 1 ELSE 0 END) AS missing_borough,
    ROUND(100.0 * SUM(CASE WHEN "BOROUGH" IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_missing_borough,
    SUM(CASE WHEN "ON STREET NAME" IS NULL THEN 1 ELSE 0 END) AS missing_on_street,
    SUM(CASE WHEN "LATITUDE" IS NULL OR "LONGITUDE" IS NULL THEN 1 ELSE 0 END) AS missing_coords
FROM crashes_raw;

-- "Null island" check: (0,0) coordinates are a known geocoding-failure
-- artifact, not a real location
SELECT COUNT(*) AS null_island_rows
FROM crashes_raw
WHERE "LATITUDE" = 0 AND "LONGITUDE" = 0;

-- Category value check -- catch casing/typo drift before grouping on them.
-- This is exactly what motivates the vehicle-type standardization in the
-- cleaned view: the same real category shows up under several spellings.
SELECT "VEHICLE TYPE CODE 1", COUNT(*) AS n
FROM crashes_raw
WHERE lower("VEHICLE TYPE CODE 1") IN ('sedan', '4 dr sedan', 'suv', 'station wagon/suv',
                                        'sport utility / station wagon')
GROUP BY "VEHICLE TYPE CODE 1"
ORDER BY n DESC;

SELECT DISTINCT "BOROUGH" FROM crashes_raw ORDER BY 1;

-- Cost/count-reconciliation-style check: do the per-role injury/fatality
-- columns actually sum to the PERSONS INJURED/KILLED totals? (The
-- equivalent, for this dataset, of the "do the cost components add up"
-- check in a financial dataset.)
SELECT
    COUNT(*) AS rows_checked,
    SUM(CASE
        WHEN "NUMBER OF PERSONS INJURED" != ("NUMBER OF PEDESTRIANS INJURED" + "NUMBER OF CYCLIST INJURED" + "NUMBER OF MOTORIST INJURED")
        THEN 1 ELSE 0
    END) AS injured_totals_dont_reconcile,
    SUM(CASE
        WHEN "NUMBER OF PERSONS KILLED" != ("NUMBER OF PEDESTRIANS KILLED" + "NUMBER OF CYCLIST KILLED" + "NUMBER OF MOTORIST KILLED")
        THEN 1 ELSE 0
    END) AS killed_totals_dont_reconcile
FROM crashes_raw;

-- Range sanity checks
SELECT
    MIN("NUMBER OF PERSONS INJURED") AS min_injured, MAX("NUMBER OF PERSONS INJURED") AS max_injured,
    MIN("NUMBER OF PERSONS KILLED") AS min_killed, MAX("NUMBER OF PERSONS KILLED") AS max_killed,
    MIN(date(substr("CRASH DATE",7,4)||'-'||substr("CRASH DATE",1,2)||'-'||substr("CRASH DATE",4,2))) AS earliest_date,
    MAX(date(substr("CRASH DATE",7,4)||'-'||substr("CRASH DATE",1,2)||'-'||substr("CRASH DATE",4,2))) AS latest_date
FROM crashes_raw;

-- Result on this dataset: 463 duplicate COLLISION_IDs (deduplicated in the
-- view), ~9% missing borough / ~10% missing coordinates / ~4% missing
-- on-street (left as null, not imputed -- a crash with no geocoded borough
-- is still a real crash, just excluded from borough-level breakdowns),
-- ~330 (0,0) geocoding-glitch coordinates (nulled out), a handful of rows
-- where injured/killed sub-totals don't reconcile to the persons total,
-- and the vehicle-type casing drift fixed by the cleaned view's CASE logic.

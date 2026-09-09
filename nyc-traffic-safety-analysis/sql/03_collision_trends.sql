-- ============================================================================
-- 03_collision_trends.sql
-- Are crashes rising or falling over time? Which boroughs have the highest
-- rates? Top 10 streets/intersections by collision count.
-- ============================================================================

-- Crashes per year, with year-over-year change
WITH yearly AS (
    SELECT crash_year, COUNT(*) AS crashes
    FROM v_crashes_clean
    GROUP BY crash_year
)
SELECT
    crash_year,
    crashes,
    LAG(crashes) OVER (ORDER BY crash_year) AS prev_year_crashes,
    ROUND(100.0 * (crashes - LAG(crashes) OVER (ORDER BY crash_year)) / LAG(crashes) OVER (ORDER BY crash_year), 1)
        AS pct_change_vs_prev_year
FROM yearly
ORDER BY crash_year;

-- Same trend but as a monthly series, for a finer-grained view of exactly
-- when the 2020 drop hit and how the recovery/decline shaped up
SELECT
    crash_year, crash_month,
    COUNT(*) AS crashes
FROM v_crashes_clean
GROUP BY crash_year, crash_month
ORDER BY crash_year, crash_month;

-- Crashes by borough -- both raw count and, since boroughs differ hugely in
-- population, worth noting count alone isn't a true "risk rate" (that would
-- need population or vehicle-miles-traveled data this dataset doesn't have
-- -- flagged explicitly here rather than presented as more than it is)
SELECT
    COALESCE(borough, 'UNKNOWN/UNASSIGNED') AS borough,
    COUNT(*) AS crashes,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM v_crashes_clean), 1) AS pct_of_all_crashes,
    SUM(persons_injured) AS total_injured,
    SUM(persons_killed) AS total_killed
FROM v_crashes_clean
GROUP BY borough
ORDER BY crashes DESC;

-- Borough trend over time -- is any one borough driving the citywide trend,
-- or is it consistent across all of them?
SELECT
    crash_year,
    COALESCE(borough, 'UNKNOWN/UNASSIGNED') AS borough,
    COUNT(*) AS crashes
FROM v_crashes_clean
GROUP BY crash_year, borough
ORDER BY borough, crash_year;

-- Top 10 streets by collision count (on_street only -- this dataset doesn't
-- reliably distinguish "at this intersection" from "somewhere along this
-- street," so on_street is the safest unit to rank)
SELECT
    on_street,
    COUNT(*) AS crashes,
    SUM(persons_injured) AS total_injured,
    SUM(persons_killed) AS total_killed
FROM v_crashes_clean
WHERE on_street IS NOT NULL
GROUP BY on_street
ORDER BY crashes DESC
LIMIT 10;

-- Top 10 specific intersections (on_street x cross_street pairs) -- a
-- tighter, more actionable unit than street-alone when both are known.
-- Excludes rows where on_street = cross_street: a street can't intersect
-- itself, so that combination is a geocoding artifact, not a real
-- intersection, and would misleadingly rank as a top hotspot otherwise.
SELECT
    on_street,
    cross_street,
    COUNT(*) AS crashes,
    SUM(persons_injured) AS total_injured,
    SUM(persons_killed) AS total_killed
FROM v_crashes_clean
WHERE on_street IS NOT NULL AND cross_street IS NOT NULL AND on_street != cross_street
GROUP BY on_street, cross_street
ORDER BY crashes DESC
LIMIT 10;

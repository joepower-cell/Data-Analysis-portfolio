-- ============================================================================
-- 04_contributing_factors.sql
-- Top 5 causes of crashes, and whether they differ by borough.
-- ============================================================================

-- Overall contributing factor frequency (vehicle-1 factor -- the primary
-- factor recorded for the crash). "Unspecified" is included deliberately
-- rather than filtered out: a large share of police reports never record a
-- determined cause, and that's a real, important limitation of this data
-- worth stating rather than hiding.
SELECT
    contributing_factor_1,
    COUNT(*) AS crashes,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM v_crashes_clean), 1) AS pct_of_all_crashes
FROM v_crashes_clean
GROUP BY contributing_factor_1
ORDER BY crashes DESC;

-- Top 5 KNOWN causes -- same ranking with "Unspecified" excluded, since
-- that's the more useful list for the "what should we actually target"
-- question the CEO/mayor's office cares about
SELECT
    contributing_factor_1,
    COUNT(*) AS crashes,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM v_crashes_clean WHERE contributing_factor_1 != 'Unspecified'), 1)
        AS pct_of_known_cause_crashes
FROM v_crashes_clean
WHERE contributing_factor_1 != 'Unspecified'
GROUP BY contributing_factor_1
ORDER BY crashes DESC
LIMIT 5;

-- Top factor by borough (excluding Unspecified, for the same reason as above)
WITH ranked AS (
    SELECT
        COALESCE(borough, 'UNKNOWN/UNASSIGNED') AS borough,
        contributing_factor_1,
        COUNT(*) AS crashes,
        RANK() OVER (PARTITION BY COALESCE(borough, 'UNKNOWN/UNASSIGNED') ORDER BY COUNT(*) DESC) AS rnk
    FROM v_crashes_clean
    WHERE contributing_factor_1 != 'Unspecified'
    GROUP BY borough, contributing_factor_1
)
SELECT borough, contributing_factor_1 AS top_known_factor, crashes
FROM ranked
WHERE rnk = 1
ORDER BY borough;

-- Speeding and aggressive driving specifically, by borough -- the exact
-- comparison the brief calls out ("is speeding more common in Queens than
-- Manhattan"), as a rate within each borough so raw crash-volume
-- differences between boroughs don't distort the comparison
SELECT
    COALESCE(borough, 'UNKNOWN/UNASSIGNED') AS borough,
    COUNT(*) AS total_crashes,
    SUM(CASE WHEN contributing_factor_1 = 'Unsafe Speed' THEN 1 ELSE 0 END) AS speeding_crashes,
    ROUND(100.0 * SUM(CASE WHEN contributing_factor_1 = 'Unsafe Speed' THEN 1 ELSE 0 END) / COUNT(*), 2)
        AS pct_speeding,
    SUM(CASE WHEN contributing_factor_1 = 'Aggressive Driving/Road Rage' THEN 1 ELSE 0 END) AS aggressive_driving_crashes,
    ROUND(100.0 * SUM(CASE WHEN contributing_factor_1 = 'Aggressive Driving/Road Rage' THEN 1 ELSE 0 END) / COUNT(*), 2)
        AS pct_aggressive_driving
FROM v_crashes_clean
GROUP BY borough
ORDER BY pct_speeding DESC;

-- Full factor x borough matrix (rate within borough) for the 5 known
-- top-5 factors, so every borough's profile can be compared side by side
-- rather than just the single top factor
WITH top5 AS (
    SELECT contributing_factor_1
    FROM v_crashes_clean
    WHERE contributing_factor_1 != 'Unspecified'
    GROUP BY contributing_factor_1
    ORDER BY COUNT(*) DESC
    LIMIT 5
)
SELECT
    COALESCE(c.borough, 'UNKNOWN/UNASSIGNED') AS borough,
    c.contributing_factor_1,
    COUNT(*) AS crashes,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY COALESCE(c.borough, 'UNKNOWN/UNASSIGNED')), 2)
        AS pct_within_borough
FROM v_crashes_clean c
JOIN top5 t ON t.contributing_factor_1 = c.contributing_factor_1
GROUP BY borough, c.contributing_factor_1
ORDER BY borough, crashes DESC;

-- ============================================================================
-- 06_vehicle_types.sql
-- Which vehicle types are most often involved in crashes, and are certain
-- types linked to more severe outcomes?
-- ============================================================================

-- Most common vehicle types (vehicle 1, standardized) -- this is what the
-- messy-casing cleanup in the view exists for; run this against the RAW
-- column instead and "Sedan"/"SEDAN"/"sedan"/"4 dr sedan" would wrongly
-- split into 4 separate rows.
SELECT
    vehicle_type_1_clean AS vehicle_type,
    COUNT(*) AS crashes,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM v_crashes_clean WHERE vehicle_type_1_clean IS NOT NULL), 1)
        AS pct_of_crashes
FROM v_crashes_clean
WHERE vehicle_type_1_clean IS NOT NULL
GROUP BY vehicle_type_1_clean
ORDER BY crashes DESC
LIMIT 15;

-- Severity by vehicle type: crashes, injury rate, and fatality rate per
-- crash involving that vehicle type as vehicle 1. Restricted to types with
-- a reasonable sample size so a rare vehicle type with 1 fatal crash out of
-- 3 total doesn't misleadingly top the "most dangerous" list.
SELECT
    vehicle_type_1_clean AS vehicle_type,
    COUNT(*) AS crashes,
    ROUND(100.0 * SUM(CASE WHEN persons_injured > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_crashes_with_injury,
    ROUND(1000.0 * SUM(CASE WHEN persons_killed > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fatal_crashes_per_1000
FROM v_crashes_clean
WHERE vehicle_type_1_clean IS NOT NULL
GROUP BY vehicle_type_1_clean
HAVING COUNT(*) >= 500
ORDER BY fatal_crashes_per_1000 DESC;

-- Vehicle type involvement in crashes where a pedestrian or cyclist was
-- killed specifically -- the most policy-relevant severity cut, since it
-- points at which vehicle types are most often on the other side of a
-- vulnerable-road-user fatality
SELECT
    vehicle_type_1_clean AS vehicle_type,
    COUNT(*) AS crashes_with_ped_or_cyclist_killed
FROM v_crashes_clean
WHERE vehicle_type_1_clean IS NOT NULL
  AND (pedestrians_killed > 0 OR cyclists_killed > 0)
GROUP BY vehicle_type_1_clean
ORDER BY crashes_with_ped_or_cyclist_killed DESC
LIMIT 10;

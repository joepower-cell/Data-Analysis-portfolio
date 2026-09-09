-- ============================================================================
-- 05_injury_fatality_analysis.sql
-- Injuries/fatalities by borough. Which road-user group (pedestrian,
-- cyclist, motorist) faces the highest risk. Trends over time.
-- ============================================================================

-- Injured/killed totals by borough
SELECT
    COALESCE(borough, 'UNKNOWN/UNASSIGNED') AS borough,
    COUNT(*) AS crashes,
    SUM(persons_injured) AS total_injured,
    SUM(persons_killed) AS total_killed,
    ROUND(1000.0 * SUM(persons_killed) / COUNT(*), 2) AS fatalities_per_1000_crashes
FROM v_crashes_clean
GROUP BY borough
ORDER BY total_killed DESC;

-- The headline "who's most at risk" answer: total injured/killed by road-
-- user type, plus each group's SHARE of injuries vs. its share of
-- fatalities -- a group overrepresented in fatalities relative to injuries
-- is disproportionately likely to die, not just get hurt, when involved.
WITH totals AS (
    SELECT
        SUM(pedestrians_injured) AS ped_inj, SUM(cyclists_injured) AS cyc_inj, SUM(motorists_injured) AS mot_inj,
        SUM(pedestrians_killed) AS ped_kill, SUM(cyclists_killed) AS cyc_kill, SUM(motorists_killed) AS mot_kill
    FROM v_crashes_clean
)
SELECT 'Pedestrian' AS road_user, ped_inj AS injured, ped_kill AS killed,
       ROUND(100.0 * ped_inj / (ped_inj + cyc_inj + mot_inj), 1) AS pct_of_all_injured,
       ROUND(100.0 * ped_kill / (ped_kill + cyc_kill + mot_kill), 1) AS pct_of_all_killed
FROM totals
UNION ALL
SELECT 'Cyclist', cyc_inj, cyc_kill,
       ROUND(100.0 * cyc_inj / (ped_inj + cyc_inj + mot_inj), 1),
       ROUND(100.0 * cyc_kill / (ped_kill + cyc_kill + mot_kill), 1)
FROM totals
UNION ALL
SELECT 'Motorist', mot_inj, mot_kill,
       ROUND(100.0 * mot_inj / (ped_inj + cyc_inj + mot_inj), 1),
       ROUND(100.0 * mot_kill / (ped_kill + cyc_kill + mot_kill), 1)
FROM totals;

-- Fatality rate PER PERSON INVOLVED (killed / (killed + injured)) by road-
-- user type -- the cleanest single "how dangerous is it to be this kind of
-- road user, once something has already gone wrong" number
WITH totals AS (
    SELECT
        SUM(pedestrians_injured) AS ped_inj, SUM(cyclists_injured) AS cyc_inj, SUM(motorists_injured) AS mot_inj,
        SUM(pedestrians_killed) AS ped_kill, SUM(cyclists_killed) AS cyc_kill, SUM(motorists_killed) AS mot_kill
    FROM v_crashes_clean
)
SELECT 'Pedestrian' AS road_user, ROUND(100.0 * ped_kill / (ped_inj + ped_kill), 2) AS pct_fatal_when_involved FROM totals
UNION ALL
SELECT 'Cyclist', ROUND(100.0 * cyc_kill / (cyc_inj + cyc_kill), 2) FROM totals
UNION ALL
SELECT 'Motorist', ROUND(100.0 * mot_kill / (mot_inj + mot_kill), 2) FROM totals
ORDER BY pct_fatal_when_involved DESC;

-- Injury/fatality trend over time -- total, and split by road-user type, to
-- see whether the 2020-2021 severity spike (noted in the collision trend
-- analysis) hit every group equally
SELECT
    crash_year,
    SUM(persons_injured) AS total_injured,
    SUM(persons_killed) AS total_killed,
    SUM(pedestrians_killed) AS pedestrians_killed,
    SUM(cyclists_killed) AS cyclists_killed,
    SUM(motorists_killed) AS motorists_killed
FROM v_crashes_clean
GROUP BY crash_year
ORDER BY crash_year;

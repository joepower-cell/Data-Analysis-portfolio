-- ============================================================================
-- 01_schema_and_cleaning.sql
-- NYC traffic safety analysis
--
-- Loads the raw crash export and builds a cleaned view that parses the date/
-- time fields, standardizes vehicle type text, and adds the derived columns
-- every other query in this project reuses. Written and tested against
-- SQLite; strftime()/date() are the main things that would need adjusting
-- for Postgres (date_trunc/EXTRACT) or MySQL.
--
-- The raw table's column names match the real NYC Open Data export exactly
-- (including the spaces), which is why every reference to them below is
-- double-quoted -- that's standard SQL identifier-quoting, not a typo.
-- ============================================================================

DROP TABLE IF EXISTS crashes_raw;
CREATE TABLE crashes_raw (
    "CRASH DATE"                        TEXT,   -- 'MM/DD/YYYY' as delivered
    "CRASH TIME"                        TEXT,   -- 'HH:MM' 24-hour, as delivered
    "BOROUGH"                           TEXT,
    "ZIP CODE"                          REAL,
    "LATITUDE"                          REAL,
    "LONGITUDE"                         REAL,
    "ON STREET NAME"                    TEXT,
    "CROSS STREET NAME"                 TEXT,
    "NUMBER OF PERSONS INJURED"         INTEGER,
    "NUMBER OF PERSONS KILLED"          INTEGER,
    "NUMBER OF PEDESTRIANS INJURED"     INTEGER,
    "NUMBER OF PEDESTRIANS KILLED"      INTEGER,
    "NUMBER OF CYCLIST INJURED"         INTEGER,
    "NUMBER OF CYCLIST KILLED"          INTEGER,
    "NUMBER OF MOTORIST INJURED"        INTEGER,
    "NUMBER OF MOTORIST KILLED"         INTEGER,
    "CONTRIBUTING FACTOR VEHICLE 1"     TEXT,
    "CONTRIBUTING FACTOR VEHICLE 2"     TEXT,
    "VEHICLE TYPE CODE 1"               TEXT,
    "VEHICLE TYPE CODE 2"               TEXT,
    "COLLISION_ID"                      INTEGER
);

-- ----------------------------------------------------------------------------
-- Cleaned view. What it fixes, and why (see 02_data_quality_checks.sql for
-- the numbers behind each of these):
--   * ~460 duplicate COLLISION_ID rows -> de-duplicated with a window
--     function keeping one row per ID, since COLLISION_ID is meant to be
--     the natural primary key and a duplicate is a double-logged record,
--     not two real crashes.
--   * CRASH DATE + CRASH TIME are text -> parsed into a real datetime and
--     split into year/month/hour columns for trend analysis.
--   * VEHICLE TYPE CODE 1/2 has ~6 different spellings for what are really
--     2 categories ("Sedan" vs "SEDAN" vs "4 dr sedan"; "Station Wagon/
--     Sport Utility Vehicle" vs "SUV" vs "Sport Utility / Station Wagon")
--     -> standardized into vehicle_type_clean.
--   * BOROUGH/street/coordinates are legitimately missing on a meaningful
--     share of rows (not something to impute -- a crash with no geocoded
--     borough is still a real crash, just not usable for geographic
--     breakdowns) -> left as NULL and handled explicitly in each query
--     that needs a location, rather than silently dropped or guessed at.
--   * A few rows have LATITUDE/LONGITUDE = (0, 0) -- a known real-world
--     geocoding-failure artifact ("null island") -- treated as missing,
--     not as an actual location off the coast of Ghana.
-- ----------------------------------------------------------------------------

DROP VIEW IF EXISTS v_crashes_clean;
CREATE VIEW v_crashes_clean AS
WITH dedup AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY "COLLISION_ID" ORDER BY "COLLISION_ID") AS rn
    FROM crashes_raw
)
SELECT
    "COLLISION_ID"                                                       AS collision_id,
    date(substr("CRASH DATE", 7, 4) || '-' || substr("CRASH DATE", 1, 2) || '-' || substr("CRASH DATE", 4, 2))
                                                                          AS crash_date,
    CAST(substr("CRASH DATE", 7, 4) AS INTEGER)                          AS crash_year,
    CAST(substr("CRASH DATE", 1, 2) AS INTEGER)                          AS crash_month,
    CAST(substr("CRASH TIME", 1, 2) AS INTEGER)                          AS crash_hour,
    "CRASH TIME"                                                         AS crash_time,
    "BOROUGH"                                                            AS borough,
    "ZIP CODE"                                                           AS zip_code,
    CASE WHEN "LATITUDE" = 0 AND "LONGITUDE" = 0 THEN NULL ELSE "LATITUDE" END  AS latitude,
    CASE WHEN "LATITUDE" = 0 AND "LONGITUDE" = 0 THEN NULL ELSE "LONGITUDE" END AS longitude,
    "ON STREET NAME"                                                     AS on_street,
    "CROSS STREET NAME"                                                  AS cross_street,
    "NUMBER OF PERSONS INJURED"                                          AS persons_injured,
    "NUMBER OF PERSONS KILLED"                                           AS persons_killed,
    "NUMBER OF PEDESTRIANS INJURED"                                      AS pedestrians_injured,
    "NUMBER OF PEDESTRIANS KILLED"                                       AS pedestrians_killed,
    "NUMBER OF CYCLIST INJURED"                                          AS cyclists_injured,
    "NUMBER OF CYCLIST KILLED"                                           AS cyclists_killed,
    "NUMBER OF MOTORIST INJURED"                                         AS motorists_injured,
    "NUMBER OF MOTORIST KILLED"                                          AS motorists_killed,
    "CONTRIBUTING FACTOR VEHICLE 1"                                      AS contributing_factor_1,
    "CONTRIBUTING FACTOR VEHICLE 2"                                      AS contributing_factor_2,
    CASE
        WHEN lower("VEHICLE TYPE CODE 1") IN ('sedan', '4 dr sedan') THEN 'Sedan'
        WHEN lower("VEHICLE TYPE CODE 1") IN ('suv', 'station wagon/suv', 'sport utility / station wagon',
                                               'station wagon/sport utility vehicle') THEN 'Station Wagon/Sport Utility Vehicle'
        WHEN lower("VEHICLE TYPE CODE 1") IN ('pickup', 'pick up truck') THEN 'Pick-up Truck'
        WHEN lower("VEHICLE TYPE CODE 1") = 'box truck' THEN 'Box Truck'
        WHEN lower("VEHICLE TYPE CODE 1") IN ('bicycle', 'bike') THEN 'Bike'
        WHEN "VEHICLE TYPE CODE 1" IS NULL THEN NULL
        ELSE "VEHICLE TYPE CODE 1"
    END AS vehicle_type_1_clean,
    CASE
        WHEN lower("VEHICLE TYPE CODE 2") IN ('sedan', '4 dr sedan') THEN 'Sedan'
        WHEN lower("VEHICLE TYPE CODE 2") IN ('suv', 'station wagon/suv', 'sport utility / station wagon',
                                               'station wagon/sport utility vehicle') THEN 'Station Wagon/Sport Utility Vehicle'
        WHEN lower("VEHICLE TYPE CODE 2") IN ('pickup', 'pick up truck') THEN 'Pick-up Truck'
        WHEN lower("VEHICLE TYPE CODE 2") = 'box truck' THEN 'Box Truck'
        WHEN lower("VEHICLE TYPE CODE 2") IN ('bicycle', 'bike') THEN 'Bike'
        WHEN "VEHICLE TYPE CODE 2" IS NULL THEN NULL
        ELSE "VEHICLE TYPE CODE 2"
    END AS vehicle_type_2_clean
FROM dedup
WHERE rn = 1;

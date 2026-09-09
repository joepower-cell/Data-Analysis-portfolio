# Power Query (M) cleaning steps

Applied in Power BI's Power Query Editor after importing the CSV. Listed in
the order they'd sit in the Applied Steps pane.

## fact_crashes

1. **Change types** -- `CRASH DATE` parsed as Date (source format is
   `MM/DD/YYYY`), `CRASH TIME` kept as text and parsed into an `crash_hour`
   whole-number column (see step 4); the six injury/fatality count columns
   and `ZIP CODE`/`LATITUDE`/`LONGITUDE` to Whole Number/Decimal Number.
2. **Remove duplicates** on `COLLISION_ID` -- Table.Distinct keyed on that
   column, keeping the first occurrence. ~460 rows in this export were
   exact double-logs of the same collision.
3. **Standardize vehicle type text** -- `Table.ReplaceValue` /
   conditional-column logic on `VEHICLE TYPE CODE 1` and `VEHICLE TYPE CODE 2`,
   collapsing the casing/naming variants onto one canonical spelling per
   category:
   - `"SEDAN"`, `"sedan"`, `"4 dr sedan"` → `"Sedan"`
   - `"SUV"`, `"station wagon/suv"`, `"Sport Utility / Station Wagon"` → `"Station Wagon/Sport Utility Vehicle"`
   - `"PICKUP"`, `"Pick up Truck"` → `"Pick-up Truck"`
   - `"BICYCLE"`, `"bike"` → `"Bike"`
   (Same logic as the `CASE WHEN` block in `sql/01_schema_and_cleaning.sql`
   -- kept identical between the two so the SQL and Power BI numbers agree.)
4. **Add column: `crash_hour`** -- `Number.From(Text.Start([CRASH TIME], 2))`
5. **Add column: `is_null_island`** -- `[LATITUDE] = 0 and [LONGITUDE] = 0`,
   then a conditional column setting `LATITUDE`/`LONGITUDE` to `null` where
   true -- (0,0) is a known geocoding-failure artifact in this dataset, not
   a real location.
6. **Leave BOROUGH / ON STREET NAME / CROSS STREET NAME / coordinates as
   null where missing** -- no imputation. A crash with no geocoded borough
   is still a real crash; it's just excluded from borough-filtered visuals
   by virtue of not matching any `dim_borough` row, rather than being
   guessed at.

## dim_road_user (built from fact_crashes, not imported separately)

Built with **Unpivot Columns** on the six injury/fatality count columns
(`NUMBER OF PEDESTRIANS INJURED`, `NUMBER OF PEDESTRIANS KILLED`, etc.),
then a conditional column splitting the resulting "Attribute" text into two
new columns: `road_user` (Pedestrian/Cyclist/Motorist) and `outcome`
(Injured/Killed). This is what lets the "who's at risk" visuals treat road
user type as a single filterable dimension instead of six separate measures.

## dim_date / dim_borough

Same pattern as the other projects in this portfolio: `dim_date` is a DAX
calculated table via `CALENDAR()`; `dim_borough` is entered manually via
**Enter Data**, purely to give the boroughs a crash-volume sort order and a
clean way to filter out unassigned crashes from geographic visuals.

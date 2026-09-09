"""
Generates a synthetic recreation of NYC's "Motor Vehicle Collisions - Crashes"
open dataset: same column names, same known quirks (missing boroughs,
inconsistent vehicle-type casing, an "Unspecified" contributing factor that
dominates because police reports are often incomplete), and a scale (~180K
rows over 7 years) that actually justifies "put it in a database" rather
than opening a CSV in Excel.

This is generated data, not a download of the real dataset -- built to
behave like it (real column names, real contributing-factor and vehicle-type
vocabulary, a real-shaped COVID-era dip and severity spike) so the cleaning
and analysis techniques below are the genuine article even though the rows
themselves are synthetic.

Run: python src/generate_data.py
Output: data/Motor_Vehicle_Collisions_Crashes.csv
"""

import numpy as np
import pandas as pd

RNG_SEED = 21
START = pd.Timestamp("2018-01-01")
N_MONTHS = 84  # 2018-01 through 2024-12
OUT_PATH = "data/Motor_Vehicle_Collisions_Crashes.csv"

BOROUGHS = ["BROOKLYN", "QUEENS", "MANHATTAN", "BRONX", "STATEN ISLAND"]
BOROUGH_WEIGHTS = np.array([0.30, 0.27, 0.20, 0.18, 0.05])
BOROUGH_WEIGHTS = BOROUGH_WEIGHTS / BOROUGH_WEIGHTS.sum()
BOROUGH_MISSING_RATE = 0.09  # applied on top of the borough draw below

# rough real-world bounding boxes (lat_min, lat_max, lon_min, lon_max)
BOROUGH_BOUNDS = {
    "BROOKLYN":       (40.57, 40.74, -74.04, -73.83),
    "QUEENS":         (40.54, 40.80, -73.96, -73.70),
    "MANHATTAN":      (40.70, 40.88, -74.02, -73.91),
    "BRONX":          (40.79, 40.92, -73.93, -73.77),
    "STATEN ISLAND":  (40.49, 40.65, -74.26, -74.05),
}

STREETS_BY_BOROUGH = {
    "BROOKLYN": ["ATLANTIC AVENUE", "FLATBUSH AVENUE", "OCEAN PARKWAY", "EASTERN PARKWAY",
                 "BEDFORD AVENUE", "NOSTRAND AVENUE", "CONEY ISLAND AVENUE", "4 AVENUE",
                 "LINDEN BOULEVARD", "MYRTLE AVENUE"],
    "QUEENS": ["QUEENS BOULEVARD", "NORTHERN BOULEVARD", "WOODHAVEN BOULEVARD", "UNION TURNPIKE",
               "ROOSEVELT AVENUE", "JAMAICA AVENUE", "HILLSIDE AVENUE", "GRAND CENTRAL PARKWAY",
               "CROSS BAY BOULEVARD", "ASTORIA BOULEVARD"],
    "MANHATTAN": ["BROADWAY", "5 AVENUE", "2 AVENUE", "3 AVENUE", "AMSTERDAM AVENUE",
                  "WEST END AVENUE", "LEXINGTON AVENUE", "FDR DRIVE", "WEST STREET", "7 AVENUE"],
    "BRONX": ["GRAND CONCOURSE", "WHITE PLAINS ROAD", "BRUCKNER BOULEVARD", "FORDHAM ROAD",
              "WEBSTER AVENUE", "PELHAM PARKWAY", "SOUTHERN BOULEVARD", "GUN HILL ROAD",
              "TREMONT AVENUE", "BOSTON ROAD"],
    "STATEN ISLAND": ["HYLAN BOULEVARD", "RICHMOND AVENUE", "VICTORY BOULEVARD", "FOREST AVENUE",
                       "ARTHUR KILL ROAD", "AMBOY ROAD", "RICHMOND ROAD", "BAY STREET",
                       "SOUTH AVENUE", "STATEN ISLAND EXPRESSWAY"],
}
ALL_STREETS = sorted({s for streets in STREETS_BY_BOROUGH.values() for s in streets})

# real vocabulary from the NYC open dataset, with realistic relative frequency.
# "Unspecified" dominates because a large share of police reports never record
# a determined cause -- that's a genuine, well-known quirk of this dataset.
CONTRIBUTING_FACTORS = {
    "Unspecified": 0.32,
    "Driver Inattention/Distraction": 0.16,
    "Failure to Yield Right-of-Way": 0.07,
    "Following Too Closely": 0.06,
    "Unsafe Speed": 0.06,
    "Passing or Lane Usage Improper": 0.045,
    "Backing Unsafely": 0.04,
    "Turning Improperly": 0.04,
    "Traffic Control Disregarded": 0.035,
    "Aggressive Driving/Road Rage": 0.03,
    "Pavement Slippery": 0.025,
    "Alcohol Involvement": 0.02,
    "Pedestrian/Bicyclist/Other Pedestrian Error/Confusion": 0.02,
    "Driver Inexperience": 0.02,
    "View Obstructed/Limited": 0.015,
    "Fatigued/Drowsy": 0.01,
    "Other Vehicular": 0.055,
}
FACTOR_NAMES = list(CONTRIBUTING_FACTORS.keys())
FACTOR_WEIGHTS = np.array(list(CONTRIBUTING_FACTORS.values()))
FACTOR_WEIGHTS = FACTOR_WEIGHTS / FACTOR_WEIGHTS.sum()

# borough tilts applied multiplicatively to the base factor weights above --
# Queens/Staten Island (wider, faster arterials) skew toward speed/aggression;
# Manhattan (dense, congested, pedestrian-heavy) skews toward inattention and
# failure-to-yield; the rest stay close to the citywide baseline.
BOROUGH_FACTOR_TILT = {
    "QUEENS":         {"Unsafe Speed": 1.9, "Aggressive Driving/Road Rage": 1.6},
    "STATEN ISLAND":  {"Unsafe Speed": 2.1, "Aggressive Driving/Road Rage": 1.5},
    "MANHATTAN":      {"Driver Inattention/Distraction": 1.3, "Failure to Yield Right-of-Way": 1.4,
                        "Pedestrian/Bicyclist/Other Pedestrian Error/Confusion": 1.5},
    "BROOKLYN":       {"Failure to Yield Right-of-Way": 1.15},
    "BRONX":          {"Following Too Closely": 1.2},
}

# vehicle types: real free-text vocabulary, deliberately including the messy
# variants called out in the project brief (Station Wagon/SUV vs SUV, plus
# casing inconsistency)
VEHICLE_TYPES_CANONICAL = {
    "Sedan": 0.34,
    "Station Wagon/Sport Utility Vehicle": 0.30,
    "Taxi": 0.05,
    "Pick-up Truck": 0.05,
    "Box Truck": 0.035,
    "Bus": 0.03,
    "Bike": 0.03,
    "E-Bike": 0.015,
    "Motorcycle": 0.02,
    "Convertible": 0.01,
    "Moped": 0.01,
    "Tractor Truck Diesel": 0.015,
    "Ambulance": 0.01,
    "E-Scooter": 0.015,
    "Van": 0.02,
    "Garbage or Refuse": 0.008,
    "Dump": 0.007,
}
VEH_NAMES = list(VEHICLE_TYPES_CANONICAL.keys())
VEH_WEIGHTS = np.array(list(VEHICLE_TYPES_CANONICAL.values()))
VEH_WEIGHTS = VEH_WEIGHTS / VEH_WEIGHTS.sum()

# messy display variants a real export would contain for the same underlying
# category -- this is exactly what "standardize vehicle types" means in practice
VEHICLE_MESSY_VARIANTS = {
    "Station Wagon/Sport Utility Vehicle": ["Station Wagon/Sport Utility Vehicle", "SUV",
                                             "Sport Utility / Station Wagon", "station wagon/suv"],
    "Sedan": ["Sedan", "SEDAN", "4 dr sedan", "sedan"],
    "Pick-up Truck": ["Pick-up Truck", "PICKUP", "Pick up Truck"],
    "Box Truck": ["Box Truck", "BOX TRUCK", "box truck"],
    "Bike": ["Bike", "BICYCLE", "bike"],
}


def seasonal_multiplier(month: int) -> float:
    # slightly more crashes in fall (back-to-school/commuting) and low points
    # in deep winter (Feb) and August (lower traffic volume)
    return {1: 0.95, 2: 0.88, 3: 0.97, 4: 1.0, 5: 1.03, 6: 1.02, 7: 0.98,
            8: 0.90, 9: 1.05, 10: 1.08, 11: 1.02, 12: 1.0}[month]


def year_multiplier(year: int) -> float:
    # gentle pre-COVID decline, sharp 2020 drop (lockdowns -> far less
    # traffic), partial rebound, then continued gradual decline as Vision
    # Zero interventions accumulate
    return {2018: 1.05, 2019: 1.00, 2020: 0.62, 2021: 0.80, 2022: 0.90,
            2023: 0.86, 2024: 0.82}[year]


def severity_multiplier(year: int) -> float:
    # fatality/severity rate PER crash: roads were emptier in 2020-2021 so
    # the crashes that did happen were faster and more severe -- a real,
    # well-documented pattern in NYC crash data, not just noise
    return {2018: 1.0, 2019: 0.97, 2020: 1.35, 2021: 1.22, 2022: 1.05,
            2023: 0.95, 2024: 0.90}[year]


def build_crashes(rng: np.random.Generator) -> pd.DataFrame:
    base_monthly = 2150
    rows_per_month = []
    for m in range(N_MONTHS):
        d = START + pd.DateOffset(months=m)
        n = int(base_monthly * seasonal_multiplier(d.month) * year_multiplier(d.year) * rng.uniform(0.94, 1.06))
        rows_per_month.append((d, n))

    total_n = sum(n for _, n in rows_per_month)

    # ---- dates & times -----------------------------------------------
    dates, sev_mults = [], []
    for d, n in rows_per_month:
        day_offsets = rng.integers(0, 28, size=n)
        dates.extend([d + pd.DateOffset(days=int(o)) for o in day_offsets])
        sev_mults.extend([severity_multiplier(d.year)] * n)
    dates = pd.Series(dates)
    sev_mults = np.array(sev_mults)

    # crash time: rush-hour-weighted hour distribution
    hour_weights = np.array([1, 0.6, 0.4, 0.3, 0.4, 0.8, 1.8, 3.2, 3.6, 2.4, 2.0, 2.2,
                              2.6, 2.4, 2.6, 3.0, 3.6, 4.2, 3.8, 2.8, 2.2, 2.0, 1.6, 1.2])
    hour_weights = hour_weights / hour_weights.sum()
    hours = rng.choice(24, size=total_n, p=hour_weights)
    minutes = rng.integers(0, 60, size=total_n)
    crash_time = [f"{h:02d}:{mm:02d}" for h, mm in zip(hours, minutes)]

    # ---- borough & location -------------------------------------------
    borough_choices = rng.choice(BOROUGHS, size=total_n, p=BOROUGH_WEIGHTS)
    borough_missing_mask = rng.random(total_n) < BOROUGH_MISSING_RATE
    borough = np.where(borough_missing_mask, None, borough_choices)

    lat = np.full(total_n, np.nan)
    lon = np.full(total_n, np.nan)
    for b in BOROUGHS:
        idx = np.where(borough_choices == b)[0]
        lo_lat, hi_lat, lo_lon, hi_lon = BOROUGH_BOUNDS[b]
        lat[idx] = rng.uniform(lo_lat, hi_lat, size=len(idx))
        lon[idx] = rng.uniform(lo_lon, hi_lon, size=len(idx))
    coord_missing_mask = rng.random(total_n) < 0.10
    lat = np.where(coord_missing_mask, np.nan, lat)
    lon = np.where(coord_missing_mask, np.nan, lon)

    on_street = np.empty(total_n, dtype=object)
    cross_street = np.empty(total_n, dtype=object)
    for b in BOROUGHS:
        idx = np.where(borough_choices == b)[0]
        pool = STREETS_BY_BOROUGH[b]
        on_street[idx] = rng.choice(pool, size=len(idx))
        cross_street[idx] = rng.choice(pool, size=len(idx))
    # a handful of unassigned-borough rows still get a street from the full citywide pool
    unassigned_idx = np.where(pd.isna(borough))[0]
    on_street[unassigned_idx] = rng.choice(ALL_STREETS, size=len(unassigned_idx))
    cross_street[unassigned_idx] = rng.choice(ALL_STREETS, size=len(unassigned_idx))
    street_missing_mask = rng.random(total_n) < 0.04
    on_street = np.where(street_missing_mask, None, on_street)
    cross_missing_mask = rng.random(total_n) < 0.18  # off-street/no-cross-street crashes are common
    cross_street = np.where(cross_missing_mask, None, cross_street)

    zip_lookup = {"MANHATTAN": 10001, "BROOKLYN": 11201, "QUEENS": 11101,
                  "BRONX": 10451, "STATEN ISLAND": 10301}
    zipcode = np.array([
        (zip_lookup[b] + int(rng.integers(0, 40))) if b in zip_lookup else None
        for b in borough_choices
    ], dtype=object)
    zipcode = np.where(pd.isna(borough), None, zipcode)

    # ---- contributing factors (with borough tilt) ----------------------
    factor1 = np.empty(total_n, dtype=object)
    for b in list(BOROUGHS) + [None]:
        idx = np.where(borough == b)[0] if b is not None else np.where(pd.isna(borough))[0]
        if len(idx) == 0:
            continue
        w = FACTOR_WEIGHTS.copy()
        tilt = BOROUGH_FACTOR_TILT.get(b, {})
        for fname, mult in tilt.items():
            w[FACTOR_NAMES.index(fname)] *= mult
        w = w / w.sum()
        factor1[idx] = rng.choice(FACTOR_NAMES, size=len(idx), p=w)

    has_second_vehicle = rng.random(total_n) < 0.55
    factor2 = np.where(
        has_second_vehicle,
        rng.choice(FACTOR_NAMES, size=total_n, p=FACTOR_WEIGHTS),
        None,
    )

    # ---- vehicle types ---------------------------------------------------
    veh1_canon = rng.choice(VEH_NAMES, size=total_n, p=VEH_WEIGHTS)
    veh2_canon = np.where(
        has_second_vehicle,
        rng.choice(VEH_NAMES, size=total_n, p=VEH_WEIGHTS),
        None,
    )

    def messify(canon_array):
        out = np.empty(len(canon_array), dtype=object)
        for i, v in enumerate(canon_array):
            if v is None:
                out[i] = None
                continue
            variants = VEHICLE_MESSY_VARIANTS.get(v, [v])
            out[i] = variants[rng.integers(0, len(variants))] if len(variants) > 1 and rng.random() < 0.4 else v
        return out

    veh1 = messify(veh1_canon)
    veh2 = messify(veh2_canon)

    # ---- injuries & fatalities --------------------------------------------
    # severity draw: none / injury / fatal, per crash, modulated by the
    # year's severity multiplier (2020-2021 roads-are-empty effect)
    base_p = np.array([0.715, 0.28, 0.005])
    fatal_p = np.clip(base_p[2] * sev_mults, 0.001, 0.02)
    injury_p = np.clip(base_p[1] * (1 + 0.15 * (sev_mults - 1)), 0.05, 0.5)
    none_p = 1 - injury_p - fatal_p
    sev_probs = np.stack([none_p, injury_p, fatal_p], axis=1)
    sev_probs = sev_probs / sev_probs.sum(axis=1, keepdims=True)
    severity = np.array([rng.choice(3, p=sev_probs[i]) for i in range(total_n)])

    ped_inj = np.zeros(total_n, dtype=int)
    cyc_inj = np.zeros(total_n, dtype=int)
    mot_inj = np.zeros(total_n, dtype=int)
    ped_kill = np.zeros(total_n, dtype=int)
    cyc_kill = np.zeros(total_n, dtype=int)
    mot_kill = np.zeros(total_n, dtype=int)

    injury_idx = np.where(severity == 1)[0]
    # who's involved: mostly motorists (vehicle occupants), with pedestrians/
    # cyclists a meaningful minority of injured people but overrepresented
    # in the fatal category (see below) -- the actual "who's at highest risk"
    # finding for this project
    role = rng.choice(["motorist", "pedestrian", "cyclist"], size=len(injury_idx),
                       p=[0.68, 0.20, 0.12])
    counts = rng.choice([1, 1, 1, 2, 3], size=len(injury_idx), p=[0.55, 0.0, 0.25, 0.13, 0.07])
    for role_name, arr in (("motorist", mot_inj), ("pedestrian", ped_inj), ("cyclist", cyc_inj)):
        sel = injury_idx[role == role_name]
        arr[sel] = counts[np.isin(injury_idx, sel)]

    fatal_idx = np.where(severity == 2)[0]
    # pedestrians and cyclists are heavily overrepresented among fatalities
    # relative to their share of injuries -- vulnerable road users absorb
    # far more of the lethality even though motorists dominate raw crash counts
    fatal_role = rng.choice(["motorist", "pedestrian", "cyclist"], size=len(fatal_idx),
                             p=[0.38, 0.42, 0.20])
    for role_name, arr in (("motorist", mot_kill), ("pedestrian", ped_kill), ("cyclist", cyc_kill)):
        sel = fatal_idx[fatal_role == role_name]
        arr[sel] = 1
    # a fatal crash commonly also injures others in the same incident
    also_injured = fatal_idx[rng.random(len(fatal_idx)) < 0.4]
    mot_inj[also_injured] += rng.integers(1, 3, size=len(also_injured))

    persons_injured = ped_inj + cyc_inj + mot_inj
    persons_killed = ped_kill + cyc_kill + mot_kill

    collision_id = np.arange(400_000_000, 400_000_000 + total_n)

    df = pd.DataFrame({
        "CRASH DATE": dates.dt.strftime("%m/%d/%Y"),
        "CRASH TIME": crash_time,
        "BOROUGH": borough,
        "ZIP CODE": zipcode,
        "LATITUDE": lat,
        "LONGITUDE": lon,
        "ON STREET NAME": on_street,
        "CROSS STREET NAME": cross_street,
        "NUMBER OF PERSONS INJURED": persons_injured,
        "NUMBER OF PERSONS KILLED": persons_killed,
        "NUMBER OF PEDESTRIANS INJURED": ped_inj,
        "NUMBER OF PEDESTRIANS KILLED": ped_kill,
        "NUMBER OF CYCLIST INJURED": cyc_inj,
        "NUMBER OF CYCLIST KILLED": cyc_kill,
        "NUMBER OF MOTORIST INJURED": mot_inj,
        "NUMBER OF MOTORIST KILLED": mot_kill,
        "CONTRIBUTING FACTOR VEHICLE 1": factor1,
        "CONTRIBUTING FACTOR VEHICLE 2": factor2,
        "VEHICLE TYPE CODE 1": veh1,
        "VEHICLE TYPE CODE 2": veh2,
        "COLLISION_ID": collision_id,
    })
    return df, rng


def add_realistic_mess(df: pd.DataFrame, rng: np.random.Generator) -> pd.DataFrame:
    df = df.copy()

    # 1) a few (0,0) "null island" coordinate glitches -- a real, well-known
    #    artifact of this exact dataset when geocoding fails silently
    glitch_idx = df.sample(frac=0.002, random_state=31).index
    df.loc[glitch_idx, "LATITUDE"] = 0.0
    df.loc[glitch_idx, "LONGITUDE"] = 0.0

    # 2) a handful of rows where the injured/killed component totals don't
    #    match NUMBER OF PERSONS INJURED/KILLED -- data entry errors
    mismatch_idx = df.sample(frac=0.0015, random_state=37).index
    df.loc[mismatch_idx, "NUMBER OF PERSONS INJURED"] = (
        df.loc[mismatch_idx, "NUMBER OF PERSONS INJURED"] + rng.integers(1, 3, size=len(mismatch_idx))
    )

    # 3) duplicate COLLISION_ID rows (double-logged in the source system)
    dupes = df.sample(frac=0.003, random_state=41)
    df = pd.concat([df, dupes], ignore_index=True)

    df = df.sample(frac=1.0, random_state=99).reset_index(drop=True)
    return df


def main():
    rng = np.random.default_rng(RNG_SEED)
    df, rng = build_crashes(rng)
    df = add_realistic_mess(df, rng)
    df.to_csv(OUT_PATH, index=False)
    print(f"Wrote {len(df):,} rows to {OUT_PATH}")


if __name__ == "__main__":
    main()

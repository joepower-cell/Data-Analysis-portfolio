"""
Generate a synthetic e-commerce transactions dataset for the customer
segmentation & retention analysis project.

The data is entirely synthetic (no real customers/orders), but it is built
to *behave* like a real retail export: seasonal demand, customer cohorts
with realistic churn, a handful of acquisition channels, and the kind of
mess (missing IDs, duplicate rows, returns, inconsistent text casing,
price outliers) that a real analyst would have to clean up before doing
any real analysis.

Run: python src/generate_data.py
Output: data/raw/transactions.csv
"""

import numpy as np
import pandas as pd

RNG_SEED = 42
N_CUSTOMERS = 1800
N_MONTHS = 24
START_DATE = pd.Timestamp("2023-01-01")
OUT_PATH = "data/raw/transactions.csv"

CATEGORIES = {
    "Electronics": (40, 600),
    "Home & Kitchen": (10, 150),
    "Apparel": (8, 90),
    "Beauty": (5, 60),
    "Sports & Outdoors": (12, 200),
    "Books": (5, 35),
    "Toys": (6, 70),
    "Office Supplies": (3, 45),
}
CATEGORY_NAMES = list(CATEGORIES.keys())

CHANNELS = ["Organic Search", "Paid Ads", "Email", "Referral", "Social"]
CHANNEL_WEIGHTS = [0.32, 0.28, 0.15, 0.15, 0.10]

# country field deliberately has inconsistent casing/spacing to simulate
# messy source systems merged from multiple regions
COUNTRY_VARIANTS = {
    "United Kingdom": ["United Kingdom", "united kingdom", "UK", " United Kingdom"],
    "Germany": ["Germany", "germany", "DE"],
    "France": ["France", "france"],
    "United States": ["United States", "united states", "USA", "US"],
    "Ireland": ["Ireland", "ireland"],
}
COUNTRY_WEIGHTS = [0.42, 0.18, 0.14, 0.16, 0.10]


def month_index(ts: pd.Timestamp, start: pd.Timestamp) -> int:
    return (ts.year - start.year) * 12 + (ts.month - start.month)


def seasonal_multiplier(month: int) -> float:
    """November/December spike, slow Jan/Feb, mild summer bump."""
    base = {
        1: 0.75, 2: 0.78, 3: 0.90, 4: 0.95, 5: 1.00, 6: 1.05,
        7: 1.08, 8: 1.02, 9: 0.95, 10: 1.05, 11: 1.55, 12: 1.85,
    }
    return base[month]


def build_customers(rng: np.random.Generator) -> pd.DataFrame:
    # signup (first-purchase) month spread across the first 20 months so
    # every cohort has room to be observed for at least a few months
    signup_month = rng.integers(0, N_MONTHS - 4, size=N_CUSTOMERS)
    signup_date = [START_DATE + pd.DateOffset(months=int(m)) for m in signup_month]

    channel = rng.choice(CHANNELS, size=N_CUSTOMERS, p=CHANNEL_WEIGHTS)
    country = rng.choice(list(COUNTRY_VARIANTS.keys()), size=N_CUSTOMERS, p=COUNTRY_WEIGHTS)

    # latent "loyalty" score drives both purchase frequency and how slowly
    # the customer churns after signup -> creates realistic RFM spread and
    # a cohort retention curve that decays but with a long tail of loyal buyers
    loyalty = rng.beta(2.0, 5.0, size=N_CUSTOMERS)  # skewed toward lower loyalty, long tail

    # referral/email customers are on average a bit stickier than paid ads
    channel_bonus = pd.Series(channel).map({
        "Organic Search": 0.03, "Paid Ads": -0.05, "Email": 0.06,
        "Referral": 0.08, "Social": -0.02,
    }).to_numpy()
    loyalty = np.clip(loyalty + channel_bonus, 0.02, 0.98)

    return pd.DataFrame({
        "CustomerID": [f"C{100000 + i}" for i in range(N_CUSTOMERS)],
        "SignupDate": signup_date,
        "SignupMonthIdx": signup_month,
        "Channel": channel,
        "Country": country,
        "_loyalty": loyalty,
    })


def build_transactions(customers: pd.DataFrame, rng: np.random.Generator) -> pd.DataFrame:
    rows = []
    invoice_counter = 900000

    for _, cust in customers.iterrows():
        for m in range(cust["SignupMonthIdx"], N_MONTHS):
            months_since_signup = m - cust["SignupMonthIdx"]
            # retention decays with tenure, moderated by loyalty; loyal
            # customers barely decay, low-loyalty customers drop off fast
            decay = np.exp(-months_since_signup * (0.35 - 0.30 * cust["_loyalty"]))
            purchase_prob = min(0.95, cust["_loyalty"] * 0.9 * decay + 0.02)

            calendar_month = (START_DATE + pd.DateOffset(months=int(m))).month
            purchase_prob *= seasonal_multiplier(calendar_month) / 1.0

            if rng.random() > min(purchase_prob, 0.97):
                continue  # no purchase this month

            # number of separate orders this customer places in the month
            n_orders = 1 if rng.random() > 0.15 else 2
            for _ in range(n_orders):
                day_offset = int(rng.integers(0, 28))
                invoice_date = START_DATE + pd.DateOffset(months=int(m), days=day_offset)
                invoice_counter += 1
                invoice_no = f"INV{invoice_counter}"

                n_lines = rng.integers(1, 5)
                country_variant = rng.choice(COUNTRY_VARIANTS[cust["Country"]])

                for _ in range(n_lines):
                    cat = rng.choice(CATEGORY_NAMES)
                    lo, hi = CATEGORIES[cat]
                    unit_price = round(float(rng.uniform(lo, hi)), 2)
                    quantity = int(rng.integers(1, 6))

                    # occasional return (negative quantity)
                    if rng.random() < 0.02:
                        quantity = -quantity

                    rows.append({
                        "InvoiceNo": invoice_no,
                        "InvoiceDate": invoice_date,
                        "CustomerID": cust["CustomerID"],
                        "Channel": cust["Channel"],
                        "Country": country_variant,
                        "ProductCategory": cat,
                        "Quantity": quantity,
                        "UnitPrice": unit_price,
                    })

    return pd.DataFrame(rows)


def add_realistic_mess(df: pd.DataFrame, rng: np.random.Generator) -> pd.DataFrame:
    df = df.copy()

    # 1) missing CustomerID for a slice of orders (guest checkouts)
    guest_mask = rng.random(len(df)) < 0.04
    df.loc[guest_mask, "CustomerID"] = np.nan

    # 2) duplicate a small number of rows outright (double-scanned lines)
    dupes = df.sample(frac=0.01, random_state=42)
    df = pd.concat([df, dupes], ignore_index=True)

    # 3) inject a handful of extreme price outliers (data entry errors)
    outlier_idx = df.sample(frac=0.002, random_state=7).index
    df.loc[outlier_idx, "UnitPrice"] = df.loc[outlier_idx, "UnitPrice"] * rng.uniform(50, 120)

    # 4) a few rows with missing UnitPrice
    missing_price_idx = df.sample(frac=0.003, random_state=11).index
    df.loc[missing_price_idx, "UnitPrice"] = np.nan

    # shuffle row order like a real export would be
    df = df.sample(frac=1.0, random_state=99).reset_index(drop=True)
    return df


def main():
    rng = np.random.default_rng(RNG_SEED)
    customers = build_customers(rng)
    txns = build_transactions(customers, rng)
    txns = add_realistic_mess(txns, rng)

    txns = txns[[
        "InvoiceNo", "InvoiceDate", "CustomerID", "ProductCategory",
        "Quantity", "UnitPrice", "Channel", "Country",
    ]]
    txns.to_csv(OUT_PATH, index=False)
    print(f"Wrote {len(txns):,} rows to {OUT_PATH}")
    print(f"Customers simulated: {N_CUSTOMERS:,}")


if __name__ == "__main__":
    main()

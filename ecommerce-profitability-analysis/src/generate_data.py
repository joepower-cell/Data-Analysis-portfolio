"""
Generates the three synthetic BrightCart datasets used in this project:
orders (transaction-level), products (catalog + cost data), and
marketing_spend (monthly, by platform).

Entirely synthetic, but built to behave like a real e-commerce export: 8
categories with genuinely different cost/return/discount profiles, 4 sales
channels with different fee structures, seasonal demand, a marketing mix
where platform efficiency drifts over time -- and the kind of mess (a few
orphaned product references, a few missing shipping costs, a handful of
duplicate lines) that a real finance export would need cleaning up before
any of the profitability questions could be answered honestly.

Run: python src/generate_data.py
Output: data/orders.csv, data/products.csv, data/marketing_spend.csv
"""

import numpy as np
import pandas as pd

RNG_SEED = 7
START_DATE = pd.Timestamp("2024-01-01")
N_MONTHS = 24
OUT_DIR = "data"

# ---------------------------------------------------------------------------
# Category profile: (unit_cost_range, list_price_range, base return rate,
# discount tendency). Deliberately differentiated so profitability by
# category has a real, explainable story rather than random noise.
# ---------------------------------------------------------------------------
CATEGORIES = {
    #                cost_range        price_range     return_rate  discount_rate
    "Electronics":     ((40, 320),      (79, 599),        0.16,        0.22),
    "Apparel":         ((6, 45),        (18, 89),         0.21,        0.35),
    "Home & Kitchen":  ((10, 90),       (24, 179),        0.09,        0.18),
    "Beauty":          ((3, 22),        (12, 59),         0.05,        0.15),
    "Sports & Outdoors": ((12, 110),    (29, 219),        0.10,        0.20),
    "Toys & Games":    ((4, 35),        (14, 79),         0.06,        0.25),
    "Books & Media":   ((3, 12),        (9, 29),          0.03,        0.10),
    "Jewelry & Accessories": ((8, 150), (29, 349),        0.13,        0.12),
}
CATEGORY_NAMES = list(CATEGORIES.keys())
N_PRODUCTS_PER_CATEGORY = 10

# channel: (share of orders, aov multiplier, platform fee rate, return rate multiplier)
CHANNELS = {
    "Website":         (0.34, 1.00, 0.000, 1.00),
    "Mobile App":      (0.28, 0.90, 0.000, 1.05),
    "Marketplace":     (0.24, 1.05, 0.150, 1.10),
    "Social Commerce": (0.14, 0.80, 0.080, 1.35),  # impulse buys -> more returns
}
CHANNEL_NAMES = list(CHANNELS.keys())

RETURN_REASONS = [
    "Wrong Size / Fit", "Damaged in Transit", "Not as Described",
    "Changed Mind", "Found Cheaper Elsewhere", "Item Defective",
]

MARKETING_PLATFORMS = ["Google Ads", "Meta Ads", "TikTok Ads", "Pinterest Ads", "Email/Affiliate"]


def seasonal_multiplier(month: int) -> float:
    base = {
        1: 0.82, 2: 0.85, 3: 0.92, 4: 0.95, 5: 0.98, 6: 1.00,
        7: 0.97, 8: 0.98, 9: 1.02, 10: 1.10, 11: 1.55, 12: 1.70,
    }
    return base[month]


def build_products(rng: np.random.Generator) -> pd.DataFrame:
    rows = []
    pid = 1
    for cat, ((cost_lo, cost_hi), (price_lo, price_hi), _, _) in CATEGORIES.items():
        for _ in range(N_PRODUCTS_PER_CATEGORY):
            cost = round(float(rng.uniform(cost_lo, cost_hi)), 2)
            # keep list price consistent with a plausible markup over cost,
            # while still varying within the category's price band
            price = round(float(np.clip(rng.uniform(price_lo, price_hi), cost * 1.15, price_hi)), 2)
            rows.append({
                "product_id": f"P{pid:04d}",
                "category": cat,
                "product_name": f"{cat.split(' ')[0]} Item {pid}",
                "unit_cost": cost,
                "list_price": price,
            })
            pid += 1
    return pd.DataFrame(rows)


def build_orders(products: pd.DataFrame, rng: np.random.Generator) -> pd.DataFrame:
    rows = []
    order_id = 500000

    # total order count calibrated to land around $1.0-1.3M gross revenue
    # over 24 months given the price bands above
    monthly_base_orders = 430

    for m in range(N_MONTHS):
        month_date = START_DATE + pd.DateOffset(months=m)
        n_orders = int(monthly_base_orders * seasonal_multiplier(month_date.month) * rng.uniform(0.92, 1.08))

        for _ in range(n_orders):
            order_id += 1
            day_offset = int(rng.integers(0, 28))
            order_date = month_date + pd.DateOffset(days=day_offset)

            channel = rng.choice(CHANNEL_NAMES, p=[CHANNELS[c][0] for c in CHANNEL_NAMES])
            _, aov_mult, fee_rate, return_mult = CHANNELS[channel]

            cat = rng.choice(CATEGORY_NAMES)
            cat_products = products[products["category"] == cat]
            product = cat_products.sample(1, random_state=rng.integers(0, 1_000_000)).iloc[0]

            quantity = int(rng.choice([1, 2, 3], p=[0.78, 0.17, 0.05]))
            unit_price = round(product["list_price"] * aov_mult * rng.uniform(0.95, 1.05), 2)

            base_discount_rate = CATEGORIES[cat][3]
            has_discount = rng.random() < base_discount_rate
            discount_amount = round(unit_price * quantity * rng.uniform(0.05, 0.25), 2) if has_discount else 0.0

            gross_revenue = round(unit_price * quantity, 2)
            platform_fee = round(gross_revenue * fee_rate, 2) if fee_rate > 0 else 0.0

            # shipping: flat-ish cost with some variance by category weight proxy (price band)
            shipping_cost = round(rng.uniform(3.5, 9.5) + (0.01 * unit_price), 2)

            base_return_rate = CATEGORIES[cat][2]
            is_returned = rng.random() < min(0.6, base_return_rate * return_mult)

            return_reason = None
            return_processing_cost = 0.0
            if is_returned:
                return_reason = rng.choice(RETURN_REASONS)
                return_processing_cost = round(rng.uniform(2.0, 6.0), 2)

            rows.append({
                "order_id": f"ORD{order_id}",
                "order_date": order_date,
                "product_id": product["product_id"],
                "category": cat,
                "channel": channel,
                "quantity": quantity,
                "unit_price": unit_price,
                "gross_revenue": gross_revenue,
                "discount_amount": discount_amount,
                "shipping_cost": shipping_cost,
                "platform_fee": platform_fee,
                "is_returned": "Yes" if is_returned else "No",
                "return_reason": return_reason,
                "return_processing_cost": return_processing_cost,
            })

    return pd.DataFrame(rows)


def build_marketing_spend(rng: np.random.Generator) -> pd.DataFrame:
    """
    Platform efficiency profiles, deliberately differentiated:
      - Google Ads: stable, solid ROAS throughout
      - Email/Affiliate: cheap, consistently the best ROAS
      - Meta Ads: decent but middling, slowly softening
      - TikTok Ads: starts hot (great ROAS in year 1), CPMs rise through
        year 2 as the platform matures -> ROAS erodes -> a real
        "reduce spend on this platform in these recent months" story
      - Pinterest Ads: weak throughout, spend never really converts
    """
    rows = []
    base_monthly_spend = {
        "Google Ads": 3800, "Meta Ads": 3200, "TikTok Ads": 2200,
        "Pinterest Ads": 1400, "Email/Affiliate": 900,
    }
    base_roas = {
        "Google Ads": 4.2, "Meta Ads": 3.3, "TikTok Ads": 5.1,
        "Pinterest Ads": 1.6, "Email/Affiliate": 7.5,
    }
    cpc = {
        "Google Ads": 1.35, "Meta Ads": 0.95, "TikTok Ads": 0.55,
        "Pinterest Ads": 0.70, "Email/Affiliate": 0.15,
    }

    for m in range(N_MONTHS):
        month_date = START_DATE + pd.DateOffset(months=m)
        month_str = month_date.strftime("%Y-%m")
        season = seasonal_multiplier(month_date.month)

        for platform in MARKETING_PLATFORMS:
            spend = base_monthly_spend[platform] * season * rng.uniform(0.9, 1.1)
            # spend creeps up slowly for every platform as the company scales
            spend *= (1 + 0.01 * m)

            roas = base_roas[platform]
            if platform == "TikTok Ads":
                # efficiency erosion: strong through month ~10, then decays
                decay_start = 10
                if m > decay_start:
                    roas = roas * max(0.45, 1 - 0.045 * (m - decay_start))
            elif platform == "Pinterest Ads":
                roas = roas * rng.uniform(0.85, 1.15)  # stays weak, just noisy
            else:
                roas = roas * (1 - 0.003 * m)  # mild natural softening

            roas *= rng.uniform(0.92, 1.08)
            spend = round(float(spend), 2)
            attributed_revenue = round(spend * max(roas, 0.3), 2)

            platform_cpc = cpc[platform] * rng.uniform(0.9, 1.1)
            clicks = int(spend / platform_cpc)
            impressions = int(clicks * rng.uniform(35, 55))
            # conversion rate varies a bit by platform realism (email highest)
            conv_rate = {"Google Ads": 0.045, "Meta Ads": 0.03, "TikTok Ads": 0.022,
                         "Pinterest Ads": 0.018, "Email/Affiliate": 0.09}[platform]
            conversions = max(1, int(clicks * conv_rate * rng.uniform(0.85, 1.15)))

            rows.append({
                "month": month_str,
                "platform": platform,
                "spend": spend,
                "impressions": impressions,
                "clicks": clicks,
                "conversions": conversions,
                "attributed_revenue": attributed_revenue,
            })

    return pd.DataFrame(rows)


def add_realistic_mess(orders: pd.DataFrame, products: pd.DataFrame, rng: np.random.Generator):
    orders = orders.copy()

    # 1) a handful of orders reference a product_id that doesn't exist in the
    #    catalog (a common real-world issue -- discontinued SKU, bad export join)
    orphan_idx = orders.sample(frac=0.006, random_state=3).index
    orders.loc[orphan_idx, "product_id"] = "P9999"

    # 2) some orders missing shipping_cost (nulls to impute)
    missing_ship_idx = orders.sample(frac=0.01, random_state=5).index
    orders.loc[missing_ship_idx, "shipping_cost"] = np.nan

    # 3) a small number of exact duplicate rows (double-logged transactions)
    dupes = orders.sample(frac=0.008, random_state=11)
    orders = pd.concat([orders, dupes], ignore_index=True)

    # 4) a few negative/nonsense discount values (data entry errors)
    bad_discount_idx = orders.sample(frac=0.002, random_state=17).index
    orders.loc[bad_discount_idx, "discount_amount"] = -orders.loc[bad_discount_idx, "discount_amount"].abs() - 5

    orders = orders.sample(frac=1.0, random_state=99).reset_index(drop=True)
    return orders


def main():
    rng = np.random.default_rng(RNG_SEED)

    products = build_products(rng)
    orders = build_orders(products, rng)
    orders = add_realistic_mess(orders, products, rng)
    marketing = build_marketing_spend(rng)

    products.to_csv(f"{OUT_DIR}/products.csv", index=False)
    orders.to_csv(f"{OUT_DIR}/orders.csv", index=False)
    marketing.to_csv(f"{OUT_DIR}/marketing_spend.csv", index=False)

    print(f"Wrote {len(products)} products, {len(orders):,} orders, {len(marketing)} marketing rows")
    print(f"Gross revenue (sum of gross_revenue, incl. returns): ${orders['gross_revenue'].sum():,.0f}")


if __name__ == "__main__":
    main()

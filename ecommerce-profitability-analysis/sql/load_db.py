"""
Builds a local SQLite database from the three source CSVs so the .sql files
in this folder can be run end to end without a live Postgres/MySQL
instance. Schema lives in 01_schema_and_cleaning.sql -- this script applies
it and loads the rows.

Usage: python3 sql/load_db.py
Output: brightcart.db in the project root
"""
import sqlite3
import pandas as pd

DB_PATH = "brightcart.db"
SCHEMA_PATH = "sql/01_schema_and_cleaning.sql"


def strip_comments(sql_text: str) -> str:
    lines = []
    for line in sql_text.splitlines():
        if line.strip().startswith("--"):
            continue
        idx = line.find("--")
        lines.append(line[:idx] if idx != -1 else line)
    return "\n".join(lines)


def main():
    conn = sqlite3.connect(DB_PATH)

    schema_sql = strip_comments(open(SCHEMA_PATH).read())
    conn.executescript(schema_sql)

    orders = pd.read_csv("data/orders.csv")
    products = pd.read_csv("data/products.csv")
    marketing = pd.read_csv("data/marketing_spend.csv")
    orders.to_sql("orders_raw", conn, if_exists="append", index=False)
    products.to_sql("products", conn, if_exists="append", index=False)
    marketing.to_sql("marketing_spend", conn, if_exists="append", index=False)

    conn.commit()
    for t in ("orders_raw", "products", "marketing_spend"):
        n = conn.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        print(f"{t}: {n:,} rows")
    conn.close()


if __name__ == "__main__":
    main()

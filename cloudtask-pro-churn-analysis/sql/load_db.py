"""
Builds a local SQLite database from the two source CSVs so the .sql files in
this folder can actually be run end to end without a live Postgres/MySQL
instance. The schema itself lives in 01_schema_and_cleaning.sql -- this
script just applies it and loads the rows.

Usage: python3 sql/load_db.py
Output: cloudtask_pro.db in the project root
"""
import re
import sqlite3
import pandas as pd

DB_PATH = "cloudtask_pro.db"
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

    subs = pd.read_csv("data/subscriptions.csv")
    mrev = pd.read_csv("data/monthly_revenue.csv")
    subs.to_sql("subscriptions_raw", conn, if_exists="append", index=False)
    mrev.to_sql("monthly_revenue", conn, if_exists="append", index=False)

    conn.commit()
    n_subs = conn.execute("SELECT COUNT(*) FROM subscriptions_raw").fetchone()[0]
    n_mrev = conn.execute("SELECT COUNT(*) FROM monthly_revenue").fetchone()[0]
    print(f"Loaded {n_subs} subscription rows and {n_mrev} monthly revenue rows into {DB_PATH}")
    conn.close()


if __name__ == "__main__":
    main()

"""
Builds a local SQLite database from the crash CSV so the .sql files in this
folder can run end to end without a live Postgres/MySQL instance (the brief's
own advice -- "for this amount of data, put it in a database" -- is exactly
what this does). Schema lives in 01_schema_and_cleaning.sql; this script
applies it and loads the rows.

Usage: python3 sql/load_db.py
Output: nyc_crashes.db in the project root
"""
import sqlite3
import pandas as pd

DB_PATH = "nyc_crashes.db"
SCHEMA_PATH = "sql/01_schema_and_cleaning.sql"
CSV_PATH = "data/Motor_Vehicle_Collisions_Crashes.csv"


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

    crashes = pd.read_csv(CSV_PATH)
    crashes.to_sql("crashes_raw", conn, if_exists="append", index=False)

    conn.commit()
    n = conn.execute("SELECT COUNT(*) FROM crashes_raw").fetchone()[0]
    print(f"Loaded {n:,} rows into {DB_PATH}")
    conn.close()


if __name__ == "__main__":
    main()

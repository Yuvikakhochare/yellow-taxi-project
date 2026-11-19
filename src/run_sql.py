
from pathlib import Path
import sys
import duckdb

PROJECT_DIR = Path(__file__).resolve().parent.parent
DB_PATH = PROJECT_DIR / "data" / "yellow_taxi.duckdb"
SQL_DIR = PROJECT_DIR / "sql"

if len(sys.argv) < 2:
    print("Usage: python src/run_sql.py filename.sql")
    sys.exit(1)

SQL_FILE = sys.argv[1]
SQL_PATH = SQL_DIR / SQL_FILE

if not SQL_PATH.exists():
    raise FileNotFoundError(f"SQL file not found: {SQL_PATH}")

connection = duckdb.connect(str(DB_PATH))

try:
    sql_code = SQL_PATH.read_text(encoding="utf-8")

    queries = [
        query.strip()
        for query in sql_code.split(";")
        if query.strip()
    ]

    print("\n" + "=" * 60)
    print(f"EXECUTING: {SQL_FILE}")
    print("=" * 60)

    for number, query in enumerate(queries, start=1):

        # Skip fragments containing only SQL comments
        cleaned_query = "\n".join(
            line for line in query.splitlines()
            if line.strip() and not line.strip().startswith("--")
        ).strip()

        if not cleaned_query:
            continue

        print(f"\nQUERY {number}")
        print("-" * 60)

        cursor = connection.execute(query)

        if cursor is None:
            continue

        if cursor.description is not None:
            result = cursor.fetchdf()

            if not result.empty:
                print(result.to_string(index=False))
            else:
                print("Query executed successfully. No rows returned.")
        else:
            print("Statement executed successfully.")

    print("\nSQL FILE EXECUTED SUCCESSFULLY!")

finally:
    connection.close()

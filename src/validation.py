
from pathlib import Path
from datetime import datetime
import duckdb

# Project paths
PROJECT_DIR = Path(__file__).resolve().parent.parent
DB_PATH = PROJECT_DIR / "data" / "yellow_taxi.duckdb"
LOG_DIR = PROJECT_DIR / "logs"

# Create logs folder if it does not exist
LOG_DIR.mkdir(exist_ok=True)

# Connect to DuckDB
con = duckdb.connect(str(DB_PATH))

try:
    # 1. Monthly validation report
    monthly_report = con.execute("""
        SELECT *
        FROM monthly_validation_log
        ORDER BY month
    """).df()

    monthly_report.to_csv(
        LOG_DIR / "monthly_validation_log.csv",
        index=False
    )

    # 2. Quarantine reason summary
    reason_report = con.execute("""
        SELECT reason_code, COUNT(*) AS rejected_records
        FROM quarantined_trips
        GROUP BY reason_code
        ORDER BY rejected_records DESC
    """).df()

    reason_report.to_csv(
        LOG_DIR / "quarantine_reason_summary.csv",
        index=False
    )

    # 3. Overall validation summary
    summary = con.execute("""
        SELECT
            COUNT(*) AS total_records,
            COUNT(*) FILTER (
                WHERE validation_status = 'LOADED'
            ) AS accepted_records,
            COUNT(*) FILTER (
                WHERE validation_status = 'QUARANTINED'
            ) AS quarantined_records
        FROM validated_trips
    """).fetchone()

    total, accepted, quarantined = summary

    # 4. Save text log
    log_file = LOG_DIR / "validation_summary.txt"

    with open(log_file, "w", encoding="utf-8") as file:
        file.write("YELLOW TAXI DATA VALIDATION REPORT\n")
        file.write("=" * 40 + "\n")
        file.write(f"Generated: {datetime.now()}\n\n")
        file.write(f"Total records: {total}\n")
        file.write(f"Accepted records: {accepted}\n")
        file.write(f"Quarantined records: {quarantined}\n")
        file.write(f"Reconciliation difference: {total - accepted - quarantined}\n")

    print("VALIDATION LOGS GENERATED SUCCESSFULLY!")
    print("Files saved in:", LOG_DIR)
    print("1. monthly_validation_log.csv")
    print("2. quarantine_reason_summary.csv")
    print("3. validation_summary.txt")

finally:
    con.close()

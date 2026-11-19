
from pathlib import Path
import logging
import duckdb
import sys

# --------------------------------------------------
# 1. PROJECT PATHS
# --------------------------------------------------

PROJECT_DIR = Path(__file__).resolve().parent.parent

RAW_DATA_DIR = PROJECT_DIR / "data" / "raw"

PROCESSED_DATA_DIR = PROJECT_DIR / "data" / "processed"

DB_PATH = PROJECT_DIR / "data" / "yellow_taxi.duckdb"

SOURCE_FILE = RAW_DATA_DIR / "yellow_tripdata_2026-09.parquet"


# --------------------------------------------------
# 2. LOGGING CONFIGURATION
# --------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

logger = logging.getLogger(__name__)


# --------------------------------------------------
# 3. CHECK SOURCE FILE
# --------------------------------------------------

def check_source_file():

    logger.info("Checking source dataset...")

    if not SOURCE_FILE.exists():
        raise FileNotFoundError(
            f"Dataset not found: {SOURCE_FILE}\n"
            "Please place yellow_tripdata_2026-09.parquet "
            "inside data/raw/"
        )

    file_size = SOURCE_FILE.stat().st_size

    if file_size == 0:
        raise ValueError("Source Parquet file is empty.")

    logger.info("Source file found: %s", SOURCE_FILE.name)
    logger.info("File size: %.2f MB", file_size / (1024 * 1024))


# --------------------------------------------------
# 4. INGEST DATA INTO DUCKDB
# --------------------------------------------------

def ingest_data():

    logger.info("Starting Yellow Taxi data ingestion...")

    RAW_DATA_DIR.mkdir(parents=True, exist_ok=True)
    PROCESSED_DATA_DIR.mkdir(parents=True, exist_ok=True)

    check_source_file()

    connection = duckdb.connect(str(DB_PATH))

    try:

        # Read Parquet file and create raw table
        connection.execute(
            """
            CREATE OR REPLACE TABLE raw_trips AS
            SELECT *
            FROM read_parquet(?)
            """,
            [str(SOURCE_FILE)]
        )

        logger.info("Raw table created successfully.")

        # --------------------------------------------------
        # 5. COUNT TOTAL RECORDS
        # --------------------------------------------------

        total_records = connection.execute(
            "SELECT COUNT(*) FROM raw_trips"
        ).fetchone()[0]

        logger.info("Total records ingested: %s", total_records)

        # --------------------------------------------------
        # 6. CHECK COLUMN INFORMATION
        # --------------------------------------------------

        columns = connection.execute(
            "DESCRIBE raw_trips"
        ).fetchall()

        logger.info("Total columns: %s", len(columns))

        # --------------------------------------------------
        # 7. DISPLAY SAMPLE RECORDS
        # --------------------------------------------------

        sample_data = connection.execute(
            "SELECT * FROM raw_trips LIMIT 5"
        ).fetchdf()

        print("\n========== INGESTION SUMMARY ==========")
        print(f"Source file     : {SOURCE_FILE.name}")
        print(f"Database        : {DB_PATH.name}")
        print(f"Raw table       : raw_trips")
        print(f"Total records   : {total_records:,}")
        print(f"Total columns   : {len(columns)}")

        print("\n========== SAMPLE DATA ==========")
        print(sample_data.to_string(index=False))

        print("\n========== INGESTION SUCCESSFUL ==========")

    finally:
        connection.close()


# --------------------------------------------------
# 8. MAIN EXECUTION
# --------------------------------------------------

if __name__ == "__main__":

    try:
        ingest_data()

    except Exception as error:
        logger.exception("Data ingestion failed: %s", error)
        sys.exit(1)

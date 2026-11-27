
from pathlib import Path
import logging
import hashlib
import duckdb
import sys

# --------------------------------------------------
# 1. PROJECT CONFIGURATION
# --------------------------------------------------

PROJECT_DIR = Path(__file__).resolve().parent.parent

RAW_DATA_DIR = PROJECT_DIR / "data" / "raw"

PROCESSED_DATA_DIR = PROJECT_DIR / "data" / "processed"

DB_PATH = PROJECT_DIR / "data" / "yellow_taxi_2025.duckdb"

ZONE_LOOKUP_FILE = RAW_DATA_DIR / "taxi_zone_lookup.csv"

# January 2025 to December 2025
MONTHS = [
    "2025-01",
    "2025-02",
    "2025-03",
    "2025-04",
    "2025-05",
    "2025-06",
    "2025-07",
    "2025-08",
    "2025-09",
    "2025-10",
    "2025-11",
    "2025-12",
]


# --------------------------------------------------
# 2. LOGGING CONFIGURATION
# --------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

logger = logging.getLogger(__name__)


# --------------------------------------------------
# 3. FILE VALIDATION
# --------------------------------------------------

def get_source_files():

    files = {}

    for month in MONTHS:

        file_name = f"yellow_tripdata_{month}.parquet"
        file_path = RAW_DATA_DIR / file_name

        if not file_path.exists():
            raise FileNotFoundError(
                f"Missing monthly dataset: {file_path}"
            )

        if file_path.stat().st_size == 0:
            raise ValueError(
                f"Dataset is empty: {file_name}"
            )

        files[month] = file_path

    if not ZONE_LOOKUP_FILE.exists():
        raise FileNotFoundError(
            f"Zone lookup not found: {ZONE_LOOKUP_FILE}"
        )

    logger.info("All 12 monthly datasets are available.")
    logger.info("Zone lookup file found.")

    return files


# --------------------------------------------------
# 4. FILE HASH FOR DUPLICATE PREVENTION
# --------------------------------------------------

def calculate_file_hash(file_path):

    sha256 = hashlib.sha256()

    with open(file_path, "rb") as file:

        for chunk in iter(
            lambda: file.read(1024 * 1024), b""
        ):
            sha256.update(chunk)

    return sha256.hexdigest()


# --------------------------------------------------
# 5. DATABASE TABLES
# --------------------------------------------------

def create_control_tables(connection):

    connection.execute("""
        CREATE TABLE IF NOT EXISTS ingestion_registry (
            month VARCHAR PRIMARY KEY,
            file_name VARCHAR,
            file_hash VARCHAR,
            rows_loaded BIGINT,
            ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    logger.info("Ingestion registry is ready.")


# --------------------------------------------------
# 6. PREPARE RAW TRIPS TABLE
# --------------------------------------------------

def prepare_raw_table(connection, first_file):

    table_exists = connection.execute("""
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_name = 'raw_trips'
    """).fetchone()[0] > 0

    if not table_exists:

        connection.execute("""
            CREATE TABLE raw_trips AS
            SELECT *,
                   CAST(NULL AS VARCHAR) AS source_month,
                   CAST(NULL AS VARCHAR) AS source_file
            FROM read_parquet(?)
            WHERE FALSE
        """, [str(first_file)])

        logger.info("Created raw_trips table.")

        return

    existing_columns = {
        row[0] for row in connection.execute(
            "DESCRIBE raw_trips"
        ).fetchall()
    }

    legacy_table = "source_file" not in existing_columns

    connection.execute("""
        ALTER TABLE raw_trips
        ADD COLUMN IF NOT EXISTS source_month VARCHAR
    """)

    connection.execute("""
        ALTER TABLE raw_trips
        ADD COLUMN IF NOT EXISTS source_file VARCHAR
    """)

    # Migrate September 2026 data loaded by the old script.
    if legacy_table:

        september_file = RAW_DATA_DIR / (
            "yellow_tripdata_2026-09.parquet"
        )

        if not september_file.exists():
            raise FileNotFoundError(
                "Existing raw_trips table needs migration. "
                "September 2026 source file is missing."
            )

        september_hash = calculate_file_hash(september_file)

        existing_count = connection.execute("""
            SELECT COUNT(*) FROM raw_trips
        """).fetchone()[0]

        if existing_count > 0:

            connection.execute("""
                UPDATE raw_trips
                SET source_month = '2026-09',
                    source_file = 'yellow_tripdata_2026-09.parquet'
                WHERE source_file IS NULL
            """)

            connection.execute("""
                INSERT INTO ingestion_registry
                (month, file_name, file_hash, rows_loaded)
                VALUES (?, ?, ?, ?)
                ON CONFLICT (month) DO NOTHING
            """, [
                "2026-09",
                september_file.name,
                september_hash,
                existing_count
            ])

            logger.info(
                "Migrated existing September records: %s",
                existing_count
            )


# --------------------------------------------------
# 7. LOAD ZONE LOOKUP
# --------------------------------------------------

def load_zone_lookup(connection):

    logger.info("Loading taxi zone lookup...")

    if not ZONE_LOOKUP_FILE.exists():
        raise FileNotFoundError(
            f"Zone lookup not found: {ZONE_LOOKUP_FILE}"
        )

    if ZONE_LOOKUP_FILE.stat().st_size == 0:
        raise ValueError("Taxi zone lookup file is empty.")

    connection.execute("""
        CREATE OR REPLACE TABLE raw_zone_lookup AS
        SELECT *
        FROM read_csv_auto(?, header = TRUE)
    """, [str(ZONE_LOOKUP_FILE)])

    zone_count = connection.execute("""
        SELECT COUNT(*) FROM raw_zone_lookup
    """).fetchone()[0]

    if zone_count == 0:
        raise ValueError("No records found in taxi zone lookup.")

    logger.info(
        "Zone lookup loaded successfully: %s records",
        zone_count
    )

    return zone_count


# --------------------------------------------------
# 8. INGEST MONTHLY DATA
# --------------------------------------------------

def ingest_month(connection, month, file_path):

    file_hash = calculate_file_hash(file_path)

    existing = connection.execute("""
        SELECT file_hash, rows_loaded
        FROM ingestion_registry
        WHERE month = ?
    """, [month]).fetchone()

    # Skip previously ingested unchanged files.
    if existing:

        if existing[0] != file_hash:

            raise ValueError(
                f"Source file changed after ingestion: {month}. "
                "Review the existing data before reloading."
            )

        logger.info(
            "%s already ingested. Skipping. Previous rows: %s",
            month,
            existing[1]
        )

        return 0

    source_rows = connection.execute("""
        SELECT COUNT(*)
        FROM read_parquet(?)
    """, [str(file_path)]).fetchone()[0]

    connection.execute("BEGIN TRANSACTION")

    try:

        connection.execute("""
            INSERT INTO raw_trips BY NAME
            SELECT *,
                   ? AS source_month,
                   ? AS source_file
            FROM read_parquet(?)
        """, [
            month,
            file_path.name,
            str(file_path)
        ])

        connection.execute("""
            INSERT INTO ingestion_registry
            (month, file_name, file_hash, rows_loaded)
            VALUES (?, ?, ?, ?)
        """, [
            month,
            file_path.name,
            file_hash,
            source_rows
        ])

        connection.execute("COMMIT")

    except Exception:

        connection.execute("ROLLBACK")
        raise

    logger.info(
        "%s | Newly ingested rows: %s",
        month,
        source_rows
    )

    return source_rows


# --------------------------------------------------
# 9. MAIN INGESTION PROCESS
# --------------------------------------------------

def ingest_data():

    logger.info("Starting 12-month Yellow Taxi ingestion.")

    RAW_DATA_DIR.mkdir(parents=True, exist_ok=True)

    PROCESSED_DATA_DIR.mkdir(parents=True, exist_ok=True)

    source_files = get_source_files()

    connection = duckdb.connect(str(DB_PATH))

    try:

        create_control_tables(connection)

        prepare_raw_table(
            connection,
            next(iter(source_files.values()))
        )

        zone_count = load_zone_lookup(connection)

        total_new_rows = 0

        print("\n========== MONTHLY INGESTION REPORT ==========")

        for month, file_path in source_files.items():

            new_rows = ingest_month(
                connection,
                month,
                file_path
            )

            total_new_rows += new_rows

            print(
                f"{month} | Newly loaded: {new_rows:,}"
            )

        total_records = connection.execute("""
            SELECT COUNT(*) FROM raw_trips
        """).fetchone()[0]

        registered_months = connection.execute("""
            SELECT COUNT(*) FROM ingestion_registry
        """).fetchone()[0]

        print("\n========== INGESTION SUMMARY ==========")

        print(f"Database          : {DB_PATH.name}")
        print(f"Raw table         : raw_trips")
        print(f"Zone lookup rows  : {zone_count:,}")
        print(f"Months registered : {registered_months}")
        print(f"New rows this run : {total_new_rows:,}")
        print(f"Total raw records : {total_records:,}")

        print("\n========== INGESTION SUCCESSFUL ==========")

    finally:

        connection.close()


# --------------------------------------------------
# 10. EXECUTION
# --------------------------------------------------

if __name__ == "__main__":

    try:

        ingest_data()

    except Exception as error:

        logger.exception(
            "Data ingestion failed: %s",
            error
        )

        sys.exit(1)

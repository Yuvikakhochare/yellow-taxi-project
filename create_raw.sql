
-- Raw source data is registered by src/ingest.py.
-- Expected source: September 2026 NYC Yellow Taxi Parquet file.

SELECT
    COUNT(*) AS total_raw_records
FROM raw_trips;

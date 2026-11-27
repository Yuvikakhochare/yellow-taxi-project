
-- ============================================================
-- YELLOW TAXI PROJECT
-- FILE: validation.sql
-- PURPOSE: 12-MONTH TRIP VALIDATION AND QUARANTINE
-- SOURCE: raw_trips
-- DATABASE: DuckDB
-- ============================================================


-- 1. VALIDATE ALL SOURCE RECORDS

CREATE OR REPLACE TABLE validated_trips AS

WITH source_data AS (

    SELECT
        ROW_NUMBER() OVER () AS source_row_id,
        *,

        CASE
            WHEN tpep_pickup_datetime IS NULL
            THEN 'UNKNOWN'
            ELSE STRFTIME(tpep_pickup_datetime, '%Y-%m')
        END AS validation_month,

        CASE
            WHEN tpep_pickup_datetime IS NULL
              OR tpep_dropoff_datetime IS NULL
            THEN NULL
            ELSE DATE_DIFF(
                'second',
                tpep_pickup_datetime,
                tpep_dropoff_datetime
            ) / 60.0
        END AS duration_minutes

    FROM raw_trips
),

classified AS (

    SELECT *,

        CASE

            WHEN tpep_pickup_datetime IS NULL
              OR tpep_dropoff_datetime IS NULL
                THEN 'MISSING_TIMESTAMP'

            WHEN tpep_dropoff_datetime <= tpep_pickup_datetime
                THEN 'INVALID_DURATION'

            WHEN passenger_count IS NULL
              OR passenger_count <= 0
              OR passenger_count > 6
                THEN 'INVALID_PASSENGER_COUNT'

            WHEN trip_distance IS NULL
              OR trip_distance <= 0
              OR trip_distance > 100
                THEN 'INVALID_DISTANCE'

            WHEN fare_amount IS NULL
              OR fare_amount < 0
                THEN 'INVALID_FARE'

            WHEN total_amount IS NULL
              OR total_amount < 0
                THEN 'INVALID_TOTAL_AMOUNT'

            WHEN trip_distance >= 3
              AND duration_minutes >= 20
                THEN 'LONG_TRIP_OUT_OF_SCOPE'

            ELSE NULL

        END AS reason_code

    FROM source_data
)

SELECT
    *,
    CASE
        WHEN reason_code IS NULL THEN 'LOADED'
        ELSE 'QUARANTINED'
    END AS validation_status

FROM classified;


-- 2. CREATE ACCEPTED TRIPS TABLE

CREATE OR REPLACE TABLE accepted_trips AS

SELECT *
FROM validated_trips
WHERE validation_status = 'LOADED';


-- 3. CREATE QUARANTINE TABLE

CREATE OR REPLACE TABLE quarantined_trips AS

SELECT *
FROM validated_trips
WHERE validation_status = 'QUARANTINED';


-- 4. MONTHLY RECONCILIATION LOG

CREATE OR REPLACE TABLE monthly_validation_log AS

SELECT

    validation_month AS month,

    COUNT(*) AS source_rows,

    COUNT(*) FILTER (
        WHERE validation_status = 'LOADED'
    ) AS loaded_rows,

    COUNT(*) FILTER (
        WHERE validation_status = 'QUARANTINED'
    ) AS quarantined_rows,

    COUNT(*) FILTER (
        WHERE validation_status = 'LOADED'
    )
    +
    COUNT(*) FILTER (
        WHERE validation_status = 'QUARANTINED'
    ) AS reconciled_rows

FROM validated_trips

GROUP BY validation_month
ORDER BY validation_month;


-- 5. VALIDATE MONTHLY RECONCILIATION

SELECT
    month,
    source_rows,
    loaded_rows,
    quarantined_rows,

    source_rows -
    (loaded_rows + quarantined_rows) AS difference

FROM monthly_validation_log
ORDER BY month;


-- 6. REASON CODE SUMMARY

SELECT
    reason_code,
    COUNT(*) AS rejected_records

FROM quarantined_trips

GROUP BY reason_code
ORDER BY rejected_records DESC;


-- 7. FINAL VALIDATION SUMMARY

SELECT

    COUNT(*) AS total_source_rows,

    COUNT(*) FILTER (
        WHERE validation_status = 'LOADED'
    ) AS total_loaded_rows,

    COUNT(*) FILTER (
        WHERE validation_status = 'QUARANTINED'
    ) AS total_quarantined_rows

FROM validated_trips;

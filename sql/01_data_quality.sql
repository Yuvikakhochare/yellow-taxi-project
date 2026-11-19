
-- ============================================================
-- YELLOW TAXI DATA ANALYTICS PROJECT
-- FILE: 01_data_quality_checks.sql
-- DATABASE: DuckDB
-- SOURCE TABLE: raw_trips
-- ANALYSIS PERIOD: SEPTEMBER 2026
-- ============================================================


-- 1. TOTAL RAW RECORDS

SELECT
    COUNT(*) AS total_raw_records
FROM raw_trips;


-- 2. NULL PICKUP DATETIME

SELECT
    COUNT(*) AS null_pickup_datetime
FROM raw_trips
WHERE tpep_pickup_datetime IS NULL;


-- 3. NULL DROPOFF DATETIME

SELECT
    COUNT(*) AS null_dropoff_datetime
FROM raw_trips
WHERE tpep_dropoff_datetime IS NULL;


-- 4. NULL VENDOR AND LOCATION VALUES

SELECT
    COUNT(*) FILTER (WHERE VendorID IS NULL) AS null_vendor,
    COUNT(*) FILTER (WHERE PULocationID IS NULL) AS null_pickup_location,
    COUNT(*) FILTER (WHERE DOLocationID IS NULL) AS null_dropoff_location
FROM raw_trips;


-- 5. EXACT DUPLICATE VALIDATION

SELECT
    COUNT(*) AS duplicate_groups,
    COALESCE(SUM(record_count - 1), 0)
        AS excess_duplicate_records
FROM (
    SELECT COUNT(*) AS record_count
    FROM raw_trips
    GROUP BY
        VendorID,
        tpep_pickup_datetime,
        tpep_dropoff_datetime,
        passenger_count,
        trip_distance,
        RatecodeID,
        store_and_fwd_flag,
        PULocationID,
        DOLocationID,
        payment_type,
        fare_amount,
        extra,
        mta_tax,
        tip_amount,
        tolls_amount,
        improvement_surcharge,
        total_amount,
        congestion_surcharge,
        Airport_fee,
        cbd_congestion_fee,
        request_source
    HAVING COUNT(*) > 1
) duplicates;


-- 6. INVALID TRIP DURATION COUNT

SELECT
    COUNT(*) AS invalid_duration_records
FROM raw_trips
WHERE tpep_dropoff_datetime <= tpep_pickup_datetime;


-- 7. NEGATIVE FARE AND TOTAL AMOUNT COUNT

SELECT
    COUNT(*) FILTER (WHERE fare_amount < 0)
        AS negative_fare_records,
    COUNT(*) FILTER (WHERE total_amount < 0)
        AS negative_total_records
FROM raw_trips;


-- 8. PICKUP DATE DISTRIBUTION

SELECT
    YEAR(tpep_pickup_datetime) AS pickup_year,
    MONTH(tpep_pickup_datetime) AS pickup_month,
    COUNT(*) AS total_records
FROM raw_trips
GROUP BY 1, 2
ORDER BY 1, 2;


-- 9. RECORDS OUTSIDE SEPTEMBER 2026

SELECT
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    VendorID,
    trip_distance,
    total_amount
FROM raw_trips
WHERE tpep_pickup_datetime < TIMESTAMP '2026-09-01 00:00:00'
   OR tpep_pickup_datetime >= TIMESTAMP '2026-10-01 00:00:00'
LIMIT 30;


-- 10. INVALID TRIP DURATION EXAMPLES

SELECT
    tpep_pickup_datetime,
    tpep_dropoff_datetime,
    passenger_count,
    trip_distance
FROM raw_trips
WHERE tpep_dropoff_datetime <= tpep_pickup_datetime
LIMIT 20;


-- 11. NEGATIVE FARE EXAMPLES

SELECT
    fare_amount,
    total_amount,
    payment_type,
    trip_distance
FROM raw_trips
WHERE fare_amount < 0
   OR total_amount < 0
LIMIT 20;


-- 12. PASSENGER COUNT DISTRIBUTION

SELECT
    passenger_count,
    COUNT(*) AS total_records
FROM raw_trips
GROUP BY passenger_count
ORDER BY passenger_count;


-- 13. NULL PASSENGER COUNT BY VENDOR

SELECT
    VendorID,
    payment_type,
    COUNT(*) AS total_records,
    COUNT(*) FILTER (
        WHERE passenger_count IS NULL
    ) AS null_passengers,
    COUNT(*) FILTER (
        WHERE passenger_count = 0
    ) AS zero_passengers
FROM raw_trips
GROUP BY VendorID, payment_type
ORDER BY VendorID, payment_type;


-- 14. DISTANCE OUTLIER INVESTIGATION

SELECT
    MIN(trip_distance) AS minimum_distance,
    MAX(trip_distance) AS maximum_distance,
    COUNT(*) FILTER (
        WHERE trip_distance = 0
    ) AS zero_distance,
    COUNT(*) FILTER (
        WHERE trip_distance > 100
    ) AS above_100_miles
FROM raw_trips;


-- 15. NEGATIVE FARE BY PAYMENT TYPE

SELECT
    payment_type,
    COUNT(*) AS negative_fare_records,
    ROUND(AVG(fare_amount), 2) AS average_negative_fare,
    ROUND(AVG(total_amount), 2) AS average_negative_total
FROM raw_trips
WHERE fare_amount < 0 OR total_amount < 0
GROUP BY payment_type
ORDER BY payment_type;


-- 16. CREATE SEPTEMBER AUDIT TABLE WITH QUALITY FLAGS

CREATE OR REPLACE TABLE september_trips_audit AS

WITH september_scope AS (
    SELECT *
    FROM raw_trips
    WHERE tpep_pickup_datetime >= TIMESTAMP '2026-09-01 00:00:00'
      AND tpep_pickup_datetime < TIMESTAMP '2026-10-01 00:00:00'
),

flagged AS (
    SELECT
        *,

        CASE
            WHEN tpep_dropoff_datetime <= tpep_pickup_datetime
            THEN TRUE ELSE FALSE
        END AS invalid_duration,

        CASE
            WHEN passenger_count IS NULL
            THEN TRUE ELSE FALSE
        END AS missing_passenger_count,

        CASE
            WHEN passenger_count = 0
              OR passenger_count < 0
              OR passenger_count > 6
            THEN TRUE ELSE FALSE
        END AS invalid_passenger_count,

        CASE
            WHEN trip_distance <= 0
              OR trip_distance > 100
            THEN TRUE ELSE FALSE
        END AS invalid_distance,

        CASE
            WHEN fare_amount < 0 OR total_amount < 0
            THEN TRUE ELSE FALSE
        END AS negative_amount

    FROM september_scope
)

SELECT
    *,
    CASE
        WHEN invalid_duration = FALSE
         AND invalid_passenger_count = FALSE
         AND invalid_distance = FALSE
         AND negative_amount = FALSE
        THEN TRUE
        ELSE FALSE
    END AS is_analysis_valid

FROM flagged;


-- 17. CREATE FINAL CLEANED TABLE

CREATE OR REPLACE TABLE cleaned_trips AS

SELECT *
FROM september_trips_audit
WHERE is_analysis_valid = TRUE;


-- 18. CLEANING SUMMARY

SELECT
    COUNT(*) AS september_audit_records,

    COUNT(*) FILTER (
        WHERE is_analysis_valid = TRUE
    ) AS valid_records,

    COUNT(*) FILTER (
        WHERE is_analysis_valid = FALSE
    ) AS excluded_records,

    COUNT(*) FILTER (
        WHERE missing_passenger_count = TRUE
    ) AS missing_passenger_records,

    COUNT(*) FILTER (
        WHERE invalid_passenger_count = TRUE
    ) AS invalid_passenger_records,

    COUNT(*) FILTER (
        WHERE invalid_duration = TRUE
    ) AS invalid_duration_records,

    COUNT(*) FILTER (
        WHERE invalid_distance = TRUE
    ) AS invalid_distance_records,

    COUNT(*) FILTER (
        WHERE negative_amount = TRUE
    ) AS negative_amount_records

FROM september_trips_audit;


-- 19. VERIFY FINAL CLEANED TABLE

SELECT
    COUNT(*) AS total_cleaned_records,
    MIN(tpep_pickup_datetime) AS first_pickup,
    MAX(tpep_pickup_datetime) AS last_pickup,
    ROUND(AVG(trip_distance), 2) AS average_distance,
    ROUND(AVG(total_amount), 2) AS average_total_amount
FROM cleaned_trips;

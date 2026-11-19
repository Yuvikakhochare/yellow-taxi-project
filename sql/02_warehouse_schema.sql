
-- ============================================================
-- NYC YELLOW TAXI PROJECT
-- 02 - WAREHOUSE SCHEMA
-- Source: cleaned_trips
-- Database: DuckDB
-- ============================================================


-- 1. DATE DIMENSION
-- Includes pickup and drop-off dates found in cleaned trips.

CREATE OR REPLACE TABLE dim_date AS

WITH date_bounds AS (
    SELECT
        CAST(MIN(tpep_pickup_datetime) AS DATE) AS min_date,
        CAST(MAX(tpep_dropoff_datetime) AS DATE) AS max_date
    FROM cleaned_trips
),

calendar AS (
    SELECT
    CAST(generated_date AS DATE) AS full_date
FROM date_bounds,
     generate_series(
         min_date,
         max_date,
         INTERVAL 1 DAY
     ) AS dates(generated_date)
)

SELECT
    CAST(strftime(full_date, '%Y%m%d') AS INTEGER) AS date_key,
    full_date,
    YEAR(full_date) AS year,
    MONTH(full_date) AS month,
    MONTHNAME(full_date) AS month_name,
    DAY(full_date) AS day,
    DAYNAME(full_date) AS day_name,
    DAYOFWEEK(full_date) AS day_of_week,
    CASE
        WHEN DAYOFWEEK(full_date) IN (0, 6) THEN TRUE
        ELSE FALSE
    END AS is_weekend
FROM calendar;


-- 2. VENDOR DIMENSION

CREATE OR REPLACE TABLE dim_vendor AS

SELECT DISTINCT
    VendorID AS vendor_id,

    CASE
        WHEN VendorID = 1 THEN 'Vendor 1'
        WHEN VendorID = 2 THEN 'Vendor 2'
        WHEN VendorID = 6 THEN 'Vendor 6'
        WHEN VendorID = 7 THEN 'Vendor 7'
        ELSE 'Other / Unknown Vendor'
    END AS vendor_name

FROM cleaned_trips;


-- 3. PAYMENT TYPE DIMENSION

CREATE OR REPLACE TABLE dim_payment_type AS

SELECT DISTINCT
    COALESCE(CAST(payment_type AS INTEGER), -1) AS payment_type_id,

    CASE
        WHEN payment_type = 0 THEN 'Flex Fare'
        WHEN payment_type = 1 THEN 'Credit Card'
        WHEN payment_type = 2 THEN 'Cash'
        WHEN payment_type = 3 THEN 'No Charge'
        WHEN payment_type = 4 THEN 'Dispute'
        WHEN payment_type = 5 THEN 'Unknown'
        WHEN payment_type = 6 THEN 'Voided Trip'
        ELSE 'Other / Unspecified'
    END AS payment_type_name

FROM cleaned_trips;


-- 4. LOCATION DIMENSION
-- One row per location ID, shared by pickup and drop-off roles.

CREATE OR REPLACE TABLE dim_location AS

SELECT
    -1 AS location_id,
    'Unknown / Missing Location' AS location_name

UNION

SELECT DISTINCT
    CAST(location_id AS INTEGER) AS location_id,
    'Location ID ' || CAST(location_id AS VARCHAR) AS location_name

FROM (
    SELECT PULocationID AS location_id
    FROM cleaned_trips

    UNION

    SELECT DOLocationID AS location_id
    FROM cleaned_trips
) locations

WHERE location_id IS NOT NULL;


-- 5. FACT TRIPS TABLE
-- One row represents one cleaned taxi trip.

CREATE OR REPLACE TABLE fact_trips AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY
            tpep_pickup_datetime,
            tpep_dropoff_datetime,
            VendorID,
            PULocationID,
            DOLocationID
    ) AS trip_key,

    CAST(
        strftime(tpep_pickup_datetime, '%Y%m%d')
        AS INTEGER
    ) AS pickup_date_key,

    CAST(
        strftime(tpep_dropoff_datetime, '%Y%m%d')
        AS INTEGER
    ) AS dropoff_date_key,

    COALESCE(CAST(VendorID AS INTEGER), -1) AS vendor_id,
    COALESCE(CAST(payment_type AS INTEGER), -1) AS payment_type_id,

    COALESCE(
        CAST(PULocationID AS INTEGER),
        -1
    ) AS pickup_location_id,

    COALESCE(
        CAST(DOLocationID AS INTEGER),
        -1
    ) AS dropoff_location_id,

    tpep_pickup_datetime AS pickup_datetime,

    tpep_dropoff_datetime AS dropoff_datetime,

    HOUR(tpep_pickup_datetime) AS pickup_hour,

    DATE_DIFF(
        'second',
        tpep_pickup_datetime,
        tpep_dropoff_datetime
    ) / 60.0 AS trip_duration_minutes,

    passenger_count,

    missing_passenger_count,

    trip_distance,

    fare_amount,

    extra,

    mta_tax,

    tip_amount,

    tolls_amount,

    improvement_surcharge,

    total_amount,

    congestion_surcharge,

    Airport_fee AS airport_fee,

    cbd_congestion_fee,

    store_and_fwd_flag,

    is_analysis_valid

FROM cleaned_trips
WHERE is_analysis_valid = TRUE;


-- ============================================================
-- 6. WAREHOUSE VERIFICATION
-- ============================================================

SELECT 'dim_date' AS table_name, COUNT(*) AS total_records
FROM dim_date

UNION ALL

SELECT 'dim_vendor', COUNT(*)
FROM dim_vendor

UNION ALL

SELECT 'dim_payment_type', COUNT(*)
FROM dim_payment_type

UNION ALL

SELECT 'dim_location', COUNT(*)
FROM dim_location

UNION ALL

SELECT 'fact_trips', COUNT(*)
FROM fact_trips;

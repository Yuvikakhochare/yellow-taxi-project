
-- ============================================================
-- MARROWGATE PEDAL LINK
-- CLIENT-SCOPED DATA WAREHOUSE
--
-- IMPORTANT:
-- All warehouse tables use client_in_scope_trips.
-- Out-of-scope trips are excluded from client reporting.
-- ============================================================


-- 1. DATE DIMENSION

CREATE OR REPLACE TABLE dim_calendar AS

WITH date_bounds AS (
    SELECT
        MIN(CAST(tpep_pickup_datetime AS DATE)) AS min_date,
        MAX(CAST(tpep_dropoff_datetime AS DATE)) AS max_date
    FROM client_in_scope_trips
),

calendar_dates AS (
    SELECT CAST(d AS DATE) AS calendar_date
    FROM date_bounds,
    GENERATE_SERIES(
        min_date,
        max_date,
        INTERVAL 1 DAY
    ) AS t(d)
)

SELECT
    CAST(STRFTIME(calendar_date, '%Y%m%d') AS INTEGER) AS date_key,
    calendar_date,
    EXTRACT(YEAR FROM calendar_date) AS year,
    EXTRACT(QUARTER FROM calendar_date) AS quarter,
    EXTRACT(MONTH FROM calendar_date) AS month,
    STRFTIME(calendar_date, '%B') AS month_name,
    EXTRACT(DAY FROM calendar_date) AS day,
    STRFTIME(calendar_date, '%A') AS day_name,
    EXTRACT(DOW FROM calendar_date) AS day_of_week,
    CASE
        WHEN EXTRACT(DOW FROM calendar_date) IN (0, 6)
        THEN TRUE
        ELSE FALSE
    END AS is_weekend

FROM calendar_dates;


-- 2. VENDOR DIMENSION

CREATE OR REPLACE TABLE dim_vendor AS

SELECT DISTINCT
    VendorID AS vendor_id,
    CASE
        WHEN VendorID IS NULL THEN 'Unknown'
        ELSE 'Vendor ' || CAST(VendorID AS VARCHAR)
    END AS vendor_name

FROM client_in_scope_trips

UNION ALL

SELECT
    -1,
    'Unknown'
WHERE NOT EXISTS (
    SELECT 1
    FROM client_in_scope_trips
    WHERE VendorID IS NULL
);


-- 3. PAYMENT TYPE DIMENSION

CREATE OR REPLACE TABLE dim_payment_type AS

SELECT DISTINCT
    payment_type,

    CASE
        WHEN payment_type = 1 THEN 'Credit Card'
        WHEN payment_type = 2 THEN 'Cash'
        WHEN payment_type = 3 THEN 'No Charge'
        WHEN payment_type = 4 THEN 'Dispute'
        WHEN payment_type = 5 THEN 'Unknown'
        WHEN payment_type = 6 THEN 'Voided Trip'
        ELSE 'Other / Missing'
    END AS payment_type_name

FROM client_in_scope_trips;


-- 4. ZONE DIMENSION

CREATE OR REPLACE TABLE dim_zones AS

WITH zone_ids AS (

    SELECT PULocationID AS zone_id
    FROM client_in_scope_trips
    WHERE PULocationID IS NOT NULL

    UNION

    SELECT DOLocationID AS zone_id
    FROM client_in_scope_trips
    WHERE DOLocationID IS NOT NULL
)

SELECT
    zone_id,
    'Zone ID ' || CAST(zone_id AS VARCHAR) AS zone_name

FROM zone_ids

UNION ALL

SELECT
    -1,
    'Unknown / Missing Zone'

WHERE EXISTS (
    SELECT 1
    FROM client_in_scope_trips
    WHERE PULocationID IS NULL
       OR DOLocationID IS NULL
);


-- 5. FACT TRIPS TABLE

CREATE OR REPLACE TABLE fact_trips AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY tpep_pickup_datetime,
                 tpep_dropoff_datetime
    ) AS trip_id,

    CAST(
        STRFTIME(tpep_pickup_datetime, '%Y%m%d')
        AS INTEGER
    ) AS pickup_date_key,

    CAST(
        STRFTIME(tpep_dropoff_datetime, '%Y%m%d')
        AS INTEGER
    ) AS dropoff_date_key,

    COALESCE(VendorID, -1) AS vendor_id,

    COALESCE(PULocationID, -1) AS pickup_zone_id,

    COALESCE(DOLocationID, -1) AS dropoff_zone_id,

    payment_type,

    tpep_pickup_datetime,
    tpep_dropoff_datetime,

    EXTRACT(
        HOUR FROM tpep_pickup_datetime
    ) AS pickup_hour,

    duration_minutes AS trip_duration_minutes,

    passenger_count,
    trip_distance,

    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    congestion_surcharge,
    Airport_fee,
    cbd_congestion_fee,
    total_amount

FROM client_in_scope_trips;


-- 6. HOURLY DEMAND PER ZONE

CREATE OR REPLACE TABLE hourly_demand_per_zone AS

SELECT
    CAST(tpep_pickup_datetime AS DATE) AS pickup_date,

    EXTRACT(
        HOUR FROM tpep_pickup_datetime
    ) AS pickup_hour,

    COALESCE(PULocationID, -1) AS pickup_zone_id,

    COUNT(*) AS total_trips,

    SUM(passenger_count) AS total_passengers,

    AVG(duration_minutes) AS average_duration_minutes,

    AVG(trip_distance) AS average_trip_distance

FROM client_in_scope_trips

GROUP BY
    CAST(tpep_pickup_datetime AS DATE),
    EXTRACT(HOUR FROM tpep_pickup_datetime),
    COALESCE(PULocationID, -1);


-- 7. REVENUE BY PICKUP ZONE
-- Excluding tolls and surcharges:
-- Fare + tips
--
-- Including tolls and surcharges:
-- Fare + tips + tolls + all listed surcharge components

CREATE OR REPLACE TABLE revenue_by_zone AS

SELECT
    COALESCE(PULocationID, -1) AS pickup_zone_id,

    COUNT(*) AS total_trips,

    SUM(COALESCE(fare_amount, 0)) AS base_fare_revenue,

    SUM(
        COALESCE(fare_amount, 0)
        + COALESCE(tip_amount, 0)
    ) AS revenue_without_tolls_surcharges,

    SUM(
        COALESCE(fare_amount, 0)
        + COALESCE(tip_amount, 0)
        + COALESCE(tolls_amount, 0)
        + COALESCE(extra, 0)
        + COALESCE(mta_tax, 0)
        + COALESCE(improvement_surcharge, 0)
        + COALESCE(congestion_surcharge, 0)
        + COALESCE(Airport_fee, 0)
        + COALESCE(cbd_congestion_fee, 0)
    ) AS revenue_with_tolls_surcharges

FROM client_in_scope_trips

GROUP BY COALESCE(PULocationID, -1);


-- 8. WAREHOUSE TABLE COUNTS

SELECT 'dim_calendar' AS table_name,
       COUNT(*) AS total_records
FROM dim_calendar

UNION ALL

SELECT 'dim_vendor', COUNT(*)
FROM dim_vendor

UNION ALL

SELECT 'dim_payment_type', COUNT(*)
FROM dim_payment_type

UNION ALL

SELECT 'dim_zones', COUNT(*)
FROM dim_zones

UNION ALL

SELECT 'fact_trips', COUNT(*)
FROM fact_trips

UNION ALL

SELECT 'hourly_demand_per_zone', COUNT(*)
FROM hourly_demand_per_zone

UNION ALL

SELECT 'revenue_by_zone', COUNT(*)
FROM revenue_by_zone;


-- 9. VERIFY CLIENT SCOPE RECONCILIATION

SELECT
    (SELECT COUNT(*) FROM client_in_scope_trips)
        AS client_approved_trips,

    (SELECT COUNT(*) FROM fact_trips)
        AS warehouse_fact_trips,

    (SELECT COUNT(*) FROM client_in_scope_trips)
    -
    (SELECT COUNT(*) FROM fact_trips)
        AS reconciliation_difference;


-- 10. VERIFY NO OUT-OF-SCOPE TRIPS IN FACT TABLE

SELECT
    COUNT(*) AS invalid_scope_records

FROM fact_trips

WHERE trip_distance >= 3
  AND trip_duration_minutes >= 20;


-- 11. SAMPLE HOURLY DEMAND

SELECT *
FROM hourly_demand_per_zone
ORDER BY pickup_date, pickup_hour
LIMIT 10;


-- 12. SAMPLE REVENUE BY ZONE

SELECT *
FROM revenue_by_zone
ORDER BY revenue_with_tolls_surcharges DESC
LIMIT 10;

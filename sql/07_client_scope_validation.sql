
-- ============================================================
-- MARROWGATE PEDAL LINK
-- CLIENT SHORT-HOP SCOPE
--
-- Keep trips if:
-- Distance < 3 miles OR Duration < 20 minutes
--
-- Exclude trips if:
-- Distance >= 3 miles AND Duration >= 20 minutes
--
-- Exclusion reason:
-- LONG_TRIP_OUT_OF_SCOPE
-- ============================================================


-- 1. Classify analysis-valid cleaned trips

CREATE OR REPLACE TABLE client_scope_trips AS

WITH trip_details AS (

    SELECT
        *,

        DATE_DIFF(
            'second',
            tpep_pickup_datetime,
            tpep_dropoff_datetime
        ) / 60.0 AS duration_minutes,

        CASE
            WHEN tpep_pickup_datetime IS NULL
            THEN 'UNKNOWN'
            ELSE STRFTIME(tpep_pickup_datetime, '%Y-%m')
        END AS trip_month

    FROM cleaned_trips

    WHERE is_analysis_valid = TRUE
)

SELECT
    *,

    CASE
        WHEN COALESCE(trip_distance < 3, FALSE)
          OR COALESCE(duration_minutes < 20, FALSE)
        THEN 'IN_SCOPE'
        ELSE 'OUT_OF_SCOPE'
    END AS scope_status,

    CASE
        WHEN COALESCE(trip_distance < 3, FALSE)
          OR COALESCE(duration_minutes < 20, FALSE)
        THEN NULL
        ELSE 'LONG_TRIP_OUT_OF_SCOPE'
    END AS scope_reason_code

FROM trip_details;


-- 2. Create accepted in-scope trips

CREATE OR REPLACE TABLE client_in_scope_trips AS

SELECT *
FROM client_scope_trips
WHERE scope_status = 'IN_SCOPE';


-- 3. Create excluded out-of-scope trips

CREATE OR REPLACE TABLE client_out_of_scope_trips AS

SELECT *
FROM client_scope_trips
WHERE scope_status = 'OUT_OF_SCOPE';


-- 4. Create monthly client scope run log

CREATE OR REPLACE TABLE client_scope_run_log AS

SELECT
    trip_month AS month,

    COUNT(*) AS source_rows,

    COUNT(*) FILTER (
        WHERE scope_status = 'IN_SCOPE'
    ) AS in_scope_rows,

    COUNT(*) FILTER (
        WHERE scope_status = 'OUT_OF_SCOPE'
    ) AS out_of_scope_rows,

    COUNT(*) FILTER (
        WHERE scope_reason_code = 'LONG_TRIP_OUT_OF_SCOPE'
    ) AS long_trip_out_of_scope_count,

    COUNT(*) -
    COUNT(*) FILTER (
        WHERE scope_status = 'IN_SCOPE'
    ) -
    COUNT(*) FILTER (
        WHERE scope_status = 'OUT_OF_SCOPE'
    ) AS reconciliation_difference

FROM client_scope_trips

GROUP BY trip_month
ORDER BY trip_month;


-- 5. Create overall client scope summary

CREATE OR REPLACE TABLE client_scope_summary AS

SELECT
    COUNT(*) AS total_source_rows,

    COUNT(*) FILTER (
        WHERE scope_status = 'IN_SCOPE'
    ) AS in_scope_rows,

    COUNT(*) FILTER (
        WHERE scope_status = 'OUT_OF_SCOPE'
    ) AS out_of_scope_rows,

    COUNT(*) FILTER (
        WHERE scope_reason_code = 'LONG_TRIP_OUT_OF_SCOPE'
    ) AS long_trip_out_of_scope_count,

    COUNT(*) -
    COUNT(*) FILTER (
        WHERE scope_status = 'IN_SCOPE'
    ) -
    COUNT(*) FILTER (
        WHERE scope_status = 'OUT_OF_SCOPE'
    ) AS reconciliation_difference

FROM client_scope_trips;


-- 6. Create exclusion reason summary

CREATE OR REPLACE TABLE client_scope_reason_summary AS

SELECT
    scope_reason_code AS reason_code,
    COUNT(*) AS excluded_records

FROM client_out_of_scope_trips

GROUP BY scope_reason_code;


-- 7. Display overall client scope summary

SELECT *
FROM client_scope_summary;


-- 8. Display exclusion reason counts

SELECT *
FROM client_scope_reason_summary;


-- 9. Display monthly run log

SELECT *
FROM client_scope_run_log
ORDER BY month;


-- 10. Verify no excluded trips remain in accepted data
-- Expected result: 0

SELECT
    COUNT(*) AS invalid_scope_records

FROM client_in_scope_trips

WHERE trip_distance >= 3
  AND duration_minutes >= 20;


-- 11. Verify reconciliation
-- Expected result: 0

SELECT
    total_source_rows,
    in_scope_rows,
    out_of_scope_rows,
    reconciliation_difference

FROM client_scope_summary;

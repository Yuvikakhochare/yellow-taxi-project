
-- Check required warehouse tables

SELECT 'dim_calendar' AS table_name, COUNT(*) AS records
FROM dim_calendar

UNION ALL

SELECT 'dim_zones', COUNT(*)
FROM dim_zones

UNION ALL

SELECT 'fact_trips', COUNT(*)
FROM fact_trips

UNION ALL

SELECT 'hourly_demand_per_zone', COUNT(*)
FROM hourly_demand_per_zone;


-- Check hourly demand sample

SELECT *
FROM hourly_demand_per_zone
ORDER BY demand_date, pickup_hour
LIMIT 10;


-- Check fact trips sample

SELECT *
FROM fact_trips
LIMIT 10;


-- Check reconciliation

SELECT
    (SELECT COUNT(*)
     FROM cleaned_trips
     WHERE is_analysis_valid = TRUE) AS valid_trips,

    (SELECT COUNT(*)
     FROM fact_trips) AS fact_trips,

    (SELECT COUNT(*)
     FROM cleaned_trips
     WHERE is_analysis_valid = TRUE)
    -
    (SELECT COUNT(*)
     FROM fact_trips) AS difference;

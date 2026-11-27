-- 1. Check revenue table structure
DESCRIBE revenue_by_zone;

-- 2. Check total number of pickup zones
SELECT COUNT(*) AS total_revenue_zones
FROM revenue_by_zone;

-- 3. Check duplicate pickup zones
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT pickup_zone_id) AS unique_zones,
    COUNT(*) - COUNT(DISTINCT pickup_zone_id) AS duplicate_rows
FROM revenue_by_zone;

-- 4. Check missing pickup zone IDs
SELECT COUNT(*) AS missing_zone_ids
FROM revenue_by_zone
WHERE pickup_zone_id IS NULL;

-- 5. Compare revenue table trip count with fact table
SELECT
    (SELECT COUNT(*) FROM fact_trips) AS fact_trip_count,
    (SELECT SUM(total_trips) FROM revenue_by_zone) AS revenue_table_trip_count,
    (SELECT COUNT(*) FROM fact_trips) -
    (SELECT SUM(total_trips) FROM revenue_by_zone) AS difference;
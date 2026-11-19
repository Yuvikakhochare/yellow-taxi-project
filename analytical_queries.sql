
-- ============================================================
-- YELLOW TAXI DATA ANALYTICS PROJECT
-- FILE: 03_analytical_queries.sql
-- DATABASE: DuckDB
-- PURPOSE: BUSINESS AND DATA ANALYSIS
-- ============================================================


-- ============================================================
-- 1. OVERALL BUSINESS PERFORMANCE
-- ============================================================

SELECT
    COUNT(*) AS total_trips,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_trip_amount,
    ROUND(AVG(trip_distance), 2) AS avg_trip_distance,
    ROUND(AVG(trip_duration_minutes), 2) AS avg_duration_minutes,
    ROUND(AVG(tip_amount), 2) AS avg_tip
FROM fact_trips
WHERE is_analysis_valid = TRUE;


-- ============================================================
-- 2. HOURLY TRIP DEMAND ANALYSIS
-- ============================================================

SELECT
    pickup_hour,
    COUNT(*) AS total_trips,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    ROUND(AVG(total_amount), 2) AS avg_trip_amount
FROM fact_trips
WHERE is_analysis_valid = TRUE
GROUP BY pickup_hour
ORDER BY pickup_hour;


-- ============================================================
-- 3. DAILY TRIP AND REVENUE TRENDS
-- ============================================================

SELECT
    d.full_date,
    d.day_name,
    COUNT(*) AS total_trips,
    ROUND(SUM(f.total_amount), 2) AS total_revenue,
    ROUND(AVG(f.total_amount), 2) AS avg_trip_amount
FROM fact_trips f
JOIN dim_date d
    ON f.pickup_date_key = d.date_key
WHERE f.is_analysis_valid = TRUE
GROUP BY
    d.full_date,
    d.day_name
ORDER BY d.full_date;


-- ============================================================
-- 4. VENDOR PERFORMANCE ANALYSIS
-- ============================================================

SELECT
    v.vendor_name,
    COUNT(*) AS total_trips,
    ROUND(SUM(f.total_amount), 2) AS total_revenue,
    ROUND(AVG(f.total_amount), 2) AS avg_trip_amount,
    ROUND(AVG(f.trip_distance), 2) AS avg_distance,
    ROUND(AVG(f.tip_amount), 2) AS avg_tip
FROM fact_trips f
JOIN dim_vendor v
    ON f.vendor_id = v.vendor_id
WHERE f.is_analysis_valid = TRUE
GROUP BY v.vendor_name
ORDER BY total_revenue DESC;


-- ============================================================
-- 5. PAYMENT TYPE ANALYSIS
-- ============================================================

SELECT
    p.payment_type_name,
    COUNT(*) AS total_trips,
    ROUND(SUM(f.total_amount), 2) AS total_revenue,
    ROUND(AVG(f.total_amount), 2) AS avg_trip_amount,
    ROUND(AVG(f.tip_amount), 2) AS avg_tip
FROM fact_trips f
JOIN dim_payment_type p
    ON f.payment_type_id = p.payment_type_id
WHERE f.is_analysis_valid = TRUE
GROUP BY p.payment_type_name
ORDER BY total_trips DESC;


-- ============================================================
-- 6. TOP 10 PICKUP LOCATIONS
-- ============================================================

SELECT
    l.location_name,
    COUNT(*) AS total_pickups,
    ROUND(SUM(f.total_amount), 2) AS total_revenue,
    ROUND(AVG(f.total_amount), 2) AS avg_trip_amount
FROM fact_trips f
JOIN dim_location l
    ON f.pickup_location_id = l.location_id
WHERE f.is_analysis_valid = TRUE
GROUP BY l.location_name
ORDER BY total_pickups DESC
LIMIT 10;


-- ============================================================
-- 7. TOP 10 DROPOFF LOCATIONS
-- ============================================================

SELECT
    l.location_name,
    COUNT(*) AS total_dropoffs,
    ROUND(SUM(f.total_amount), 2) AS total_revenue,
    ROUND(AVG(f.trip_distance), 2) AS avg_distance
FROM fact_trips f
JOIN dim_location l
    ON f.dropoff_location_id = l.location_id
WHERE f.is_analysis_valid = TRUE
GROUP BY l.location_name
ORDER BY total_dropoffs DESC
LIMIT 10;


-- ============================================================
-- 8. WEEKDAY VS WEEKEND ANALYSIS
-- ============================================================

SELECT
    CASE
        WHEN d.is_weekend = TRUE THEN 'Weekend'
        ELSE 'Weekday'
    END AS day_type,

    COUNT(*) AS total_trips,

    ROUND(SUM(f.total_amount), 2) AS total_revenue,

    ROUND(AVG(f.total_amount), 2) AS avg_trip_amount,

    ROUND(AVG(f.trip_distance), 2) AS avg_distance

FROM fact_trips f
JOIN dim_date d
    ON f.pickup_date_key = d.date_key

WHERE f.is_analysis_valid = TRUE

GROUP BY day_type
ORDER BY total_trips DESC;


-- ============================================================
-- 9. TRIP DISTANCE CATEGORY ANALYSIS
-- ============================================================

SELECT
    CASE
        WHEN trip_distance <= 2 THEN '0-2 Miles'
        WHEN trip_distance <= 5 THEN '2-5 Miles'
        WHEN trip_distance <= 10 THEN '5-10 Miles'
        WHEN trip_distance <= 20 THEN '10-20 Miles'
        ELSE 'Above 20 Miles'
    END AS distance_category,

    COUNT(*) AS total_trips,

    ROUND(AVG(total_amount), 2) AS avg_trip_amount,

    ROUND(AVG(trip_duration_minutes), 2) AS avg_duration,

    ROUND(SUM(total_amount), 2) AS total_revenue

FROM fact_trips

WHERE is_analysis_valid = TRUE

GROUP BY distance_category
ORDER BY MIN(trip_distance);


-- ============================================================
-- 10. TIP ANALYSIS BY PAYMENT TYPE
-- ============================================================

SELECT
    p.payment_type_name,

    COUNT(*) AS total_trips,

    ROUND(SUM(f.tip_amount), 2) AS total_tips,

    ROUND(AVG(f.tip_amount), 2) AS avg_tip,

    ROUND(
        100.0 * SUM(f.tip_amount)
        / NULLIF(SUM(f.fare_amount), 0),
        2
    ) AS tip_percentage_of_fare

FROM fact_trips f

JOIN dim_payment_type p
    ON f.payment_type_id = p.payment_type_id

WHERE f.is_analysis_valid = TRUE

GROUP BY p.payment_type_name

ORDER BY total_tips DESC;


-- ============================================================
-- END OF ANALYTICAL SQL QUERIES
-- ============================================================

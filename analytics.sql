
-- 1. Total trips
SELECT COUNT(*) AS total_trips
FROM yellow_taxi_cleaned;

-- 2. Total revenue
SELECT ROUND(SUM(total_amount), 2) AS total_revenue
FROM yellow_taxi_cleaned;

-- 3. Average fare
SELECT ROUND(AVG(fare_amount), 2) AS average_fare
FROM yellow_taxi_cleaned;

-- 4. Average trip distance
SELECT ROUND(AVG(trip_distance), 2) AS average_distance
FROM yellow_taxi_cleaned;

-- 5. Average trip duration in minutes
SELECT ROUND(
    AVG(
        date_diff(
            'second',
            tpep_pickup_datetime,
            tpep_dropoff_datetime
        )
    ) / 60.0,
    2
) AS average_duration_minutes
FROM yellow_taxi_cleaned;

-- 6. Daily trips and revenue
SELECT
    CAST(tpep_pickup_datetime AS DATE) AS trip_date,
    COUNT(*) AS total_trips,
    ROUND(SUM(total_amount), 2) AS revenue
FROM yellow_taxi_cleaned
GROUP BY trip_date
ORDER BY trip_date;

-- 7. Trips by pickup hour
SELECT
    EXTRACT(HOUR FROM tpep_pickup_datetime) AS pickup_hour,
    COUNT(*) AS total_trips
FROM yellow_taxi_cleaned
GROUP BY pickup_hour
ORDER BY pickup_hour;

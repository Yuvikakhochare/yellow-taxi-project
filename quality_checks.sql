
-- Total cleaned records
SELECT COUNT(*) AS cleaned_records
FROM yellow_taxi_cleaned;

-- Missing timestamps
SELECT COUNT(*) AS missing_timestamps
FROM yellow_taxi_cleaned
WHERE
    tpep_pickup_datetime IS NULL
    OR tpep_dropoff_datetime IS NULL;

-- Invalid timestamp order
SELECT COUNT(*) AS invalid_timestamps
FROM yellow_taxi_cleaned
WHERE tpep_dropoff_datetime <= tpep_pickup_datetime;

-- Invalid passenger count
SELECT COUNT(*) AS invalid_passengers
FROM yellow_taxi_cleaned
WHERE passenger_count NOT BETWEEN 1 AND 6;

-- Invalid distance
SELECT COUNT(*) AS invalid_distance
FROM yellow_taxi_cleaned
WHERE trip_distance <= 0;

-- Invalid monetary values
SELECT COUNT(*) AS invalid_monetary_records
FROM yellow_taxi_cleaned
WHERE fare_amount < 0 OR total_amount < 0;

-- Exact duplicate check
SELECT
    COUNT(*) - COUNT(DISTINCT hash(*)) AS duplicate_count
FROM yellow_taxi_cleaned;

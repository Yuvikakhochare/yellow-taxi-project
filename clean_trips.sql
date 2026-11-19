
CREATE OR REPLACE TABLE yellow_taxi_cleaned AS
SELECT DISTINCT *
FROM raw_trips
WHERE
    tpep_pickup_datetime IS NOT NULL
    AND tpep_dropoff_datetime IS NOT NULL

    AND tpep_dropoff_datetime > tpep_pickup_datetime

    AND passenger_count BETWEEN 1 AND 6

    AND trip_distance > 0

    AND fare_amount >= 0
    AND total_amount >= 0;

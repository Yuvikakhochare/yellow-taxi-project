
import duckdb
import os
import csv

# ============================================================
# MARROWGATE PEDAL LINK
# CLIENT-SCOPED BUSINESS METRICS
# ============================================================

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DB_PATH = os.path.join(BASE_DIR, "data", "yellow_taxi.duckdb")

OUTPUT_DIR = os.path.join(BASE_DIR, "logs")

os.makedirs(OUTPUT_DIR, exist_ok=True)

# Connect to DuckDB
con = duckdb.connect(DB_PATH, read_only=True)

# Calculate business metrics using client-approved trips
query = """
WITH trip_metrics AS (

    SELECT
        COUNT(*) AS total_trips,

        SUM(COALESCE(fare_amount, 0))
            AS base_fare_revenue,

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
        ) AS revenue_with_tolls_surcharges,

        AVG(fare_amount) AS average_fare,

        AVG(duration_minutes) AS average_duration_minutes

    FROM client_in_scope_trips
),

zone_hours AS (

    SELECT
        COUNT(*) AS active_zone_hours

    FROM (
        SELECT DISTINCT
            PULocationID,
            CAST(tpep_pickup_datetime AS DATE) AS pickup_date,
            EXTRACT(HOUR FROM tpep_pickup_datetime) AS pickup_hour

        FROM client_in_scope_trips

        WHERE PULocationID IS NOT NULL
          AND tpep_pickup_datetime IS NOT NULL
    ) AS active_hours
),

duration_total AS (

    SELECT
        SUM(duration_minutes) AS total_duration_minutes

    FROM client_in_scope_trips
)

SELECT
    t.total_trips,
    t.base_fare_revenue,
    t.revenue_without_tolls_surcharges,
    t.revenue_with_tolls_surcharges,
    t.average_fare,
    t.average_duration_minutes,

    d.total_duration_minutes,

    z.active_zone_hours,

    CASE
        WHEN z.active_zone_hours > 0
        THEN d.total_duration_minutes /
             (z.active_zone_hours * 60.0)
        ELSE NULL
    END AS utilisation_proxy

FROM trip_metrics t
CROSS JOIN zone_hours z
CROSS JOIN duration_total d;
"""

# Execute query
result = con.execute(query).fetchdf()

# Display results
print("\n==============================================")
print(" MARROWGATE PEDAL LINK - BUSINESS METRICS")
print("==============================================\n")

print(result.to_string(index=False))

# Export metrics to CSV
output_file = os.path.join(OUTPUT_DIR, "business_metrics.csv")

result.to_csv(output_file, index=False)

print("\n==============================================")
print("METRICS CALCULATED SUCCESSFULLY!")
print("==============================================")

print(f"\nOutput saved to: {output_file}")

con.close()

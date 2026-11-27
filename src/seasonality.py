
import duckdb
import pandas as pd
import matplotlib.pyplot as plt
import os

# ============================================================
# MARROWGATE PEDAL LINK
# CLIENT-SCOPED SEASONALITY ANALYSIS
# ============================================================

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DB_PATH = os.path.join(BASE_DIR, "data", "yellow_taxi.duckdb")
REPORT_DIR = os.path.join(BASE_DIR, "reports")
LOG_DIR = os.path.join(BASE_DIR, "logs")

os.makedirs(REPORT_DIR, exist_ok=True)
os.makedirs(LOG_DIR, exist_ok=True)

con = duckdb.connect(DB_PATH, read_only=True)

print("\n==============================================")
print(" MARROWGATE PEDAL LINK - SEASONALITY ANALYSIS")
print("==============================================\n")


# ------------------------------------------------------------
# 1. HOURLY DEMAND
# ------------------------------------------------------------

hourly = con.execute("""
    SELECT
        EXTRACT(HOUR FROM tpep_pickup_datetime) AS pickup_hour,
        COUNT(*) AS total_trips
    FROM client_in_scope_trips
    WHERE tpep_pickup_datetime IS NOT NULL
    GROUP BY pickup_hour
    ORDER BY pickup_hour
""").fetchdf()

plt.figure(figsize=(10, 5))
plt.bar(hourly["pickup_hour"], hourly["total_trips"])
plt.title("Trip Demand by Hour")
plt.xlabel("Pickup Hour")
plt.ylabel("Total Trips")
plt.xticks(range(24))
plt.tight_layout()
plt.savefig(os.path.join(REPORT_DIR, "hourly_demand.png"))
plt.close()


# ------------------------------------------------------------
# 2. WEEKDAY DEMAND
# ------------------------------------------------------------

weekday = con.execute("""
    SELECT
        STRFTIME(tpep_pickup_datetime, '%A') AS weekday,
        EXTRACT(DOW FROM tpep_pickup_datetime) AS weekday_number,
        COUNT(*) AS total_trips
    FROM client_in_scope_trips
    WHERE tpep_pickup_datetime IS NOT NULL
    GROUP BY weekday, weekday_number
    ORDER BY
        CASE EXTRACT(DOW FROM tpep_pickup_datetime)
            WHEN 1 THEN 1
            WHEN 2 THEN 2
            WHEN 3 THEN 3
            WHEN 4 THEN 4
            WHEN 5 THEN 5
            WHEN 6 THEN 6
            WHEN 0 THEN 7
        END
""").fetchdf()

plt.figure(figsize=(10, 5))
plt.bar(weekday["weekday"], weekday["total_trips"])
plt.title("Trip Demand by Weekday")
plt.xlabel("Weekday")
plt.ylabel("Total Trips")
plt.xticks(rotation=30)
plt.tight_layout()
plt.savefig(os.path.join(REPORT_DIR, "weekday_demand.png"))
plt.close()


# ------------------------------------------------------------
# 3. MONTHLY DEMAND
# ------------------------------------------------------------

monthly = con.execute("""
    SELECT
        STRFTIME(tpep_pickup_datetime, '%Y-%m') AS trip_month,
        COUNT(*) AS total_trips
    FROM client_in_scope_trips
    WHERE tpep_pickup_datetime IS NOT NULL
    GROUP BY STRFTIME(tpep_pickup_datetime, '%Y-%m')
    ORDER BY trip_month
""").fetchdf()

plt.figure(figsize=(10, 5))
plt.plot(
    monthly["trip_month"],
    monthly["total_trips"],
    marker="o"
)
plt.title("Trip Demand by Month")
plt.xlabel("Month")
plt.ylabel("Total Trips")
plt.xticks(rotation=30)
plt.tight_layout()
plt.savefig(os.path.join(REPORT_DIR, "monthly_demand.png"))
plt.close()


# ------------------------------------------------------------
# 4. TOP 10 PICKUP ZONES
# ------------------------------------------------------------

top_zones = con.execute("""
    SELECT
        COALESCE(PULocationID, -1) AS pickup_zone_id,
        COUNT(*) AS total_trips
    FROM client_in_scope_trips
    GROUP BY pickup_zone_id
    ORDER BY total_trips DESC
    LIMIT 10
""").fetchdf()

plt.figure(figsize=(10, 5))
plt.bar(
    top_zones["pickup_zone_id"].astype(str),
    top_zones["total_trips"]
)
plt.title("Top 10 Pickup Zones")
plt.xlabel("Pickup Zone ID")
plt.ylabel("Total Trips")
plt.tight_layout()
plt.savefig(os.path.join(REPORT_DIR, "top_10_zones.png"))
plt.close()


# ------------------------------------------------------------
# 5. BOTTOM 10 PICKUP ZONES
# ------------------------------------------------------------

bottom_zones = con.execute("""
    SELECT
        COALESCE(PULocationID, -1) AS pickup_zone_id,
        COUNT(*) AS total_trips
    FROM client_in_scope_trips
    GROUP BY pickup_zone_id
    ORDER BY total_trips ASC, pickup_zone_id ASC
    LIMIT 10
""").fetchdf()

plt.figure(figsize=(10, 5))
plt.bar(
    bottom_zones["pickup_zone_id"].astype(str),
    bottom_zones["total_trips"]
)
plt.title("Bottom 10 Pickup Zones")
plt.xlabel("Pickup Zone ID")
plt.ylabel("Total Trips")
plt.tight_layout()
plt.savefig(os.path.join(REPORT_DIR, "bottom_10_zones.png"))
plt.close()


# ------------------------------------------------------------
# 6. ANOMALY DETECTION USING IQR
# ------------------------------------------------------------

def detect_anomalies(data, value_column, category_column, category_name):

    q1 = data[value_column].quantile(0.25)
    q3 = data[value_column].quantile(0.75)

    iqr = q3 - q1

    lower_limit = q1 - (1.5 * iqr)
    upper_limit = q3 + (1.5 * iqr)

    result = data.copy()

    result["lower_limit"] = lower_limit
    result["upper_limit"] = upper_limit

    result["is_anomaly"] = (
        (result[value_column] < lower_limit)
        | (result[value_column] > upper_limit)
    )

    result["analysis_category"] = category_name

    result = result.rename(
        columns={
            category_column: "category",
            value_column: "total_trips"
        }
    )

    return result[
        [
            "analysis_category",
            "category",
            "total_trips",
            "lower_limit",
            "upper_limit",
            "is_anomaly"
        ]
    ]


hourly_anomalies = detect_anomalies(
    hourly,
    "total_trips",
    "pickup_hour",
    "Hourly Demand"
)

weekday_anomalies = detect_anomalies(
    weekday,
    "total_trips",
    "weekday",
    "Weekday Demand"
)

anomalies = pd.concat(
    [hourly_anomalies, weekday_anomalies],
    ignore_index=True
)

anomalies.to_csv(
    os.path.join(LOG_DIR, "seasonality_anomalies.csv"),
    index=False
)


# ------------------------------------------------------------
# 7. EXPORT SEASONALITY DATA
# ------------------------------------------------------------

hourly.to_csv(
    os.path.join(REPORT_DIR, "hourly_demand.csv"),
    index=False
)

weekday.to_csv(
    os.path.join(REPORT_DIR, "weekday_demand.csv"),
    index=False
)

monthly.to_csv(
    os.path.join(REPORT_DIR, "monthly_demand.csv"),
    index=False
)

top_zones.to_csv(
    os.path.join(REPORT_DIR, "top_10_zones.csv"),
    index=False
)

bottom_zones.to_csv(
    os.path.join(REPORT_DIR, "bottom_10_zones.csv"),
    index=False
)


# ------------------------------------------------------------
# 8. CREATE DECISION LOG
# ------------------------------------------------------------

anomaly_count = int(anomalies["is_anomaly"].sum())

month_count = len(monthly)

decision_log = f"""
# Marrowgate Pedal Link - Seasonality Decision Log

## Data scope

All analysis uses client_in_scope_trips.

Approved trips: {con.execute(
    "SELECT COUNT(*) FROM client_in_scope_trips"
).fetchone()[0]:,}

## Analysis performed

1. Hourly demand
2. Weekday demand
3. Monthly demand
4. Top 10 pickup zones
5. Bottom 10 pickup zones

## Anomaly detection

Method: Interquartile Range (IQR).

Lower threshold = Q1 - 1.5 * IQR

Upper threshold = Q3 + 1.5 * IQR

Anomalies detected in hourly and weekday demand:
{anomaly_count}

## Anomaly handling

- Anomalies are flagged for investigation.
- Original trip records are not deleted.
- Unusual demand values are retained unless a data-quality
  issue is independently confirmed.
- No demand value is changed just because it is unusual.

## Monthly analysis limitation

Number of observed months: {month_count}

Monthly demand is reported descriptively.
A single observed month is insufficient to establish
seasonality or a reliable monthly trend.

## Reporting decision

All charts and demand summaries use client-approved trips.
Out-of-scope trips are excluded from reporting.
Zone results use pickup zone IDs.
"""

with open(
    os.path.join(LOG_DIR, "seasonality_decision_log.md"),
    "w",
    encoding="utf-8"
) as file:
    file.write(decision_log)


# ------------------------------------------------------------
# 9. DISPLAY RESULTS
# ------------------------------------------------------------

print("HOURLY DEMAND")
print(hourly.to_string(index=False))

print("\nWEEKDAY DEMAND")
print(weekday.to_string(index=False))

print("\nMONTHLY DEMAND")
print(monthly.to_string(index=False))

print("\nTOP 10 PICKUP ZONES")
print(top_zones.to_string(index=False))

print("\nBOTTOM 10 PICKUP ZONES")
print(bottom_zones.to_string(index=False))

print("\nANOMALY SUMMARY")
print(anomalies.to_string(index=False))

print("\n==============================================")
print("SEASONALITY ANALYSIS COMPLETED SUCCESSFULLY!")
print("==============================================")

print(f"\nCharts and CSV files saved in: {REPORT_DIR}")
print(f"Anomaly and decision logs saved in: {LOG_DIR}")

con.close()

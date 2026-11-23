
# Marrowgate Pedal Link - Seasonality Decision Log

## Data scope

All analysis uses client_in_scope_trips.

Approved trips: 2,678,614

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
0

## Anomaly handling

- Anomalies are flagged for investigation.
- Original trip records are not deleted.
- Unusual demand values are retained unless a data-quality
  issue is independently confirmed.
- No demand value is changed just because it is unusual.

## Monthly analysis limitation

Number of observed months: 1

Monthly demand is reported descriptively.
A single observed month is insufficient to establish
seasonality or a reliable monthly trend.

## Reporting decision

All charts and demand summaries use client-approved trips.
Out-of-scope trips are excluded from reporting.
Zone results use pickup zone IDs.

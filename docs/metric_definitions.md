
Marrowgate Pedal Link – Metric Definitions

1. Data Scope

All client-facing metrics are calculated using `client_in_scope_trips`.

Client filtering rule:

- Keep trips shorter than 3 miles OR shorter than 20 minutes.
- Exclude trips that are 3 miles or longer AND 20 minutes or longer.
- Exclusion reason: LONG_TRIP_OUT_OF_SCOPE.

Total approved trips: 2,678,614.

2. Trips

Definition:
Total number of client-approved trips.

Calculation:
COUNT(*)

Source:
client_in_scope_trips

3. Revenue

Three revenue measures are reported.

Base Fare Revenue

Definition:
Total fare amount collected before tips, tolls and surcharges.

Calculation:
SUM(fare_amount)

Revenue Without Tolls and Surcharges

Definition:
Fare amount plus tips, excluding tolls, taxes and surcharges.

Calculation:
SUM(fare_amount + tip_amount)

Revenue With Tolls and Surcharges

Definition:
Fare amount, tips, tolls, taxes and listed surcharges.

Calculation:
SUM(
    fare_amount
    + tip_amount
    + tolls_amount
    + extra
    + mta_tax
    + improvement_surcharge
    + congestion_surcharge
    + Airport_fee
    + cbd_congestion_fee
)

Null charge values are treated as zero.

4. Average Fare

Definition:
Average fare amount per approved trip.

Calculation:
SUM(fare_amount) / COUNT(*)

SQL equivalent:
AVG(fare_amount)

5. Average Trip Duration

Definition:
Average journey duration in minutes.

Calculation:
AVG(duration_minutes)

Duration is calculated from pickup and drop-off timestamps.

6. Utilisation Proxy

Definition:
A measure of trip activity relative to observed zone-hours.

Calculation:

Total trip duration minutes
/
(Active zone-hours * 60)

Active zone-hours:
Number of distinct pickup date and pickup hour combinations for each pickup zone.

This is an operational activity proxy, NOT actual vehicle utilisation.

Actual fleet utilisation would require vehicle availability, shift hours or vehicle-level operating data.

7. Reporting Rules

- Use only client-approved trips.
- Exclude LONG_TRIP_OUT_OF_SCOPE records.
- Handle missing charge values as zero for revenue calculations.
- Report average fare and duration in their appropriate units.
- Do not describe the utilisation proxy as actual fleet utilisation.
- Maintain consistent metric definitions across SQL, Python and dashboards.

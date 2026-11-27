CR-1 Impact Assessment – Short-Hop Service Scope

1. Change Request Overview

Client: Marrowgate Pedal Link
Requested by: Elena Dribben, Head of Dispatch Operations
Change Request: CR-1
Requirement: Retain trips shorter than 3 miles OR shorter than 20 minutes. Exclude trips that are 3 miles or longer AND 20 minutes or longer.

2. What Changes

The short-hop filtering rule is applied before demand and revenue reporting.

- Trips satisfying the short-hop rule are retained.
- Trips outside the service scope are excluded.
- Excluded trips receive the reason code `LONG_TRIP_OUT_OF_SCOPE`.
- The number of excluded trips is recorded in the client scope run log.
- Warehouse tables, business metrics, and seasonality analysis use `client_in_scope_trips`.

3. Measured Impact

| Metric | Result |
|---|---:|
| Source trips | 3,658,255 |
| In-scope trips | 2,678,614 |
| Out-of-scope trips | 979,641 |
| Reconciliation difference | 0 |
| In-scope percentage | 73.22% |
| Excluded percentage | 26.78% |

The scope filter excludes 979,641 trips from downstream reporting.

4. Revenue Impact

Revenue calculations are available by pickup zone through the `revenue_by_zone` warehouse table.

Three revenue measures are maintained:

1. Base fare revenue.
2. Revenue including tips but excluding tolls and surcharges.
3. Revenue including tips, tolls, and applicable surcharges.

The currency unit must be confirmed against the source dataset before presenting financial values to the client.

5. Implementation Effort

Estimated effort for a small analytics project:

| Activity | Estimated effort |
|---|---:|
| Scope rule implementation | 2–3 hours |
| Validation and reconciliation | 2–3 hours |
| Warehouse updates | 2–3 hours |
| Metrics and reporting updates | 2–3 hours |
| Testing and documentation | 2–3 hours |
| **Total** | **10–15 hours** |

These are planning estimates, not recorded actual working hours.

6. Risks and Mitigation

| Risk | Mitigation |
|---|---|
| Incorrect trip classification | Validate distance and duration conditions |
| Missing or invalid source values | Use existing data validation and quarantine process |
| Demand figures change after filtering | Apply scope filtering before all client reporting |
| Limited historical coverage | Clearly disclose that only September 2026 is currently available |
| Revenue interpretation errors | Document revenue components and confirm currency |
| Utilisation proxy misunderstood | Clearly state that it is not actual fleet utilisation |
| Zone labels lack official names | Validate zone IDs against the official taxi zone lookup |

7. Acceptance Criteria

- [x] Apply the short-hop rule before demand reporting.
- [x] Exclude long trips using `LONG_TRIP_OUT_OF_SCOPE`.
- [x] Record excluded trip counts in the run log.
- [x] Reconcile source, in-scope, and out-of-scope counts.
- [x] Build warehouse tables using client-approved trips.
- [x] Calculate business metrics using in-scope trips.
- [x] Produce hourly, weekday, and monthly demand analysis.
- [x] Generate top and bottom pickup-zone reports.
- [x] Record anomaly assessment and handling decisions.
- [x] Build revenue reporting by pickup zone.

8. Final Assessment

CR-1 has been implemented and its scope classification has been validated. The in-scope and out-of-scope counts reconcile exactly, with zero difference.

All downstream demand and business metrics use the client-approved short-hop dataset. The analysis is currently limited to September 2026, and this limitation must be considered before making long-term demand or seasonality decisions.
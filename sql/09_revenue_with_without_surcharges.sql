
-- ============================================================
-- FleetSense Phase 1
-- CR-1: Revenue Impact Analysis
-- Revenue with and without tolls and surcharges by zone
-- ============================================================

SELECT
    pickup_zone_id,
    total_trips,
    base_fare_revenue,

    revenue_without_tolls_surcharges,

    revenue_with_tolls_surcharges,

    -- Additional revenue from tolls and surcharges
    (
        revenue_with_tolls_surcharges
        - revenue_without_tolls_surcharges
    ) AS additional_revenue

FROM revenue_by_zone

ORDER BY revenue_with_tolls_surcharges DESC;

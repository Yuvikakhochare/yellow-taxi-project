
-- 1. Total validated records

SELECT COUNT(*) AS total_records
FROM validated_trips;


-- 2. Accepted records

SELECT COUNT(*) AS accepted_records
FROM accepted_trips;


-- 3. Quarantined records

SELECT COUNT(*) AS quarantined_records
FROM quarantined_trips;


-- 4. Rejection reason summary

SELECT
    reason_code,
    COUNT(*) AS rejected_records
FROM quarantined_trips
GROUP BY reason_code
ORDER BY rejected_records DESC;


-- 5. Monthly reconciliation

SELECT
    month,
    source_rows,
    loaded_rows,
    quarantined_rows,
    source_rows - loaded_rows - quarantined_rows AS difference
FROM monthly_validation_log
ORDER BY month;


-- 6. Total month count

SELECT COUNT(DISTINCT month) AS total_months
FROM monthly_validation_log;

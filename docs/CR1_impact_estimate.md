# CR-1 Impact Estimate
## Revenue Comparison With and Without Tolls and Surcharges

**Project:** FleetSense – Phase 1: Data Foundation and Operations Analytics  
**Client:** Elena Dribben – Head of Dispatch Operations, Marrowgate Pedal Link  
**Change Request:** CR-1  
**Issued Date:** 22 November 2026  
**Status:** Implemented – Submitted for Verification

## 1. Objective

The objective of CR-1 is to provide a zone-wise comparison of revenue with and without tolls and surcharges. This helps the operations team understand the contribution of additional charges to reported revenue across pickup zones.

## 2. What Changes?

The following changes were implemented:

1. Created the SQL file `sql/09_revenue_with_without_surcharges.sql`.
2. Calculated revenue separately for each pickup zone.
3. Included total trip count and base fare revenue.
4. Calculated revenue without tolls and surcharges.
5. Calculated revenue with tolls and surcharges.
6. Calculated additional revenue as the difference between the two revenue measures.
7. Generated results for 260 pickup zones.

**Calculation:**

Additional Revenue = Revenue With Tolls and Surcharges - Revenue Without Tolls and Surcharges

## 3. Implementation Evidence

The SQL query executed successfully and returned results for 260 pickup zones.

**Example: Pickup Zone 237**

| Metric | Result |
|---|---:|
| Total Trips | 145,310 |
| Base Fare Revenue | $1,768,766.48 |
| Revenue Without Tolls and Surcharges | $2,122,875.14 |
| Revenue With Tolls and Surcharges | $2,912,715.63 |
| Additional Revenue | $789,840.49 |

These are observed results from the September 2026 analysis dataset. They are not figures from the separate 12-month 2025 ingestion.

## 4. Effort Estimate

| Activity | Estimated Effort |
|---|---:|
| Understanding the change request | 1 hour |
| Reviewing existing revenue tables | 1 hour |
| Developing the SQL query | 2 hours |
| Testing and validating calculations | 1 hour |
| Reviewing zone-wise results | 1 hour |
| Documentation | 1 hour |
| **Total estimated effort** | **7 hours** |

This is an estimated effort for SQL implementation and documentation. Dashboard integration is a separate activity.

## 5. Risk Assessment

| Risk | Possible Impact | Mitigation |
|---|---|---|
| Incorrect revenue calculation | Inaccurate revenue reporting | Validate SQL calculations against source columns |
| Missing toll or surcharge values | Incomplete revenue comparison | Check missing values and handle them consistently |
| Duplicate trip records | Revenue may be overstated | Validate records and prevent duplicate counting |
| Confusion between base fare and total revenue | Incorrect business interpretation | Display revenue measures separately |
| Incorrect zone mapping | Revenue assigned to the wrong zone | Validate pickup zone IDs against the zone lookup table |

## 6. Business Impact

- Helps compare revenue across pickup zones.
- Shows the contribution of tolls and surcharges.
- Improves transparency in revenue reporting.
- Supports operational and financial analysis.
- Provides a foundation for the CR-1 revenue view in the Streamlit dashboard.

## 7. Acceptance Criteria

- [x] Revenue without tolls and surcharges is calculated.
- [x] Revenue with tolls and surcharges is calculated.
- [x] Additional revenue is calculated.
- [x] Results are grouped by pickup zone.
- [x] SQL query executes successfully.
- [x] Results are returned for 260 pickup zones.
- [ ] Team reviews and verifies the impact estimate.
- [ ] CR-1 revenue view is integrated into the Streamlit dashboard.

## 8. Conclusion

CR-1 has been implemented at the SQL analysis level. The zone-wise revenue comparison successfully calculates revenue with and without tolls and surcharges.

The impact estimate documents the changes, estimated effort, risks and business benefits. It is submitted for team verification. Dashboard integration and final acceptance remain part of the release work.

**Prepared for:** FleetSense Project Team  
**Document:** CR-1 Impact Estimate – What Changes, Effort and Risk

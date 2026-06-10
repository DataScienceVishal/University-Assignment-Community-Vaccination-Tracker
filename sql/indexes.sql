-- ============================================================
-- Step 3.3  Proposed indexes (SQLite)
-- PRIMARY KEY and UNIQUE constraints already index most access paths,
-- including all PK joins and PatientID / (PatientID,VaccineTypeID) via
-- sqlite_autoindex_VACCINATION_1. These three fill the remaining gaps on
-- the high-growth VACCINATION table. Each was confirmed with EXPLAIN QUERY PLAN.
-- ============================================================

-- C1: group by worker. Removes the full scan + GROUP BY temp B-tree.
CREATE INDEX idx_vacc_worker    ON VACCINATION(WorkerID);

-- C2: group by vaccine, COUNT(DISTINCT patient). Covering index removes
--     BOTH the GROUP BY and the DISTINCT temp B-trees (one ordered scan).
CREATE INDEX idx_vacc_vtype_pat ON VACCINATION(VaccineTypeID, PatientID);

-- A1: ORDER BY DateAdministered. Removes the ORDER BY temp B-tree; also
--     supports date-range / period reporting.
CREATE INDEX idx_vacc_date      ON VACCINATION(DateAdministered);

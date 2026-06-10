-- ============================================================
-- Step 3.2  Eight SQL queries (SQLite)
-- Run after schema.sql + data.sql. LIMITs are for readable output only.
-- ============================================================

-- A1) JOIN across 5 tables: administered-dose register (audit / operational record)
SELECT v.VaccinationID,
       p.FirstName||' '||p.LastName AS Patient,
       vt.Name AS Vaccine, v.DoseNumber,
       w.FirstName||' '||w.LastName AS AdministeredBy,
       c.Name AS Clinic, v.DateAdministered
FROM VACCINATION v
JOIN PATIENT p           ON v.PatientID = p.PatientID
JOIN VACCINE_TYPE vt     ON v.VaccineTypeID = vt.VaccineTypeID
JOIN HEALTHCARE_WORKER w ON v.WorkerID = w.WorkerID
JOIN CLINIC c            ON v.ClinicID = c.ClinicID
ORDER BY v.DateAdministered DESC
LIMIT 8;

-- A2) JOIN across 5 tables: current stock with vaccine, manufacturer, lot and expiry
SELECT c.Name AS Clinic, vt.Name AS Vaccine, m.Name AS Manufacturer,
       s.LotNumber, b.ExpirationDate, s.QuantityOnHand
FROM CLINIC_STOCK s
JOIN CLINIC c        ON s.ClinicID = c.ClinicID
JOIN VACCINE_TYPE vt ON s.VaccineTypeID = vt.VaccineTypeID
JOIN MANUFACTURER m  ON vt.ManufacturerID = m.ManufacturerID
JOIN VACCINE_BATCH b ON s.VaccineTypeID = b.VaccineTypeID AND s.LotNumber = b.LotNumber
WHERE s.QuantityOnHand > 0
ORDER BY c.Name, b.ExpirationDate
LIMIT 8;

-- B1) Subquery (NOT IN): patients with no vaccination record -> outreach targets
SELECT p.PatientID, p.FirstName||' '||p.LastName AS Patient, p.Region, p.InsuranceStatus
FROM PATIENT p
WHERE p.PatientID NOT IN (SELECT DISTINCT PatientID FROM VACCINATION)
ORDER BY p.Region
LIMIT 8;

-- B2) Correlated subquery: patients who started but have not finished a multi-dose series
SELECT DISTINCT p.PatientID, p.FirstName||' '||p.LastName AS Patient,
       vt.Name AS Vaccine, vt.DosesInSeries,
       (SELECT MAX(v2.DoseNumber) FROM VACCINATION v2
        WHERE v2.PatientID = v.PatientID AND v2.VaccineTypeID = v.VaccineTypeID) AS DosesTaken
FROM VACCINATION v
JOIN PATIENT p       ON v.PatientID = p.PatientID
JOIN VACCINE_TYPE vt ON v.VaccineTypeID = vt.VaccineTypeID
WHERE vt.DosesInSeries > 1
  AND (SELECT MAX(v2.DoseNumber) FROM VACCINATION v2
       WHERE v2.PatientID = v.PatientID AND v2.VaccineTypeID = v.VaccineTypeID) < vt.DosesInSeries
ORDER BY p.PatientID
LIMIT 8;

-- C1) GROUP BY + HAVING: staff who have administered 5 or more doses (workload)
SELECT w.WorkerID, w.FirstName||' '||w.LastName AS Worker, w.Role,
       COUNT(*) AS DosesAdministered
FROM VACCINATION v
JOIN HEALTHCARE_WORKER w ON v.WorkerID = w.WorkerID
GROUP BY w.WorkerID
HAVING COUNT(*) >= 5
ORDER BY DosesAdministered DESC;

-- C2) GROUP BY + HAVING: vaccines that have reached 3 or more distinct patients (demand)
SELECT vt.Name AS Vaccine, COUNT(DISTINCT v.PatientID) AS PatientsReached
FROM VACCINATION v
JOIN VACCINE_TYPE vt ON v.VaccineTypeID = vt.VaccineTypeID
GROUP BY vt.VaccineTypeID
HAVING COUNT(DISTINCT v.PatientID) >= 3
ORDER BY PatientsReached DESC;

-- D1) Sustainability (SDG-3 equity): reach vs uninsured burden, by neighbourhood
SELECT p.Region,
       COUNT(DISTINCT p.PatientID) AS PatientsInRegion,
       SUM(CASE WHEN p.InsuranceStatus='uninsured' THEN 1 ELSE 0 END) AS Uninsured,
       COUNT(DISTINCT vacc.PatientID) AS VaccinatedPatients
FROM PATIENT p
LEFT JOIN VACCINATION vacc ON p.PatientID = vacc.PatientID
GROUP BY p.Region
ORDER BY Uninsured DESC;

-- D2) Sustainability (waste reduction): stock expired or expiring within 90 days
SELECT c.Name AS Clinic, vt.Name AS Vaccine, s.LotNumber,
       b.ExpirationDate, s.QuantityOnHand,
       CASE WHEN b.ExpirationDate < DATE('now') THEN 'EXPIRED'
            WHEN b.ExpirationDate < DATE('now','+90 day') THEN 'EXPIRING_SOON'
            ELSE 'OK' END AS WasteRisk
FROM CLINIC_STOCK s
JOIN VACCINE_BATCH b ON s.VaccineTypeID = b.VaccineTypeID AND s.LotNumber = b.LotNumber
JOIN VACCINE_TYPE vt ON s.VaccineTypeID = vt.VaccineTypeID
JOIN CLINIC c        ON s.ClinicID = c.ClinicID
WHERE s.QuantityOnHand > 0 AND b.ExpirationDate < DATE('now','+90 day')
ORDER BY b.ExpirationDate
LIMIT 8;

-- ============================================================
-- Community Vaccination Tracking System  (SQLite)
-- Step 3.1 schema. SQLite uses type affinity, so VARCHAR(n)/
-- DATE/DECIMAL are advisory; dates/times are stored as ISO-8601
-- TEXT. Foreign keys must be enabled per connection.
-- ============================================================
PRAGMA foreign_keys = ON;

-- Vaccine producers. Separated from VACCINE_TYPE so manufacturer
-- details are not repeated per product (keeps VACCINE_TYPE in 3NF).
CREATE TABLE MANUFACTURER (
  ManufacturerID INTEGER PRIMARY KEY,
  Name           VARCHAR(100) NOT NULL UNIQUE,
  ContactInfo    VARCHAR(150)
);

-- The six clinics. Region is explicit to support equity reporting.
CREATE TABLE CLINIC (
  ClinicID        INTEGER PRIMARY KEY,
  Name            VARCHAR(100) NOT NULL UNIQUE,
  Street          VARCHAR(150),
  City            VARCHAR(80),
  Region          VARCHAR(80) NOT NULL,
  Postcode        VARCHAR(12),       -- non-authoritative (free text)
  Phone           VARCHAR(20),
  ServiceCapacity INTEGER NOT NULL CHECK (ServiceCapacity > 0)  -- max appts/day
);

-- Patients. Age is NOT stored; it is derived from DateOfBirth.
CREATE TABLE PATIENT (
  PatientID       INTEGER PRIMARY KEY,
  NationalID      VARCHAR(20) UNIQUE,
  FirstName       VARCHAR(50),
  LastName        VARCHAR(50) NOT NULL,
  DateOfBirth     DATE NOT NULL,
  Street          VARCHAR(150),
  City            VARCHAR(80),
  Region          VARCHAR(80),
  Postcode        VARCHAR(12),
  Email           VARCHAR(100),
  InsuranceStatus VARCHAR(10) NOT NULL
                  CHECK (InsuranceStatus IN ('insured','uninsured','pending'))
);

-- Clinical staff. Role is an enumerated domain via CHECK (SQLite has no ENUM).
CREATE TABLE HEALTHCARE_WORKER (
  WorkerID      INTEGER PRIMARY KEY,
  LicenceNumber VARCHAR(30) UNIQUE,
  FirstName     VARCHAR(50),
  LastName      VARCHAR(50) NOT NULL,
  Role          VARCHAR(11) NOT NULL
                CHECK (Role IN ('doctor','nurse','pharmacist')),
  Phone         VARCHAR(20),
  Email         VARCHAR(100)
);

-- Vaccine catalogue. Expiry lives on the batch, not here.
CREATE TABLE VACCINE_TYPE (
  VaccineTypeID  INTEGER PRIMARY KEY,
  Name           VARCHAR(100) NOT NULL UNIQUE,
  ManufacturerID INTEGER NOT NULL,
  DoseVolume     DECIMAL(4,2) NOT NULL CHECK (DoseVolume > 0),   -- mL per dose
  DosesInSeries  INTEGER NOT NULL CHECK (DosesInSeries > 0),
  IntervalDays   INTEGER,            -- NULL for single-dose vaccines
  StorageTempMin DECIMAL(4,1) NOT NULL,
  StorageTempMax DECIMAL(4,1) NOT NULL,
  FOREIGN KEY (ManufacturerID) REFERENCES MANUFACTURER(ManufacturerID),
  CHECK (StorageTempMin <= StorageTempMax)
);

-- Weak entity: physical stock. Identified by owner type + partial key LotNumber.
CREATE TABLE VACCINE_BATCH (
  VaccineTypeID  INTEGER NOT NULL,
  LotNumber      VARCHAR(40) NOT NULL,   -- unique only within a vaccine type
  ExpirationDate DATE NOT NULL,
  PRIMARY KEY (VaccineTypeID, LotNumber),
  FOREIGN KEY (VaccineTypeID) REFERENCES VACCINE_TYPE(VaccineTypeID) ON DELETE CASCADE
);

-- Weak entity: per-day opening hours for a clinic.
CREATE TABLE CLINIC_OPERATING_HOURS (
  ClinicID  INTEGER NOT NULL,
  DayOfWeek INTEGER NOT NULL CHECK (DayOfWeek BETWEEN 1 AND 7),  -- 1=Mon..7=Sun
  OpenTime  VARCHAR(5) NOT NULL,    -- 'HH:MM'
  CloseTime VARCHAR(5) NOT NULL,
  PRIMARY KEY (ClinicID, DayOfWeek),
  FOREIGN KEY (ClinicID) REFERENCES CLINIC(ClinicID) ON DELETE CASCADE,
  CHECK (CloseTime > OpenTime)       -- works for zero-padded 24h text
);

-- Multivalued attribute of PATIENT mapped to its own relation.
CREATE TABLE PATIENT_PHONE (
  PatientID   INTEGER NOT NULL,
  PhoneNumber VARCHAR(20) NOT NULL,
  PRIMARY KEY (PatientID, PhoneNumber),
  FOREIGN KEY (PatientID) REFERENCES PATIENT(PatientID) ON DELETE CASCADE
);

-- M:N assignment of staff to clinics.
CREATE TABLE WORKER_CLINIC (
  WorkerID INTEGER NOT NULL,
  ClinicID INTEGER NOT NULL,
  PRIMARY KEY (WorkerID, ClinicID),
  FOREIGN KEY (WorkerID) REFERENCES HEALTHCARE_WORKER(WorkerID) ON DELETE CASCADE,
  FOREIGN KEY (ClinicID) REFERENCES CLINIC(ClinicID) ON DELETE CASCADE
);

-- M:N stock holding (a lot can sit at several clinics). Quantity per clinic.
CREATE TABLE CLINIC_STOCK (
  ClinicID       INTEGER NOT NULL,
  VaccineTypeID  INTEGER NOT NULL,
  LotNumber      VARCHAR(40) NOT NULL,
  QuantityOnHand INTEGER NOT NULL CHECK (QuantityOnHand >= 0),
  PRIMARY KEY (ClinicID, VaccineTypeID, LotNumber),
  FOREIGN KEY (ClinicID) REFERENCES CLINIC(ClinicID) ON DELETE CASCADE,
  FOREIGN KEY (VaccineTypeID, LotNumber)
              REFERENCES VACCINE_BATCH(VaccineTypeID, LotNumber) ON DELETE CASCADE
);

-- Scheduled visits. Intended vaccine is optional.
CREATE TABLE APPOINTMENT (
  AppointmentID     INTEGER PRIMARY KEY,
  PatientID         INTEGER NOT NULL,
  ClinicID          INTEGER NOT NULL,
  VaccineTypeID     INTEGER,           -- intended vaccine, nullable
  ScheduledDateTime DATETIME NOT NULL,
  Status            VARCHAR(10) NOT NULL
                    CHECK (Status IN ('scheduled','completed','cancelled','no_show')),
  FOREIGN KEY (PatientID)     REFERENCES PATIENT(PatientID),
  FOREIGN KEY (ClinicID)      REFERENCES CLINIC(ClinicID),
  FOREIGN KEY (VaccineTypeID) REFERENCES VACCINE_TYPE(VaccineTypeID)
);

-- Administered doses (core fact). PatientID/ClinicID stored directly because
-- the appointment link is optional (walk-ins); consistency is an app rule.
CREATE TABLE VACCINATION (
  VaccinationID    INTEGER PRIMARY KEY,
  PatientID        INTEGER NOT NULL,
  WorkerID         INTEGER NOT NULL,
  VaccineTypeID    INTEGER NOT NULL,
  LotNumber        VARCHAR(40) NOT NULL,
  ClinicID         INTEGER NOT NULL,
  AppointmentID    INTEGER,            -- NULL = walk-in
  DateAdministered DATE NOT NULL,
  DoseNumber       INTEGER NOT NULL CHECK (DoseNumber > 0),
  UNIQUE (PatientID, VaccineTypeID, DoseNumber),   -- no duplicate dose # per series
  FOREIGN KEY (PatientID)     REFERENCES PATIENT(PatientID),
  FOREIGN KEY (WorkerID)      REFERENCES HEALTHCARE_WORKER(WorkerID),
  FOREIGN KEY (VaccineTypeID, LotNumber)
               REFERENCES VACCINE_BATCH(VaccineTypeID, LotNumber),
  FOREIGN KEY (ClinicID)      REFERENCES CLINIC(ClinicID),
  FOREIGN KEY (AppointmentID) REFERENCES APPOINTMENT(AppointmentID)
);

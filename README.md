# Community Vaccination Tracking — Patient Manager

Command-line application for the LCSCI7228 AE1 coursework (Step 4). It manages
patient records for a network of community vaccination clinics, on top of the
SQLite database designed in Steps 1–3.

## Technology and constraints
- Python 3 (standard library only).
- SQLite through the built-in `sqlite3` driver. **No ORM is used** — every
  statement is hand-written and parameterised.
- No third-party dependencies.

## Features
Full CRUD on patients, with validation performed before any write:
- **Create** — register a patient (required fields, a real past date of birth,
  insurance status from a fixed set, and a unique National ID).
- **Read** — list or search patients by surname or region.
- **Update** — change a patient's email and insurance status.
- **Delete** — remove a patient; phone numbers cascade, but the delete is
  blocked when the patient has appointments or vaccinations on record.

## Database integration
- `PRAGMA foreign_keys = ON` on every connection.
- Parameterised queries (`?` placeholders) to prevent SQL injection.
- Each write runs inside a transaction (`with connection:`), committing on
  success and rolling back on error.
- Schema constraints (CHECK, UNIQUE, NOT NULL, foreign keys) act as the final
  guard behind the application-level validation.

## Project layout
```
app/
├── main.py              entry point
├── src/
│   ├── db.py            connection + first-run bootstrap
│   ├── validators.py    input and business-rule checks
│   ├── patient_service.py  CRUD operations
│   └── cli.py           menu loop
├── sql/
│   ├── schema.sql       tables, keys, constraints
│   ├── data.sql         sample data (6 clinics, 100 patients, 85 vaccinations …)
│   ├── queries.sql      the eight reporting queries
│   └── indexes.sql      proposed indexes
└── README.md
```

## Setup and run
1. Check Python is available: `python3 --version`.
2. From the `app/` folder: `python3 main.py`.
3. On first run the app builds `vaccination.db` from `sql/schema.sql` and
   `sql/data.sql` automatically. Delete `vaccination.db` to rebuild from scratch.

## AI use declaration
AI assistance was used in line with the assessment brief and is cited in the
report using APA style.

## Author
**Vishal Khan - Msc in AI and CS, Northeastern University**
**Shubham Singh - Msc in AI and CS, Northeastern University**

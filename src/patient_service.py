"""CRUD operations for PATIENT. Every statement is parameterised; no ORM."""
import sqlite3

import validators


class ValidationError(Exception):
    def __init__(self, errors):
        super().__init__("; ".join(errors))
        self.errors = errors


class NotFoundError(Exception):
    pass


class InUseError(Exception):
    pass


def create_patient(conn, data):
    """CREATE. Validates before inserting; returns the new PatientID."""
    errors = validators.validate_new_patient(data, conn)
    if errors:
        raise ValidationError(errors)
    with conn:  # commit on success, roll back on any error
        cursor = conn.execute(
            """INSERT INTO PATIENT
                   (NationalID, FirstName, LastName, DateOfBirth,
                    Street, City, Region, Postcode, Email, InsuranceStatus)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (data.get("NationalID"), data.get("FirstName"), data.get("LastName"),
             data.get("DateOfBirth"), data.get("Street"), data.get("City"),
             data.get("Region"), data.get("Postcode"), data.get("Email"),
             data.get("InsuranceStatus")),
        )
    return cursor.lastrowid


def get_patient(conn, patient_id):
    """READ one."""
    return conn.execute(
        "SELECT * FROM PATIENT WHERE PatientID = ?", (patient_id,)
    ).fetchone()


def find_patients(conn, term=None, limit=50):
    """READ many, optionally filtered by surname or region."""
    if term:
        like = f"%{term}%"
        return conn.execute(
            """SELECT PatientID, FirstName, LastName, Region, InsuranceStatus
                 FROM PATIENT
                WHERE LastName LIKE ? OR Region LIKE ?
                ORDER BY PatientID LIMIT ?""",
            (like, like, limit),
        ).fetchall()
    return conn.execute(
        """SELECT PatientID, FirstName, LastName, Region, InsuranceStatus
             FROM PATIENT ORDER BY PatientID LIMIT ?""",
        (limit,),
    ).fetchall()


def update_patient_contact(conn, patient_id, email, insurance_status):
    """UPDATE editable fields after re-validating them."""
    if get_patient(conn, patient_id) is None:
        raise NotFoundError(f"No patient with id {patient_id}")
    errors = validators.validate_patient_update(
        {"Email": email, "InsuranceStatus": insurance_status}
    )
    if errors:
        raise ValidationError(errors)
    with conn:
        conn.execute(
            "UPDATE PATIENT SET Email = ?, InsuranceStatus = ? WHERE PatientID = ?",
            (email, insurance_status, patient_id),
        )


def delete_patient(conn, patient_id):
    """DELETE. Phone rows cascade; blocked if clinical records reference the patient."""
    if get_patient(conn, patient_id) is None:
        raise NotFoundError(f"No patient with id {patient_id}")
    try:
        with conn:
            conn.execute("DELETE FROM PATIENT WHERE PatientID = ?", (patient_id,))
    except sqlite3.IntegrityError:
        raise InUseError(
            "Cannot delete: this patient has appointments or vaccinations on record"
        )

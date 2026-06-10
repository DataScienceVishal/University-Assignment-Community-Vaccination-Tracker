"""Input and business-rule validation, run before any database write."""
from datetime import date

ALLOWED_INSURANCE = {"insured", "uninsured", "pending"}


def valid_date_of_birth(value):
    try:
        parsed = date.fromisoformat(value)
    except (ValueError, TypeError):
        return False, "DateOfBirth must be a real date in YYYY-MM-DD format"
    if parsed > date.today():
        return False, "DateOfBirth cannot be in the future"
    if parsed.year < 1900:
        return False, "DateOfBirth year is unrealistic"
    return True, ""


def valid_email(value):
    if "@" not in value:
        return False
    local, _, domain = value.partition("@")
    return bool(local) and "." in domain


def national_id_exists(conn, national_id):
    row = conn.execute(
        "SELECT 1 FROM PATIENT WHERE NationalID = ?", (national_id,)
    ).fetchone()
    return row is not None


def validate_new_patient(data, conn):
    """Return a list of error messages; an empty list means the input is valid."""
    errors = []
    if not data.get("LastName", "").strip():
        errors.append("LastName is required")

    ok, message = valid_date_of_birth(data.get("DateOfBirth", ""))
    if not ok:
        errors.append(message)

    national_id = data.get("NationalID", "").strip()
    if not national_id:
        errors.append("NationalID is required")
    elif len(national_id) > 20:
        errors.append("NationalID must be 20 characters or fewer")
    elif national_id_exists(conn, national_id):
        errors.append("NationalID is already registered")

    errors.extend(_validate_common(data))
    return errors


def validate_patient_update(data):
    """Validation for the fields editable on update."""
    return _validate_common(data)


def _validate_common(data):
    errors = []
    insurance = data.get("InsuranceStatus", "").strip()
    if insurance not in ALLOWED_INSURANCE:
        errors.append("InsuranceStatus must be one of: insured, uninsured, pending")
    email = data.get("Email")
    if email and not valid_email(email):
        errors.append("Email format is invalid")
    return errors

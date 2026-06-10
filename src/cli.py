"""Menu-driven command line interface."""
import db
import patient_service as svc


def _prompt(label, required=False):
    while True:
        value = input(f"{label}: ").strip()
        if value or not required:
            return value
        print("  This field is required.")


def do_create(conn):
    print("\n-- Register patient --")
    data = {
        "NationalID": _prompt("National ID", required=True),
        "FirstName": _prompt("First name"),
        "LastName": _prompt("Last name", required=True),
        "DateOfBirth": _prompt("Date of birth (YYYY-MM-DD)", required=True),
        "Street": _prompt("Street"),
        "City": _prompt("City"),
        "Region": _prompt("Region"),
        "Postcode": _prompt("Postcode"),
        "Email": _prompt("Email"),
        "InsuranceStatus": _prompt("Insurance (insured/uninsured/pending)", required=True),
    }
    try:
        new_id = svc.create_patient(conn, data)
        print(f"  Registered patient #{new_id}")
    except svc.ValidationError as exc:
        print("  Could not register:")
        for err in exc.errors:
            print(f"   - {err}")


def do_read(conn):
    term = input("\nSearch surname/region (blank for all): ").strip() or None
    rows = svc.find_patients(conn, term)
    print(f"  {len(rows)} patient(s):")
    for r in rows:
        name = f"{r['FirstName'] or ''} {r['LastName']}".strip()
        print(f"   #{r['PatientID']:<4} {name:<26} {r['Region'] or '':<12} {r['InsuranceStatus']}")


def do_update(conn):
    pid = input("\nPatient id to update: ").strip()
    if not pid.isdigit():
        print("  Enter a numeric id.")
        return
    email = _prompt("New email")
    insurance = _prompt("New insurance (insured/uninsured/pending)", required=True)
    try:
        svc.update_patient_contact(conn, int(pid), email, insurance)
        print("  Updated.")
    except svc.NotFoundError as exc:
        print(f"  {exc}")
    except svc.ValidationError as exc:
        print("  Could not update:")
        for err in exc.errors:
            print(f"   - {err}")


def do_delete(conn):
    pid = input("\nPatient id to delete: ").strip()
    if not pid.isdigit():
        print("  Enter a numeric id.")
        return
    try:
        svc.delete_patient(conn, int(pid))
        print("  Deleted.")
    except (svc.NotFoundError, svc.InUseError) as exc:
        print(f"  {exc}")


MENU = """
Community Vaccination Tracking - Patient Manager
  1) Register patient   (Create)
  2) Search patients    (Read)
  3) Update contact     (Update)
  4) Delete patient     (Delete)
  0) Exit
"""


def run():
    conn = db.connect()
    db.ensure_ready(conn)
    try:
        while True:
            print(MENU)
            choice = input("Choose: ").strip()
            if choice == "1":
                do_create(conn)
            elif choice == "2":
                do_read(conn)
            elif choice == "3":
                do_update(conn)
            elif choice == "4":
                do_delete(conn)
            elif choice == "0":
                break
            else:
                print("  Unknown option.")
    finally:
        conn.close()
    print("Goodbye.")

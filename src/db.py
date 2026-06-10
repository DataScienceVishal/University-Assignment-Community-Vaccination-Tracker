"""Database connection and one-time bootstrap. No ORM: plain sqlite3 driver."""
import os
import sqlite3

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE_DIR, "vaccination.db")
SQL_DIR = os.path.join(BASE_DIR, "sql")


def connect(db_path=DB_PATH):
    """Open a connection with foreign keys enforced and named-column rows."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def is_initialised(conn):
    """True if the schema has already been created in this database."""
    row = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='PATIENT'"
    ).fetchone()
    return row is not None


def initialise(conn, sql_dir=SQL_DIR):
    """Create tables and load sample data from the sql/ folder."""
    for filename in ("schema.sql", "data.sql"):
        with open(os.path.join(sql_dir, filename), "r", encoding="utf-8") as handle:
            conn.executescript(handle.read())
    conn.execute("PRAGMA foreign_keys = ON")


def ensure_ready(conn):
    """Build the database on first run if it is empty."""
    if not is_initialised(conn):
        initialise(conn)

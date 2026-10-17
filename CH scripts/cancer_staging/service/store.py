"""SQLite state of the service: sheet snapshot, cases, devices, and the audit log."""

from __future__ import annotations

import hashlib
import json
import sqlite3
import threading
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

SCHEMA = """
CREATE TABLE IF NOT EXISTS sheet_rows(
  row_number INTEGER PRIMARY KEY, accession TEXT, chart_no TEXT, doctor TEXT,
  status TEXT, cancer_type TEXT, duplicate INTEGER NOT NULL DEFAULT 0, data TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS sheet_rows_accession ON sheet_rows(accession);
CREATE TABLE IF NOT EXISTS cases(
  accession TEXT PRIMARY KEY, chart_no TEXT NOT NULL, doctor TEXT NOT NULL, phase TEXT NOT NULL,
  source TEXT NOT NULL, ris TEXT, ris_tries INTEGER NOT NULL DEFAULT 0, ris_at TEXT,
  entry TEXT, entry_by TEXT, entry_at TEXT, review TEXT, note TEXT NOT NULL DEFAULT '',
  rev INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS cases_doctor ON cases(doctor, phase);
CREATE TABLE IF NOT EXISTS doctors(name TEXT PRIMARY KEY, ris_userid TEXT NOT NULL, updated_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS devices(
  token_hash TEXT NOT NULL, doctor TEXT NOT NULL, trusted_at TEXT NOT NULL,
  auto_send INTEGER NOT NULL DEFAULT 0, last_seen TEXT, PRIMARY KEY(token_hash, doctor));
CREATE TABLE IF NOT EXISTS events(
  id INTEGER PRIMARY KEY AUTOINCREMENT, at TEXT NOT NULL, kind TEXT NOT NULL,
  accession TEXT NOT NULL DEFAULT '', doctor TEXT NOT NULL DEFAULT '', device TEXT NOT NULL DEFAULT '',
  detail TEXT NOT NULL DEFAULT '{}');
CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
"""

# new: seen in the sheet; ris_error / not_reported: fetch to retry; ready: in review;
# staged: RIS already has a staging block; closed: the sheet row is no longer to do.
OPEN_PHASES = ("new", "ris_error", "not_reported", "ready", "staged")
REVIEW_PHASES = ("ready", "staged")
JSON_COLUMNS = ("source", "ris", "entry", "review")


class Conflict(Exception):
    """The case changed in the database after it was loaded."""


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def token_hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _dump(value: Any) -> str | None:
    return None if value is None else json.dumps(value, ensure_ascii=False, sort_keys=True)


class Store:
    def __init__(self, path: Path) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._local = threading.local()
        self._db().executescript(SCHEMA)

    def _db(self) -> sqlite3.Connection:
        db = getattr(self._local, "db", None)
        if db is None:
            db = sqlite3.connect(self.path, timeout=30, isolation_level=None)
            db.row_factory = sqlite3.Row
            db.execute("PRAGMA journal_mode=WAL")
            db.execute("PRAGMA busy_timeout=30000")
            self._local.db = db
        return db

    @contextmanager
    def tx(self) -> Iterator[sqlite3.Connection]:
        """One write transaction; nested use joins the outer one."""
        db = self._db()
        if db.in_transaction:
            yield db
            return
        db.execute("BEGIN IMMEDIATE")
        try:
            yield db
        except BaseException:
            db.execute("ROLLBACK")
            raise
        db.execute("COMMIT")

    # ---- generic -------------------------------------------------------------------------
    def log(self, kind: str, *, accession: str = "", doctor: str = "", device: str = "", **detail: Any) -> None:
        with self.tx() as db:
            db.execute(
                "INSERT INTO events(at, kind, accession, doctor, device, detail) VALUES(?,?,?,?,?,?)",
                (now(), kind, str(accession), doctor, device[:12], json.dumps(detail, ensure_ascii=False)),
            )

    def events(self, limit: int = 50, accession: str | None = None) -> list[dict[str, Any]]:
        where, args = ("WHERE accession=?", [accession]) if accession else ("", [])
        rows = self._db().execute(f"SELECT * FROM events {where} ORDER BY id DESC LIMIT ?", [*args, limit])
        return [{**dict(row), "detail": json.loads(row["detail"])} for row in rows]

    def get_meta(self, key: str, default: str = "") -> str:
        row = self._db().execute("SELECT value FROM meta WHERE key=?", (key,)).fetchone()
        return row["value"] if row else default

    def set_meta(self, key: str, value: str) -> None:
        with self.tx() as db:
            db.execute("INSERT INTO meta(key, value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
                       (key, value))

    # ---- sheet snapshot ------------------------------------------------------------------
    def replace_sheet_rows(self, rows: list[dict[str, Any]]) -> None:
        """`rows`: normalized row dicts with `input_row` and `duplicate`."""
        with self.tx() as db:
            db.execute("DELETE FROM sheet_rows")
            db.executemany(
                "INSERT INTO sheet_rows(row_number, accession, chart_no, doctor, status, cancer_type, duplicate, data)"
                " VALUES(?,?,?,?,?,?,?,?)",
                [(row["input_row"], row["accession"], row["chart_no"], row["review_doctor"], row["status"],
                  row["cancer_type_existing"], int(bool(row.get("duplicate"))), _dump(row)) for row in rows],
            )

    def sheet_row(self, accession: str) -> dict[str, Any] | None:
        row = self._db().execute(
            "SELECT data FROM sheet_rows WHERE accession=? AND duplicate=0", (str(accession),)).fetchone()
        return json.loads(row["data"]) if row else None

    def sheet_counts(self) -> dict[str, dict[str, int]]:
        """Per doctor: number of sheet rows by status."""
        out: dict[str, dict[str, int]] = {}
        for row in self._db().execute(
                "SELECT doctor, status, COUNT(*) AS n FROM sheet_rows WHERE doctor<>'' GROUP BY doctor, status"):
            out.setdefault(row["doctor"], {})[row["status"]] = row["n"]
        return out

    # ---- cases ---------------------------------------------------------------------------
    @staticmethod
    def _case(row: sqlite3.Row | None) -> dict[str, Any] | None:
        if row is None:
            return None
        case = dict(row)
        for key in JSON_COLUMNS:
            case[key] = json.loads(case[key]) if case[key] else None
        return case

    def get_case(self, accession: str) -> dict[str, Any] | None:
        return self._case(self._db().execute("SELECT * FROM cases WHERE accession=?", (str(accession),)).fetchone())

    def cases(self, *, phases: tuple[str, ...] | None = None, doctor: str | None = None) -> list[dict[str, Any]]:
        where, args = [], []
        if phases:
            where.append(f"phase IN ({','.join('?' * len(phases))})")
            args += list(phases)
        if doctor is not None:
            where.append("doctor=?")
            args.append(doctor)
        sql = "SELECT * FROM cases" + (" WHERE " + " AND ".join(where) if where else "")
        rows = [self._case(row) for row in self._db().execute(sql, args)]
        return sorted(rows, key=lambda case: (case["source"].get("input_row") or 0, case["accession"]))

    def create_case(self, source: dict[str, Any]) -> None:
        stamp = now()
        with self.tx() as db:
            db.execute(
                "INSERT INTO cases(accession, chart_no, doctor, phase, source, created_at, updated_at)"
                " VALUES(?,?,?,?,?,?,?)",
                (source["accession"], source["chart_no"], source["review_doctor"], "new", _dump(source), stamp, stamp),
            )

    def update_case(self, accession: str, *, expect_rev: int | None = None, **fields: Any) -> int:
        """Set columns of one case; returns its new revision number."""
        columns = {key: (_dump(value) if key in JSON_COLUMNS else value) for key, value in fields.items()}
        columns["updated_at"] = now()
        sql = f"UPDATE cases SET rev=rev+1, {', '.join(f'{key}=?' for key in columns)} WHERE accession=?"
        args = [*columns.values(), str(accession)]
        if expect_rev is not None:
            sql += " AND rev=?"
            args.append(expect_rev)
        with self.tx() as db:
            if db.execute(sql, args).rowcount != 1:
                raise Conflict(f"Study {accession} changed in the database; reload the page")
            return db.execute("SELECT rev FROM cases WHERE accession=?", (str(accession),)).fetchone()["rev"]

    def phase_counts(self) -> dict[str, int]:
        return {row["phase"]: row["n"] for row in
                self._db().execute("SELECT phase, COUNT(*) AS n FROM cases GROUP BY phase")}

    # ---- review view of one doctor ----------------------------------------------------------
    def load_review(self, doctor: str) -> dict[str, Any]:
        cases = []
        for row in self.cases(phases=REVIEW_PHASES, doctor=doctor) if doctor else []:
            if row["review"]:
                cases.append({"source": row["source"], **row["review"], "_rev": row["rev"]})
        return {"schema_version": 1, "doctor": doctor, "cases": cases}

    def save_review(self, doctor: str, review: dict[str, Any], *, device: str = "") -> list[str]:
        """Store the cases that changed; returns their accessions."""
        changed: list[str] = []
        with self.tx():
            for case in review.get("cases", []):
                accession = str(case["source"]["accession"])
                body = {key: value for key, value in case.items() if key not in ("source", "_rev")}
                current = self.get_case(accession)
                if current is None or current["doctor"] != doctor:
                    raise Conflict(f"Study {accession} is not in this doctor's list any more")
                if _dump(current["review"]) == _dump(body):
                    continue
                case["_rev"] = self.update_case(accession, expect_rev=case.get("_rev"), review=body)
                self.log("review_saved", accession=accession, doctor=doctor, device=device,
                         approval=body.get("approval", {}).get("state", ""),
                         text_sha256=body.get("proposal", {}).get("text_sha256", ""))
                changed.append(accession)
        return changed

    # ---- doctors and devices ----------------------------------------------------------------
    def ris_userid(self, doctor: str) -> str:
        row = self._db().execute("SELECT ris_userid FROM doctors WHERE name=?", (doctor,)).fetchone()
        return row["ris_userid"] if row else ""

    def set_ris_userid(self, doctor: str, userid: str) -> None:
        with self.tx() as db:
            db.execute(
                "INSERT INTO doctors(name, ris_userid, updated_at) VALUES(?,?,?)"
                " ON CONFLICT(name) DO UPDATE SET ris_userid=excluded.ris_userid, updated_at=excluded.updated_at",
                (doctor, userid, now()),
            )

    def device(self, token: str, doctor: str) -> dict[str, Any] | None:
        if not token or not doctor:
            return None
        row = self._db().execute(
            "SELECT * FROM devices WHERE token_hash=? AND doctor=?", (token_hash(token), doctor)).fetchone()
        return dict(row) if row else None

    def trust_device(self, token: str, doctor: str) -> None:
        with self.tx() as db:
            db.execute(
                "INSERT INTO devices(token_hash, doctor, trusted_at, last_seen) VALUES(?,?,?,?)"
                " ON CONFLICT(token_hash, doctor) DO UPDATE SET trusted_at=excluded.trusted_at",
                (token_hash(token), doctor, now(), now()),
            )

    def forget_device(self, token: str, doctor: str) -> None:
        with self.tx() as db:
            db.execute("DELETE FROM devices WHERE token_hash=? AND doctor=?", (token_hash(token), doctor))

    def count_events(self, kind: str, *, doctor: str, since: str) -> int:
        return self._db().execute("SELECT COUNT(*) FROM events WHERE kind=? AND doctor=? AND at>=?",
                                  (kind, doctor, since)).fetchone()[0]

    def set_auto_send(self, token: str, doctor: str, enabled: bool) -> None:
        with self.tx() as db:
            db.execute("UPDATE devices SET auto_send=? WHERE token_hash=? AND doctor=?",
                       (int(enabled), token_hash(token), doctor))

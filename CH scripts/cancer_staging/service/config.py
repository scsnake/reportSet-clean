"""Settings of the service: defaults, then `<data_dir>/config.json`, then CS_* environment."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, fields, replace
from datetime import datetime
from pathlib import Path
from typing import Any

APP_DIR = Path(__file__).resolve().parent.parent
DEFAULT_DATA_DIR = Path("/opt/cancer_staging/data")
TODO_STATUS = "待修正"


@dataclass(frozen=True)
class Settings:
    data_dir: Path = DEFAULT_DATA_DIR
    sheet_id: str = "MOCK_SHEET_ID"
    sheet_gid: int = 40999601
    service_account_key: Path = Path("/opt/cancer_staging/secrets/google_service_account.json")
    webris_url: str = "http://127.0.0.1:7200"
    host: str = "127.0.0.1"
    port: int = 7206
    # Address the doctors open (reverse tunnel on the office PC), shown in messages only.
    public_url: str = "http://192.0.2.10:7204/"
    # WebRIS page where a doctor saves the RIS login (reverse tunnel on the office PC).
    credentials_url: str = "http://192.0.2.10:7203/admin/credentials"
    # The sheet changes rarely: one poll each day, before the night job (00:05).
    poll_at: str = "23:30"
    ris_fetch_per_cycle: int = 200
    ris_retry_hours: int = 6
    ris_refresh_hours: int = 24
    # Doctors who may send to RIS from this service. Empty: every doctor who signs in with
    # their own RIS account and has the RIS login saved in WebRIS.
    send_doctors: tuple[str, ...] = ()
    # False: nobody can send from this process (preview with `service.run --no-send`).
    send_enabled: bool = True
    # A RIS sign-in on the page lets that browser send for this many hours.
    signin_hours: int = 12
    # "off": paste-back only; "button": the doctor clicks; "auto": after each send.
    sheet_write: str = "button"
    llm_model: str = "qwen3.6-35b-a3b"

    @property
    def db_path(self) -> Path:
        return self.data_dir / "staging.db"

    @property
    def ledger_path(self) -> Path:
        return self.data_dir / "sent_ledger.jsonl"

    @property
    def log_dir(self) -> Path:
        return self.data_dir / "logs"


def _coerce(name: str, value: Any) -> Any:
    kind = {f.name: f.type for f in fields(Settings)}[name]
    if "Path" in str(kind):
        return Path(value)
    if "tuple" in str(kind):
        items = value.split(",") if isinstance(value, str) else value
        return tuple(item for item in items if item)
    if str(kind) == "int":
        return int(value)
    if str(kind) == "bool":
        return value if isinstance(value, bool) else str(value).strip().lower() in ("1", "true", "yes", "on")
    return value


def load_settings(data_dir: Path | None = None) -> Settings:
    data_dir = Path(data_dir or os.environ.get("CS_DATA_DIR") or DEFAULT_DATA_DIR)
    values: dict[str, Any] = {"data_dir": data_dir}
    config = data_dir / "config.json"
    if config.is_file():
        values.update(json.loads(config.read_text(encoding="utf-8")))
    names = {f.name for f in fields(Settings)}
    for name in names:
        env = os.environ.get(f"CS_{name.upper()}")
        if env is not None:
            values[name] = env
    unknown = set(values) - names
    if unknown:
        raise ValueError(f"Unknown setting(s) in config: {sorted(unknown)}")
    settings = replace(Settings(), **{name: _coerce(name, value) for name, value in values.items()})
    if settings.sheet_write not in ("off", "button", "auto"):
        raise ValueError("sheet_write must be off, button or auto")
    datetime.strptime(settings.poll_at, "%H:%M")  # fail at start, not at the first poll
    return settings

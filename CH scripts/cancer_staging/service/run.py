"""Service process: the web page plus the daily poll. Started by the Prefect flow.

    python -m service.run [--no-poll] [--no-send]

--no-poll: page only. --no-send: nobody can send to RIS from this process (preview).
"""

from __future__ import annotations

import argparse
import threading
import traceback
from dataclasses import replace
from datetime import datetime, timedelta, timezone

from tnm_catalog import load_catalog

from .config import APP_DIR, Settings, load_settings
from .core import App
from .sheets import SheetClient
from .store import Store
from .sync import run_cycle
from .web import build_server


def build_app(settings: Settings | None = None) -> App:
    settings = settings or load_settings()
    settings.data_dir.mkdir(parents=True, exist_ok=True)
    store = Store(settings.db_path)
    sheet = SheetClient(settings.sheet_id, settings.sheet_gid, settings.service_account_key)
    return App(settings, store, sheet, load_catalog(cache_path=APP_DIR / "catalog_cache.json"))


def seconds_until(poll_at: str, now: datetime | None = None) -> float:
    """Seconds from `now` (local time) to the next HH:MM."""
    now = now or datetime.now()
    hour, minute = (int(part) for part in poll_at.split(":"))
    target = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if target <= now:
        target += timedelta(days=1)
    return (target - now).total_seconds()


def poll_once(app: App) -> None:
    try:
        result = run_cycle(app.store, app.settings, app.sheet, app.catalog)
        print(f"[poll {datetime.now():%m-%d %H:%M}] {result}", flush=True)
    except Exception as exc:
        app.store.log("poll_error", error=f"{type(exc).__name__}: {exc}"[:300])
        print(f"[poll {datetime.now():%m-%d %H:%M}] ERROR {type(exc).__name__}: {exc}", flush=True)
        traceback.print_exc()


def poll_forever(app: App, stop: threading.Event) -> None:
    """One poll each day at `poll_at`; one at start only if the last poll is older than a day."""
    last = app.store.get_meta("last_sheet_sync")
    if not last or datetime.now(timezone.utc) - datetime.fromisoformat(last) > timedelta(hours=24):
        poll_once(app)
    while not stop.wait(seconds_until(app.settings.poll_at)):
        poll_once(app)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--no-poll", action="store_true")
    parser.add_argument("--no-send", action="store_true")
    args = parser.parse_args(argv)
    settings = load_settings()
    if args.no_send:
        settings = replace(settings, send_enabled=False)
    app = build_app(settings)
    server = build_server(app)
    stop = threading.Event()
    if not args.no_poll:
        threading.Thread(target=poll_forever, args=(app, stop), daemon=True, name="poller").start()
    host, port = server.server_address[:2]
    print(f"Cancer-staging service on http://{host}:{port}/ (public: {app.settings.public_url})", flush=True)
    send_open = (("signed-in doctors: " + ", ".join(app.settings.send_doctors)) if app.settings.send_doctors
                 else "every signed-in doctor") if app.settings.send_enabled else "nobody"
    print(f"Data: {app.settings.data_dir} | poll: {'off' if args.no_poll else app.settings.poll_at} | "
          f"sheet write: {app.settings.sheet_write} | send open for: {send_open}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

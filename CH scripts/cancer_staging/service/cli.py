"""Admin commands of the service (run on gpu-host.example.invalid in the app directory).

    python -m service.cli status
    python -m service.cli sync [--no-ris] [--limit N] [--doctor NAME]
    python -m service.cli events [--limit N] [--accession ACC]
    python -m service.cli set-userid DOCTOR RIS_USERID
    python -m service.cli pending [--doctor NAME]
    python -m service.cli propose --deadline 02:45 [--doctor NAME] [--device cpu --limit 1 --max-new-tokens 900]
    python -m service.cli results [--doctor NAME]
    python -m service.cli redo [--clear]      # the next night job writes every proposal again
"""

from __future__ import annotations

import argparse
import json
import time
from datetime import datetime, timedelta

from batch import load_sent_ledger

from . import propose as propose_mod
from .run import build_app
from .store import OPEN_PHASES, now
from .sync import fetch_ris, sync_sheet


def _deadline_epoch(value: str) -> float:
    """Next HH:MM from now."""
    hour, minute = (int(part) for part in value.split(":"))
    target = datetime.now().replace(hour=hour, minute=minute, second=0, microsecond=0)
    if target <= datetime.now():
        target += timedelta(days=1)
    return target.timestamp()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status")
    sync = sub.add_parser("sync")
    sync.add_argument("--no-ris", action="store_true")
    sync.add_argument("--limit", type=int, default=None, help="RIS fetches in this run")
    sync.add_argument("--doctor", default=None, help="RIS fetch for this doctor's rows only")
    events = sub.add_parser("events")
    events.add_argument("--limit", type=int, default=30)
    events.add_argument("--accession", default=None)
    userid = sub.add_parser("set-userid")
    userid.add_argument("doctor")
    userid.add_argument("ris_userid")
    sub.add_parser("pending").add_argument("--doctor", default=None)
    sub.add_parser("results").add_argument("--doctor", default=None)
    redo = sub.add_parser("redo", help="mark the proposals of today as old (after a rule or catalog change)")
    redo.add_argument("--clear", action="store_true", help="remove the mark")
    prop = sub.add_parser("propose")
    prop.add_argument("--deadline", default="02:45")
    prop.add_argument("--device", default="cuda", choices=["cuda", "cpu"])
    prop.add_argument("--limit", type=int, default=None)
    prop.add_argument("--max-new-tokens", type=int, default=None)
    prop.add_argument("--doctor", default=None, help="only this doctor's cases")
    args = parser.parse_args(argv)

    app = build_app()
    store = app.store
    if args.command == "status":
        print("phases:", store.phase_counts())
        print("last sheet sync:", store.get_meta("last_sheet_sync") or "never")
        print("last RIS fetch:", store.get_meta("last_ris_fetch") or "never")
        by_doctor: dict[str, dict[str, int]] = {}
        for case in store.cases(phases=OPEN_PHASES):
            row = by_doctor.setdefault(case["doctor"], {})
            row[case["phase"]] = row.get(case["phase"], 0) + 1
        for doctor, phases in sorted(by_doctor.items()):
            print(f"  {doctor}: {phases} | RIS user ID {'set' if store.ris_userid(doctor) else 'not set'}")
        print("proposals to write tonight:", len(propose_mod.pending(app)))
    elif args.command == "sync":
        ledger = load_sent_ledger(app.settings.ledger_path)
        print("sheet:", sync_sheet(store, app.sheet.read_rows(), ledger=ledger))
        if not args.no_ris:
            print("ris:", fetch_ris(store, app.settings, app.catalog, limit=args.limit, doctor=args.doctor))
    elif args.command == "events":
        for event in reversed(store.events(args.limit, args.accession)):
            print(event["at"][:19], event["kind"], event["accession"], event["doctor"],
                  json.dumps(event["detail"], ensure_ascii=False))
    elif args.command == "set-userid":
        store.set_ris_userid(args.doctor, args.ris_userid)
        print(f"RIS user ID saved for {args.doctor}")
    elif args.command == "pending":
        print(len(propose_mod.pending(app, args.doctor)))
    elif args.command == "results":
        for case in store.cases(phases=OPEN_PHASES, doctor=args.doctor):
            proposal = (case["review"] or {}).get("proposal", {})
            tnm = f"{proposal.get('t', '')}{proposal.get('n', '')}{proposal.get('m', '')}"
            what = (f"{proposal.get('catalog_id')} {tnm} stage {proposal.get('stage')}" if proposal.get("staging_text")
                    else proposal.get("skip_reason") or case["note"] or "-")
            print(f"{case['source'].get('input_row'):>5} {case['accession']} {case['doctor']} {case['phase']:<12} {what[:110]}")
    elif args.command == "redo":
        # Proposals stay on the page until the night job replaces them. A case that a
        # person edited or approved is never written again.
        store.set_meta(propose_mod.REDO_MARK, "" if args.clear else now())
        store.log("redo_marked", cleared=args.clear)
        print("redo mark:", store.get_meta(propose_mod.REDO_MARK) or "none")
        print("proposals to write tonight:", len(propose_mod.pending(app)))
    elif args.command == "propose":
        started = time.time()
        summary = propose_mod.run(app, deadline_epoch=_deadline_epoch(args.deadline), device=args.device,
                                  limit=args.limit, max_new_tokens=args.max_new_tokens, doctor=args.doctor)
        print(f"[propose] {summary} in {round(time.time() - started)}s", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

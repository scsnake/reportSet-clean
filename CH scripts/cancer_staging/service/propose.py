"""Night job: local-LLM proposals for the cases that have none. Never talks to RIS.

Run it only inside a gpu-scheduler `local-llm` lease (see the Prefect flow):

    python -m service.cli propose --deadline 02:45
"""

from __future__ import annotations

import time
import traceback
from datetime import datetime
from typing import Any

import local_llm
from llm_trial import MODELS, LlamaServer

from .core import App
from .sync import set_entry


REDO_MARK = "redo_before"  # meta key: proposals written before this time are written again


def pending(app: App, doctor: str | None = None) -> list[dict[str, Any]]:
    """Fetched cases (of one doctor, if given) that need a proposal and have no work by a person.

    A case needs one when it has none, or when its proposal is older than the `redo` mark.
    Cases with no proposal come first.
    """
    from .sync import has_human_work

    mark = app.store.get_meta(REDO_MARK)
    cases = [case for case in app.store.cases(phases=("ready",), doctor=doctor)
             if (not case["entry"] or (mark and (case["entry_at"] or "") < mark))
             and not has_human_work(case["review"])]
    return sorted(cases, key=lambda case: bool(case["entry"]))


def run(app: App, *, deadline_epoch: float, device: str = "cuda", limit: int | None = None,
        max_new_tokens: int | None = None, doctor: str | None = None) -> dict[str, Any]:
    cases = pending(app, doctor)[:limit]
    summary: dict[str, Any] = {"pending": len(cases), "done": 0, "statuses": {}}
    if not cases:
        return summary
    key = app.settings.llm_model
    spec = dict(MODELS[key])
    if max_new_tokens:  # smoke test on the CPU
        spec.update(max_new_tokens=max_new_tokens, reasoning_budget=max(0, max_new_tokens - 600))
    label = f"{spec['hf_id']} ({spec['quant']})"
    app.settings.log_dir.mkdir(parents=True, exist_ok=True)
    server = LlamaServer(spec, app.settings.log_dir / f"llama_{datetime.now():%Y%m%d_%H%M}.log",
                         port=18732, device=device)
    stats: list[dict[str, Any]] = []
    server.start()
    try:
        generate = server.make_generate(deadline_epoch, stats)
        for case in cases:
            if time.time() >= deadline_epoch - 60:
                summary["stopped"] = "deadline"
                break
            accession = case["accession"]
            try:
                entry, log = local_llm.propose_case(generate, case["source"], app.catalog, model_label=label)
                status = log.get("status", "")
            except Exception as exc:  # one bad study must not end the night
                app.store.log("proposal_error", accession=accession, doctor=case["doctor"],
                              error=traceback.format_exc()[-400:])
                print(f"[propose] {accession} failed: {type(exc).__name__}", flush=True)
                summary["statuses"]["error"] = summary["statuses"].get("error", 0) + 1
                continue
            entry["warnings"] = [text.replace(" (local LLM trial).", " (local LLM, night job).")
                                 for text in entry.get("warnings", [])]
            set_entry(app.store, accession, entry, by=label, catalog=app.catalog)
            summary["done"] += 1
            summary["statuses"][status] = summary["statuses"].get(status, 0) + 1
            print(f"[propose] {accession} {status} {log.get('seconds', '')}s", flush=True)
    finally:
        server.stop()
    return summary

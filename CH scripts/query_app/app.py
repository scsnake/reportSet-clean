"""FastAPI entrypoint for the confirmed HIS workflow query application."""

from __future__ import annotations

import hashlib
import logging
from datetime import date, timedelta
from pathlib import Path
from typing import Any

import uvicorn
from fastapi import FastAPI, HTTPException, Query
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import HTMLResponse

from his_query import (
    HisQueryService,
    SearchWindow,
    group_laboratory_rows,
    normalize_accession_no,
    normalize_chart_no,
    workflow_catalog,
)


LOGGER = logging.getLogger("his_query_app")
INDEX_PATH = Path(__file__).resolve().with_name("index.html")


def _audit_key(identifier: str) -> str:
    """Return a non-reversible short key for correlating local audit entries."""
    return hashlib.sha256(identifier.encode("ascii")).hexdigest()[:12]


def create_app(service: HisQueryService | None = None) -> FastAPI:
    query_service = service or HisQueryService()
    application = FastAPI(
        title="HIS Confirmed Workflow Query",
        description="Hospital-aware direct queries reconstructed from confirmed HIS workflows",
        version="2.0.0",
    )

    @application.get("/api/health")
    async def health() -> dict[str, Any]:
        config = query_service.config
        return {
            "status": "ok",
            "database_configured": bool(config.db_user and config.db_password),
            "database": f"{config.db_host}:{config.db_port}/{config.db_sid}",
            "nodes": {
                "lab": f"{config.db_host}:{config.db_port}/{config.db_sid}",
                "patient": f"{config.patient_host}:{config.db_port}/{config.patient_sid}",
                "inpatient": f"{config.inpatient_host}:{config.db_port}/{config.inpatient_sid}",
            },
            "hospital_id": config.hospital_id,
        }

    @application.get("/api/workflows")
    async def workflows() -> dict[str, Any]:
        items = workflow_catalog()
        return {
            "workflows": items,
            "available": [item["id"] for item in items if item["implementation"] == "available"],
        }

    @application.get("/api/search/{workflow}")
    async def search_workflow(
        workflow: str,
        chart_no: str = Query(min_length=1, max_length=10),
        start_date: date = Query(default_factory=lambda: date.today() - timedelta(days=730)),
        end_date: date = Query(default_factory=date.today),
    ) -> dict[str, Any]:
        catalog = {item["id"]: item for item in workflow_catalog()}
        workflow_id = workflow.strip().lower()
        item = catalog.get(workflow_id)
        if item is None:
            raise HTTPException(status_code=404, detail="Unknown workflow")
        if item["implementation"] != "available":
            raise HTTPException(
                status_code=409,
                detail="This workflow is mapped but its content query is not yet confirmed.",
            )

        try:
            normalized_chart = normalize_chart_no(chart_no)
            window = SearchWindow.from_dates(start_date, end_date)
            methods = {
                "radiology": query_service.search_radiology,
                "exam_accession": query_service.search_exam_accessions,
                "laboratory": query_service.search_laboratory,
                "pathology": query_service.search_pathology,
                "admission": query_service.search_admissions,
                "inpatient_note": query_service.search_inpatient_notes,
                "opd_note": query_service.search_outpatient_notes,
                "discharge_summary": query_service.search_discharge_summaries,
                "operation_note": query_service.search_operations,
            }
            rows = await run_in_threadpool(methods[workflow_id], normalized_chart, window)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        except Exception as exc:
            LOGGER.exception("Workflow query failed: workflow=%s", workflow_id)
            raise HTTPException(
                status_code=503,
                detail="The HIS database query could not be completed.",
            ) from exc

        LOGGER.info(
            "workflow_query workflow=%s chart_key=%s start=%s end=%s count=%d",
            workflow_id,
            _audit_key(normalized_chart),
            start_date.isoformat(),
            end_date.isoformat(),
            len(rows),
        )
        response = {
            "workflow": workflow_id,
            "chart_no": normalized_chart,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "count": len(rows),
            "results": rows,
            "evidence": item["evidence"],
            "caveat": item.get("caveat"),
        }
        if workflow_id == "laboratory":
            response["groups"] = group_laboratory_rows(rows)
        return response

    @application.get("/api/radiology/{source}/{hospital_id}/{apply_no}")
    async def radiology_detail(source: str, hospital_id: str, apply_no: str) -> dict[str, Any]:
        try:
            result = await run_in_threadpool(
                query_service.radiology_detail,
                source,
                hospital_id,
                apply_no,
            )
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        except Exception as exc:
            LOGGER.exception("Radiology detail query failed: source=%s", source)
            raise HTTPException(
                status_code=503,
                detail="The HIS database query could not be completed.",
            ) from exc
        return {"source": source.upper(), "hospital_id": hospital_id, "apply_no": apply_no, **result}

    @application.get("/api/exam-accessions/{hospital_id}/{apply_no}")
    async def exam_accession_detail(hospital_id: str, apply_no: str) -> dict[str, Any]:
        try:
            result = await run_in_threadpool(
                query_service.exam_accession_detail,
                hospital_id,
                apply_no,
            )
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        except Exception as exc:
            LOGGER.exception("Exam accession detail query failed")
            raise HTTPException(
                status_code=503,
                detail="The HIS database query could not be completed.",
            ) from exc
        return {"hospital_id": hospital_id, "apply_no": apply_no, **result}

    @application.get("/api/accession/{accession_no}")
    async def accession_search(accession_no: str) -> dict[str, Any]:
        try:
            normalized = normalize_accession_no(accession_no)
            rows = await run_in_threadpool(query_service.accession_report, normalized)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        except Exception as exc:
            LOGGER.exception("Accession query failed")
            raise HTTPException(
                status_code=503,
                detail="The HIS database query could not be completed.",
            ) from exc
        LOGGER.info(
            "accession_query accession_key=%s count=%d", _audit_key(normalized), len(rows)
        )
        return {"accession_no": normalized, "count": len(rows), "results": rows}

    @application.get("/api/patient/{chart_no}")
    async def patient_info(chart_no: str) -> dict[str, Any]:
        try:
            normalized_chart = normalize_chart_no(chart_no)
            patient = await run_in_threadpool(query_service.patient_info, normalized_chart)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        except Exception as exc:
            LOGGER.exception("Patient query failed")
            raise HTTPException(
                status_code=503,
                detail="The HIS database query could not be completed.",
            ) from exc
        LOGGER.info(
            "patient_query chart_key=%s found=%s", _audit_key(normalized_chart), patient is not None
        )
        return {"chart_no": normalized_chart, "found": patient is not None, "patient": patient}

    @application.get("/api/inpatient-notes/{admit_no}/{note_date}/{note_time}")
    async def inpatient_note_detail(admit_no: str, note_date: str, note_time: str) -> dict[str, Any]:
        try:
            result = await run_in_threadpool(
                query_service.inpatient_note_detail,
                admit_no,
                note_date,
                note_time,
            )
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        except Exception as exc:
            LOGGER.exception("Inpatient note detail query failed")
            raise HTTPException(
                status_code=503,
                detail="The HIS database query could not be completed.",
            ) from exc
        return {"admit_no": admit_no, "note_date": note_date, "note_time": note_time, **result}

    @application.get("/api/discharge-summaries/{document_no}")
    async def discharge_summary_detail(document_no: str) -> dict[str, Any]:
        try:
            result = await run_in_threadpool(query_service.discharge_summary_detail, document_no)
        except ValueError as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        except Exception as exc:
            LOGGER.exception("Discharge summary detail query failed")
            raise HTTPException(
                status_code=503,
                detail="The HIS database query could not be completed.",
            ) from exc
        return {"document_no": document_no, **result}

    @application.get("/", response_class=HTMLResponse)
    async def index() -> HTMLResponse:
        if not INDEX_PATH.is_file():
            raise HTTPException(status_code=404, detail="Web interface not found")
        return HTMLResponse(INDEX_PATH.read_text(encoding="utf-8"))

    return application


app = create_app()


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8000)

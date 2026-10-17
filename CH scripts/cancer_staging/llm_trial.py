"""Overnight local-LLM trial for the proposal step (runs on gpu-host.example.invalid, never sends to RIS).

For each model in turn: load it once, run every study as its own fresh request
(see local_llm.py), write results after every study, then unload. Stops at a
hard deadline so the 03:00 CheXagent job is not delayed. Launched under the GPU
scheduler's exclusive `local-llm` lease by run_trial.sh.

Outputs in --out/<model_key>/: proposals.json, log.json, review.json (marked as
a trial; batch.py refuses to send it). --out/run.json summarises the run.
"""

from __future__ import annotations

import argparse
import gc
import json
import os
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

LLAMA_SERVER = "/opt/llama.cpp/build/bin/llama-server"
GGUF_DIR = "/opt/gguf"
QWEN_THINKING = {"temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0.0}
GEMMA_SAMPLING = {"temperature": 1.0, "top_p": 0.95, "top_k": 64}

# Model registry. backend "transformers" loads in-process (quant nf4 or bf16);
# backend "llamacpp" runs a private llama-server on a GGUF file. `offload` is
# tried in order until the server loads: [] lets llama.cpp's --fit place
# layers/experts automatically; the rest are explicit fallbacks.
# reasoning_budget caps thinking tokens so the answer always fits.
# minutes caps one model's share of the night; case_seconds caps one request.
MODELS: dict[str, dict[str, Any]] = {
    "qwen3.6-35b-a3b": {
        "backend": "llamacpp",
        "hf_id": "Qwen/Qwen3.6-35B-A3B",
        "gguf": f"{GGUF_DIR}/unsloth/Qwen3.6-35B-A3B-GGUF/Qwen3.6-35B-A3B-UD-Q4_K_S.gguf",
        "quant": "UD-Q4_K_S",
        "offload": [[], ["--n-cpu-moe", "30"], ["--n-cpu-moe", "99"]],
        "sampling": QWEN_THINKING,
        "max_new_tokens": 6000,
        "reasoning_budget": 4000,
        "case_seconds": 360,
        "minutes": 35,
    },
    "gemma-4-26b-a4b": {
        "backend": "llamacpp",
        "hf_id": "google/gemma-4-26B-A4B-it",
        "gguf": f"{GGUF_DIR}/google/gemma-4-26B-A4B-it-qat-q4_0-gguf/gemma-4-26B_q4_0-it.gguf",
        "quant": "QAT q4_0",
        "offload": [[], ["--n-cpu-moe", "16"], ["--n-cpu-moe", "99"]],
        "sampling": GEMMA_SAMPLING,
        "chat_template_kwargs": {"enable_thinking": True},
        "max_new_tokens": 5000,
        "reasoning_budget": 3500,
        "case_seconds": 300,
        "minutes": 25,
    },
    "qwen3.8-27b": {
        "backend": "llamacpp",
        "hf_id": "Qwen/Qwen3.8-27B",
        "gguf": f"{GGUF_DIR}/unsloth/Qwen3.8-27B-GGUF/Qwen3.8-27B-UD-Q3_K_XL.gguf",
        "quant": "UD-Q3_K_XL",
        "offload": [[], ["-ngl", "48"], ["-ngl", "36"]],
        "sampling": QWEN_THINKING,
        "max_new_tokens": 5000,
        "reasoning_budget": 3500,
        "case_seconds": 420,
        "minutes": 40,
    },
    "gemma-4-12b": {
        "backend": "llamacpp",
        "hf_id": "google/gemma-4-12B-it",
        "gguf": f"{GGUF_DIR}/google/gemma-4-12B-it-qat-q4_0-gguf/gemma-4-12b-it-qat-q4_0.gguf",
        "quant": "QAT q4_0",
        "offload": [[], ["-ngl", "40"]],
        "sampling": GEMMA_SAMPLING,
        "chat_template_kwargs": {"enable_thinking": True},
        "max_new_tokens": 5000,
        "reasoning_budget": 3500,
        "case_seconds": 300,
        "minutes": 20,
    },
    "huatuogpt-3-9b": {
        "backend": "llamacpp",
        "hf_id": "FreedomIntelligence/HuatuoGPT-3-9B",
        "gguf": f"{GGUF_DIR}/mradermacher/HuatuoGPT-3-9B-GGUF/HuatuoGPT-3-9B.Q8_0.gguf",
        "quant": "Q8_0",
        "offload": [[], ["-ngl", "28"]],
        "sampling": QWEN_THINKING,
        "max_new_tokens": 5000,
        "reasoning_budget": 3500,
        "case_seconds": 300,
        "minutes": 20,
    },
    "medgemma-4b-bf16": {
        "backend": "transformers",
        "hf_id": "google/medgemma-4b-it",
        "quant": "bf16",
        "max_new_tokens": 900,
        "minutes": 12,
    },
    "deepseek-r1-14b-nf4": {
        "backend": "transformers",
        "hf_id": "deepseek-ai/DeepSeek-R1-Distill-Qwen-14B",
        "quant": "nf4",
        "max_new_tokens": 3500,
        "minutes": 60,
        "system_in_user": True,  # the distill's card advises no system prompt
    },
}
DEFAULT_ORDER = "qwen3.6-35b-a3b,gemma-4-26b-a4b,qwen3.8-27b,gemma-4-12b,huatuogpt-3-9b,medgemma-4b-bf16"


class LlamaServer:
    """A private llama-server for one model, killed with its parent."""

    def __init__(self, spec: dict[str, Any], log_path: Path, *, port: int, device: str):
        self.spec, self.log_path, self.port, self.device = spec, log_path, port, device
        self.proc = None
        self.args: list[str] = []

    def _command(self, offload: list[str]) -> list[str]:
        command = [
            LLAMA_SERVER, "-m", self.spec["gguf"], "--host", "127.0.0.1", "--port", str(self.port),
            "-c", str(self.spec.get("ctx", 12288)), "-np", "1", "--jinja", "--reasoning-format", "deepseek",
            "--no-webui",
        ]
        if self.spec.get("reasoning_budget"):
            command += ["--reasoning-budget", str(self.spec["reasoning_budget"])]
        if self.device == "cpu":
            return command + ["-ngl", "0", "--fit", "off"]
        return command + offload

    def start(self) -> None:
        import signal
        import subprocess
        import urllib.request

        def die_with_parent() -> None:
            import ctypes

            ctypes.CDLL("libc.so.6").prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG

        attempts = self.spec.get("offload", [[]]) if self.device == "cuda" else [[]]
        for offload in attempts:
            self.args = self._command(offload)
            log = open(self.log_path, "a", encoding="utf-8")
            log.write(f"\n$ {' '.join(self.args)}\n")
            log.flush()
            env = dict(os.environ)
            if self.device == "cpu":
                env["CUDA_VISIBLE_DEVICES"] = ""
            self.proc = subprocess.Popen(
                self.args, stdout=log, stderr=subprocess.STDOUT, env=env, preexec_fn=die_with_parent
            )
            deadline = time.time() + 900
            while time.time() < deadline and self.proc.poll() is None:
                try:
                    with urllib.request.urlopen(f"http://127.0.0.1:{self.port}/health", timeout=5) as response:
                        if response.status == 200:
                            return
                except OSError:
                    pass
                time.sleep(3)
            self.stop()  # did not come up with this offload setting; try the next
        raise RuntimeError(f"llama-server did not start; see {self.log_path.name}")

    def stop(self) -> None:
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=30)
            except Exception:
                self.proc.kill()
                self.proc.wait()
        self.proc = None

    def make_generate(self, deadline: float, stats: list[dict[str, Any]]):
        import urllib.request

        spec = self.spec

        def generate(messages: list[dict[str, str]]) -> str:
            body: dict[str, Any] = {
                "messages": messages,
                "max_tokens": spec["max_new_tokens"],
                "seed": 42,
                **spec.get("sampling", {"temperature": 0}),
            }
            if spec.get("chat_template_kwargs"):
                body["chat_template_kwargs"] = spec["chat_template_kwargs"]
            request = urllib.request.Request(
                f"http://127.0.0.1:{self.port}/v1/chat/completions",
                data=json.dumps(body).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )
            timeout = max(30.0, min(spec.get("case_seconds", 600), deadline - time.time()))
            with urllib.request.urlopen(request, timeout=timeout) as response:
                payload = json.loads(response.read().decode("utf-8"))
            message = payload["choices"][0]["message"]
            timings = payload.get("timings", {})
            stats.append(
                {
                    "completion_tokens": payload.get("usage", {}).get("completion_tokens"),
                    "tokens_per_second": round(timings.get("predicted_per_second", 0), 1),
                    "finish_reason": payload["choices"][0].get("finish_reason"),
                }
            )
            reasoning = message.get("reasoning_content") or ""
            content = message.get("content") or ""
            return f"<think>{reasoning}</think>{content}" if reasoning else content

        return generate


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _write(path: Path, payload: Any) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def _gpu_used_mb() -> int | None:
    import subprocess

    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=memory.used", "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=10,
        ).stdout
        return int(out.strip().splitlines()[0])
    except Exception:
        return None


def load_model(spec: dict[str, Any], device: str):
    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig

    kwargs: dict[str, Any] = {"dtype": torch.bfloat16}
    if device == "cuda":
        kwargs["device_map"] = {"": 0}
    if spec["quant"] == "nf4":
        kwargs["quantization_config"] = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_compute_dtype=torch.bfloat16,
            bnb_4bit_use_double_quant=True,
            bnb_4bit_quant_type="nf4",
        )
    tokenizer = AutoTokenizer.from_pretrained(spec["hf_id"])
    model = AutoModelForCausalLM.from_pretrained(spec["hf_id"], **kwargs).eval()
    return model, tokenizer


def make_generate(model, tokenizer, spec: dict[str, Any], deadline: float):
    import torch

    def generate(messages: list[dict[str, str]]) -> str:
        text = tokenizer.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True, **spec.get("chat_kwargs", {})
        )
        # The chat template already carries BOS where the model needs it.
        inputs = tokenizer(text, return_tensors="pt", add_special_tokens=False).to(model.device)
        remaining = max(30.0, deadline - time.time())
        with torch.inference_mode():
            output = model.generate(
                **inputs,
                max_new_tokens=spec["max_new_tokens"],
                max_time=min(remaining, spec.get("case_seconds", 600)),
                do_sample=False,
                pad_token_id=tokenizer.pad_token_id or tokenizer.eos_token_id,
            )
        new_tokens = output[0][inputs["input_ids"].shape[-1]:]
        return tokenizer.decode(new_tokens, skip_special_tokens=True).strip()

    return generate


def run_model(
    key: str,
    spec: dict[str, Any],
    rows: list[dict[str, Any]],
    catalog,
    out_dir: Path,
    *,
    deadline: float,
    device: str,
    limit: int | None,
) -> dict[str, Any]:
    import torch

    import local_llm
    import workflow

    model_dir = out_dir / key
    model_dir.mkdir(parents=True, exist_ok=True)
    backend = spec.get("backend", "transformers")
    summary: dict[str, Any] = {
        "model": key, "hf_id": spec["hf_id"], "quant": spec["quant"], "backend": backend, "started_at": _now(),
    }
    label = f"{spec['hf_id']} ({spec['quant']})"
    model = tokenizer = server = None
    stats: list[dict[str, Any]] = []
    try:
        started = time.monotonic()
        model_deadline = min(deadline, time.time() + spec.get("minutes", 30) * 60)
        if backend == "llamacpp":
            if not Path(spec["gguf"] + ".done").exists():  # marker written by gguf/download.sh
                raise RuntimeError(f"GGUF not fully downloaded: {spec['gguf']}")
            server = LlamaServer(spec, model_dir / "server.log", port=18731, device=device)
            server.start()
            summary["server_args"] = server.args[1:]
            generate = server.make_generate(model_deadline, stats)
        else:
            model, tokenizer = load_model(spec, device)
            generate = make_generate(model, tokenizer, spec, model_deadline)
        summary["load_seconds"] = round(time.monotonic() - started, 1)
        summary["gpu_used_mb_after_load"] = _gpu_used_mb() if device == "cuda" else None
        proposals: dict[str, Any] = {
            "generated_by": label,
            "generated_at": _now(),
            "prompt": local_llm.SYSTEM_PROMPT,
            "cases": {},
        }
        logs: list[dict[str, Any]] = []
        done_rows: list[dict[str, Any]] = []
        for row in rows[:limit]:
            if time.time() >= model_deadline:
                logs.append({"accession": row["accession"], "status": "not-run-deadline"})
                continue
            stats.clear()
            try:
                entry, log = local_llm.propose_case(
                    generate,
                    row,
                    catalog,
                    model_label=label,
                    system_in_user=spec.get("system_in_user", False),
                )
            except Exception as exc:  # one bad study must not end the model run
                entry = {"skip": f"{label} crashed on this study: {exc}"}
                log = {"accession": row["accession"], "status": "error", "error": traceback.format_exc()}
            if stats:
                log["generation"] = list(stats)
            proposals["cases"][row["accession"]] = entry
            logs.append(log)
            done_rows.append(row)
            _write(model_dir / "proposals.json", proposals)
            _write(model_dir / "log.json", logs)
            print(f"[{key}] {row['accession']} {log.get('status')} {log.get('seconds', '')}s", flush=True)
        review = workflow.prepare_review(done_rows, catalog, proposals)
        review["trial"] = {"model": key, "hf_id": spec["hf_id"], "quant": spec["quant"], "not_for_ris": True}
        _write(model_dir / "review.json", review)
        statuses = [log.get("status") for log in logs]
        summary.update(
            {
                "status": "done",
                "cases": len(statuses),
                "counts": {status: statuses.count(status) for status in set(statuses)},
                "peak_vram_gb": round(torch.cuda.max_memory_allocated() / 2**30, 2)
                if device == "cuda" and backend == "transformers"
                else None,
            }
        )
    except Exception as exc:
        summary.update({"status": "failed", "error": f"{type(exc).__name__}: {exc}"})
        (model_dir / "error.txt").write_text(traceback.format_exc(), encoding="utf-8")
        # Keep the reason off stdout: the scheduler reruns the whole job when it
        # sees OOM wording there, but this model's failure is already handled.
        print(f"[{key}] failed; see {key}/error.txt", flush=True)
    finally:
        if server:
            server.stop()
        del model, tokenizer
        gc.collect()
        if device == "cuda":
            torch.cuda.empty_cache()
            torch.cuda.reset_peak_memory_stats()
        summary["finished_at"] = _now()
    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workdir", required=True, help="dir holding the pipeline modules and inputs")
    parser.add_argument("--out", required=True)
    parser.add_argument("--models", default=DEFAULT_ORDER)
    parser.add_argument("--deadline-epoch", type=float, required=True)
    parser.add_argument("--device", default="cuda", choices=["cuda", "cpu"])
    parser.add_argument("--limit", type=int, default=None, help="only the first N studies (smoke test)")
    parser.add_argument("--max-new-tokens", type=int, default=None, help="override every model's budget (smoke test)")
    args = parser.parse_args()
    if args.max_new_tokens:
        for spec in MODELS.values():
            spec["max_new_tokens"] = args.max_new_tokens
            if spec.get("reasoning_budget"):
                spec["reasoning_budget"] = max(0, args.max_new_tokens - 600)

    workdir = Path(args.workdir).resolve()
    sys.path.insert(0, str(workdir))
    os.chdir(workdir)
    from tnm_catalog import load_catalog

    catalog = load_catalog(cache_path=workdir / "catalog_cache.json")
    rows = json.loads((workdir / "cases.json").read_text(encoding="utf-8"))
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    # Library warnings and tracebacks go to a file (fd-level, so CUDA's too);
    # stdout carries only the short status lines the scheduler scans.
    stderr_log = open(out_dir / "stderr.log", "a", encoding="utf-8")
    os.dup2(stderr_log.fileno(), 2)
    sys.stderr = stderr_log
    run: dict[str, Any] = {
        "started_at": _now(),
        "deadline": datetime.fromtimestamp(args.deadline_epoch).isoformat(),
        "cases": [row["accession"] for row in rows[: args.limit]],
        "catalog_sha256": catalog.sha256,
        "models": [],
    }
    for key in [item.strip() for item in args.models.split(",") if item.strip()]:
        if (out_dir / key / "review.json").exists():
            # The scheduler reran the job after an OOM; keep finished models.
            run["models"].append({"model": key, "status": "kept-from-earlier-attempt"})
            continue
        if time.time() >= args.deadline_epoch - 120:
            run["models"].append({"model": key, "status": "not-run-deadline"})
            continue
        run["models"].append(
            run_model(
                key, MODELS[key], rows, catalog, out_dir,
                deadline=args.deadline_epoch, device=args.device, limit=args.limit,
            )
        )
        _write(out_dir / "run.json", run)
    run["finished_at"] = _now()
    _write(out_dir / "run.json", run)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

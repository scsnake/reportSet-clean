"""Prefect flows of the cancer-staging service (copy lives in /opt/prefect-orchestration).

  cancer-staging-service  perpetual: the web page + poll loop, and the reverse tunnel that
                          publishes it on the office PC as http://192.0.2.10:7204/
  cancer-staging-nightly  cron 00:05 (not Friday): local-LLM proposals inside a
                          gpu-scheduler `local-llm` lease, deadline 02:45. Never talks to RIS.

Register after an edit:   PREFECT_API_URL=http://127.0.0.1:4200/api python cancer_staging_flow.py
The source of this file is `CH scripts/cancer_staging/service/flows/` in the reportSet repo.
"""

import os
import subprocess
import threading

from prefect import flow, task

BASE = "/opt/cancer_staging"
APP_DIR = f"{BASE}/app"
PYTHON = f"{BASE}/venv/bin/python"
GPU_SCHEDULER_DIR = "/opt/gpu-scheduler"

TUNNEL_HOST = "ch-office"      # the office PC (192.0.2.10); it already has `GatewayPorts yes`
TUNNEL_REMOTE_PORT = 7204       # office-PC side
SERVICE_PORT = 7206             # local port of service.run (Settings.port)
NIGHT_DEADLINE = "02:45"


def _pipe(proc, prefix=""):
    for line in iter(proc.stdout.readline, ""):
        print(f"{prefix}{line.rstrip()}", flush=True)


def _popen(cmd, **kwargs):
    return subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1, **kwargs)


def _stop(proc, name):
    if proc is None or proc.poll() is not None:
        return
    print(f"[{name}] terminating PID {proc.pid}", flush=True)
    proc.terminate()
    try:
        proc.wait(timeout=10)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait(timeout=2)


def _start_tunnel():
    cmd = [
        "autossh", "-M", "0", "-N",
        "-o", "ServerAliveInterval=30", "-o", "ServerAliveCountMax=3",
        "-o", "ExitOnForwardFailure=yes", "-o", "StrictHostKeyChecking=accept-new", "-o", "ConnectTimeout=10",
        "-R", f"0.0.0.0:{TUNNEL_REMOTE_PORT}:127.0.0.1:{SERVICE_PORT}",
        TUNNEL_HOST,
    ]
    print(f"[tunnel] {' '.join(cmd)}", flush=True)
    # AUTOSSH_GATETIME=0: keep retrying when the office PC is not reachable at start.
    proc = _popen(cmd, env={**os.environ, "AUTOSSH_GATETIME": "0"})
    threading.Thread(target=_pipe, args=(proc, "[tunnel] "), daemon=True).start()
    return proc


@task(name="run-cancer-staging-service", log_prints=True)
def run_service():
    tunnel = _start_tunnel()
    env = {**os.environ, "PYTHONUNBUFFERED": "1", "PYTHONIOENCODING": "utf-8", "CS_PORT": str(SERVICE_PORT)}
    process = _popen([PYTHON, "-u", "-m", "service.run"], cwd=APP_DIR, env=env)
    try:
        _pipe(process)
        process.wait()
        if process.returncode not in (0, -15):
            raise RuntimeError(f"service.run exited with code {process.returncode}")
    finally:
        # A Prefect cancel (SIGTERM) must not leave the server or the tunnel behind.
        _stop(process, "service")
        _stop(tunnel, "tunnel")


@flow(name="cancer-staging-service")
def cancer_staging_service():
    """Cancer-staging web page + sheet/RIS poll loop, published through the office-PC tunnel."""
    run_service()


@task(name="night-proposals", log_prints=True)
def night_proposals():
    env = {**os.environ, "PYTHONUNBUFFERED": "1", "PYTHONIOENCODING": "utf-8"}
    pending = subprocess.run([PYTHON, "-m", "service.cli", "pending"], cwd=APP_DIR, env=env,
                             capture_output=True, text=True, check=True).stdout.strip()
    print(f"cases without a proposal: {pending}", flush=True)
    if pending == "0":
        return  # no GPU lease when there is nothing to do
    cmd = [
        "python3", "-m", "gpu_scheduler", "run", "local-llm", "--vram-gb", "10.5", "--timeout", "1800",
        "--cwd", APP_DIR, "--note", "cancer-staging night proposals", "--",
        PYTHON, "-m", "service.cli", "propose", "--deadline", NIGHT_DEADLINE,
    ]
    print(" ".join(cmd), flush=True)
    process = _popen(cmd, cwd=GPU_SCHEDULER_DIR, env=env)
    try:
        _pipe(process)
        process.wait()
        if process.returncode != 0:
            raise RuntimeError(f"night proposals exited with code {process.returncode}")
    finally:
        _stop(process, "night")


@flow(name="cancer-staging-nightly")
def cancer_staging_nightly():
    """Local-LLM proposals for new cancer-staging cases (GPU through gpu-scheduler)."""
    night_proposals()


if __name__ == "__main__":
    from prefect.runner.storage import LocalStorage
    from prefect.schedules import Cron

    source = LocalStorage(path="/opt/prefect-orchestration")
    cancer_staging_service.from_source(
        source=source, entrypoint="cancer_staging_flow.py:cancer_staging_service",
    ).deploy(name="cancer-staging-service-deploy", work_pool_name="gpu-host.example.invalid-pool", tags=["cancer-staging", "server"],
             ignore_warnings=True)  # no "use .serve" hint: the process work pool is intended
    cancer_staging_nightly.from_source(
        source=source, entrypoint="cancer_staging_flow.py:cancer_staging_nightly",
    ).deploy(
        name="cancer-staging-nightly-deploy", work_pool_name="gpu-host.example.invalid-pool",
        schedules=[Cron("5 0 * * 0-4,6", timezone="Asia/Taipei")],   # 00:05, every night but Friday
        tags=["cancer-staging", "gpu"], ignore_warnings=True,
    )
    print("cancer-staging deployments registered.")

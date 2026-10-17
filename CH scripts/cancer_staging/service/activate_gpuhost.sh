#!/usr/bin/env bash
# On gpu-host: register the two Prefect deployments and (re)start the service flow.
# Starting the flow opens the reverse tunnel: the page becomes reachable on the hospital
# LAN at http://10.0.0.1:7204/ .   usage: bash service/activate_gpuhost.sh
set -eo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ORCH=/opt/prefect-orchestration
# The Prefect flow file lives in the orchestration repo (deployment source).
cp "$HERE/flows/cancer_staging_flow.py" "$ORCH/cancer_staging_flow.py"
cd "$ORCH"
source venv/bin/activate
export PREFECT_API_URL=http://127.0.0.1:4200/api
python cancer_staging_flow.py
python - <<"PY"
import subprocess
import httpx
api = "http://127.0.0.1:4200/api"
flows = {f["id"]: f["name"] for f in httpx.post(api + "/flows/filter", json={}, timeout=20).json()}
active = {"flow_runs": {"state": {"type": {"any_": ["RUNNING", "PENDING"]}}}}
for run in httpx.post(api + "/flow_runs/filter", json=active, timeout=20).json():
    if flows.get(run["flow_id"]) == "cancer-staging-service":
        print("cancelling the old run", run["id"])
        subprocess.run(["prefect", "flow-run", "cancel", run["id"]], check=False)
PY
sleep 5
prefect deployment run cancer-staging-service/cancer-staging-service-deploy
echo "Wait about 20 seconds, then open http://10.0.0.1:7204/"

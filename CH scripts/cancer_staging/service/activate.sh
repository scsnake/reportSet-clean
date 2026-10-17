#!/usr/bin/env bash
# Start (or restart) the service. Works in both places:
#   office PC (Git Bash):  bash service/activate.sh   -> copies the code to gpu-host first
#   gpu-host:                bash service/activate.sh   -> uses the code that is already there
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -d /opt/prefect-orchestration ]; then
  exec bash "$HERE/activate_gpuhost.sh"
fi
HOST="${CS_HOST:-gpu-host}"
bash "$HERE/deploy.sh"
ssh "$HOST" 'bash /opt/cancer_staging/app/service/activate_gpuhost.sh'

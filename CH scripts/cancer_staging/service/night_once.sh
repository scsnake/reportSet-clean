#!/usr/bin/env bash
# One night run of local-LLM proposals on gpu-host, for a single run queued with `at`:
#   echo 'bash /opt/cancer_staging/app/service/night_once.sh 許醫師' | at 00:05
#   usage: night_once.sh [DOCTOR] [DEADLINE_HH:MM]      (no DOCTOR = all doctors)
# Takes the gpu-scheduler `local-llm` lease only when a case needs a proposal.
# It never talks to RIS and never sends anything.
set -u
BASE=/opt/cancer_staging
PY="$BASE/venv/bin/python"
DOCTOR="${1:-}"
DEADLINE="${2:-02:45}"
LOG="$BASE/data/logs/night_$(date +%Y%m%d_%H%M).log"
export PYTHONUNBUFFERED=1 PYTHONIOENCODING=utf-8
mkdir -p "$BASE/data/logs"

cd "$BASE/app"
PENDING="$("$PY" -m service.cli pending ${DOCTOR:+--doctor "$DOCTOR"})"
echo "start=$(date -Is) doctor=${DOCTOR:-all} pending=$PENDING deadline=$DEADLINE" >> "$LOG"
[ "$PENDING" = "0" ] && exit 0

cd /opt/gpu-scheduler
python3 -m gpu_scheduler run local-llm --vram-gb 10.5 --timeout 1800 --cwd "$BASE/app" \
    --note "cancer-staging proposals (${DOCTOR:-all})" -- \
    "$PY" -m service.cli propose --deadline "$DEADLINE" ${DOCTOR:+--doctor "$DOCTOR"} \
    >> "$LOG" 2>&1
echo "exit=$? finished=$(date -Is)" >> "$LOG"

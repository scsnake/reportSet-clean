#!/usr/bin/env bash
# Overnight cancer-staging local-LLM trial on gpu-host. Queued with `at` by
# `main.py trial-schedule`. Takes the GPU scheduler's exclusive `local-llm`
# lease (drains gemma-llm/paddleocr/trocr, restores them on exit), runs
# llm_trial.py, and never talks to RIS.
#   usage: run_trial.sh MODEL_KEYS [DEADLINE_HH:MM]
set -u
CODE_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$CODE_DIR")"
MODELS="${1:?comma-separated model keys}"
DEADLINE="${2:-02:45}"
RUN_ID="$(date +%Y%m%d_%H%M)"
OUT="$BASE_DIR/runs/$RUN_ID"
mkdir -p "$OUT"
chmod 700 "$BASE_DIR"
DEADLINE_EPOCH="$(date -d "$DEADLINE" +%s)"

export HF_HOME=/opt/hf-cache
export HF_HUB_OFFLINE=1          # weights are downloaded beforehand; no network at night
export PYTHONUNBUFFERED=1

echo "run=$RUN_ID models=$MODELS deadline=$DEADLINE start=$(date -Is)" >> "$OUT/trial.log"
cd /opt/gpu-scheduler
# The lease must fit the scheduler's budget (12288 MB - 400 MB margin - Xorg
# etc. ~= 11.1-11.3 GB); 12 GB can never be granted. The models size themselves
# to the free memory anyway (llama.cpp --fit keeps a 1 GB margin).
python3 -m gpu_scheduler run local-llm --vram-gb 10.5 --timeout 1800 \
    --note "cancer-staging local LLM trial $RUN_ID" -- \
    /opt/gemma-llm/.venv/bin/python "$CODE_DIR/llm_trial.py" \
    --workdir "$CODE_DIR" --out "$OUT" --models "$MODELS" \
    --deadline-epoch "$DEADLINE_EPOCH" \
    >> "$OUT/trial.log" 2>&1
echo "exit=$? finished=$(date -Is)" >> "$OUT/trial.log"

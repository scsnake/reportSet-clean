#!/usr/bin/env bash
# Copy the service code to gpu-host and prepare its Python environment.
# Run from Git Bash on the office PC:   bash service/deploy.sh
# It copies the app code only: it does not touch Prefect and does not restart the service.
set -euo pipefail
HOST="${CS_HOST:-gpu-host}"
BASE="/opt/cancer_staging"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"

FILES=(workflow.py classify.py tnm_catalog.py catalog_corrections.py local_llm.py llm_trial.py batch.py api_client.py
       review_ui.py catalog_cache.json review_ui_static service)

ssh "$HOST" "mkdir -p $BASE/app $BASE/data/logs && chmod 700 $BASE $BASE/data"
tar --exclude='__pycache__' --exclude='deploy.sh' -cf - "${FILES[@]}" \
  | ssh "$HOST" "rm -rf $BASE/app/service $BASE/app/review_ui_static && tar -xf - -C $BASE/app"
ssh "$HOST" "export PATH=\"\$HOME/.local/bin:\$PATH\"; cd $BASE \
  && { [ -x venv/bin/python ] || uv venv --quiet --python 3.12 venv; } \
  && uv pip install --quiet --python venv/bin/python 'requests>=2.32' 'google-auth>=2.30' \
  && cd app && ../venv/bin/python -c 'import service.run, service.cli; print(\"import ok\")'"

# The ledger of studies already sent from the office PC: seed it once, never overwrite.
if [ -f sent_ledger.jsonl ] && ! ssh "$HOST" "[ -f $BASE/data/sent_ledger.jsonl ]"; then
  scp -q sent_ledger.jsonl "$HOST:$BASE/data/sent_ledger.jsonl"
  echo "seeded sent_ledger.jsonl"
fi
echo "deployed to $HOST:$BASE/app"

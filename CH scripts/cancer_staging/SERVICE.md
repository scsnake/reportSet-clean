# Cancer-staging service (gpu-host.example.invalid)

The service does the pipeline of `LLM_PROPOSALS.md` automatically, for all doctors.
It runs on gpu-host.example.invalid. Doctors open one web page on the hospital LAN.

## What it does

1. **Poll.** One time each day, at 23:30, it reads the `TNM` tab with the Google service account.
2. **Open cases.** Each `待修正` row becomes a case. Duplicate accessions are skipped.
3. **Fetch from RIS.** It reads each report through WebRIS with the default saved login.
   This step uses GET requests only.
4. **Propose.** At 00:05 (not on Friday) the local LLM writes proposals. It uses the
   `local-llm` lease of gpu-scheduler and stops at 02:45.
5. **Review.** Each doctor sees only their own rows, and edits and approves the text.
6. **Send.** A doctor signs in with their own RIS account and sends approved text with
   their saved RIS login. Each send has a confirmation dialog.
7. **Sheet.** The doctor writes `癌別` and `完成` to the sheet with one button.

## Where things are

| Item | Place |
| --- | --- |
| Web page | `http://192.0.2.10:7204/` (reverse tunnel on the office PC) |
| RIS login page | `http://192.0.2.10:7203/admin/credentials` (WebRIS) |
| Code on gpu-host.example.invalid | `/opt/cancer_staging/app` |
| Python on gpu-host.example.invalid | `/opt/cancer_staging/venv` |
| Database | `/opt/cancer_staging/data/staging.db` (SQLite) |
| Sent ledger | `/opt/cancer_staging/data/sent_ledger.jsonl` |
| Settings | `/opt/cancer_staging/data/config.json` (optional) |
| Service account key | `/opt/cancer_staging/secrets/google_service_account.json` |
| Prefect flow file | `/opt/prefect-orchestration/cancer_staging_flow.py` |
| Source | `service/` in this folder |

## Start it

Run this in Git Bash on the office PC, from this folder:

```bash
bash service/activate.sh
```

Or run it on gpu-host.example.invalid, in `/opt/cancer_staging/app`. There it uses the code that
is already on gpu-host.example.invalid and does not copy anything from the office PC:

```bash
bash service/activate.sh
```

The script does these steps:

1. Copy the code to gpu-host.example.invalid (`service/deploy.sh`).
2. Register the Prefect deployments `cancer-staging-service-deploy` and
   `cancer-staging-nightly-deploy`.
3. Cancel an old service run, then start a new one.

The service flow also keeps the reverse tunnel (`autossh -R 0.0.0.0:7204 → gpu-host.example.invalid:7206`).

## After a reboot of gpu-host.example.invalid

Three systemd units start Prefect: `prefect-server`, `prefect-worker` (pool `gpu-host.example.invalid-pool`)
and `prefect-flows-startup`. The last one runs `startup_flows.py` one time. That script
waits for the Prefect API, cancels stale runs, and starts each flow in `PERPETUAL_FLOWS`.

- **Service flow:** `("cancer-staging-service", "cancer-staging-service-deploy")` is in
  `PERPETUAL_FLOWS` in `/opt/prefect-orchestration/startup_flows.py` (added
  2026-10-07), so the service starts by itself after a reboot.
- **Night flow:** it has a cron schedule. The Prefect server starts it; no line is necessary.

## Restart after a deploy

`bash service/deploy.sh` copies code only. The running service keeps the old code.
Run `bash service/activate.sh` to load the new code.

## What a doctor does

1. Open `http://192.0.2.10:7204/`.
2. Choose your name. The browser remembers it.
3. Review each study. Edit the form or the text, then click **Approve**.
4. To send: click **Sign in with RIS to send**, and type your RIS user ID and password.
   WebRIS checks them with one RIS login. The service does not keep the password.
   The sign-in lasts 12 hours on that browser. Click **Sign out** to end it earlier.
5. If the page shows **Save your RIS login**, open that link and save the login in WebRIS.
6. Send one study or all approved studies:
   - One study: open it, then click **Send to RIS** next to **Approve**.
   - All approved studies: click **Send approved to RIS** in the top bar.
7. Read the confirmation dialog. It shows the RIS account and the exact text of each study.
   Click the send button in the dialog. The service does a dry-run, sends, and reads RIS back.
8. Click **Write to sheet** to set `癌別` and `完成` for the finished rows.

**Auto-send on Approve** is a tick box. With it, each approval goes to RIS immediately,
with no confirmation dialog.

## Who can send

Three conditions are necessary:

- The browser signed in for that name in the last 12 hours (`signin_hours`).
  The RIS account must belong to that doctor: the RIS user name must match the sheet name,
  or the user ID must equal the one set with `service.cli set-userid`.
- The doctor's RIS login is saved in WebRIS. The send uses this saved login.
- `send_doctors` is empty (the default), or it lists the doctor's name.

Anyone on the LAN can review and approve for any name. Only a signed-in browser can send.

The send request carries the accession and the approved-text SHA of each study in the
dialog. The service sends only those studies, and only if the approved text is unchanged.

After 5 failed sign-ins for one name in 15 minutes, the service refuses more sign-ins for
15 minutes. It does not send more passwords to RIS, so RIS does not lock the account.

## Settings

Put only the changed values in `data/config.json`, then restart the service.

| Key | Default | Meaning |
| --- | --- | --- |
| `send_doctors` | `[]` | Empty: every signed-in doctor can send. Otherwise only these names |
| `signin_hours` | `12` | Hours that a RIS sign-in lets a browser send |
| `sheet_write` | `"button"` | `off` = paste-back only, `button`, or `auto` = after each send |
| `poll_at` | `"23:30"` | Time of the daily sheet read (before the night job) |
| `ris_fetch_per_cycle` | `200` | Maximum RIS reads in one poll |
| `llm_model` | `qwen3.6-35b-a3b` | Key in `llm_trial.MODELS` |

## Safety rules in the code

- The service sends only text that the doctor approved, with the same SHA checks as `batch.py`.
- Each send starts with a dry-run. A study that fails the dry-run is not sent.
- The service never sends a study two times. It checks the ledger and the RIS report.
- It never retries a send. A failed read-back shows a warning for a manual check in RIS.
- A sheet write needs: one row with the accession and chart, `完成` = `待修正`, and `癌別`
  empty or equal. The row is found through a temporary row label, not a row number.
- Proposals from the night job never replace a text that a person edited or approved.
- The night job does not connect to RIS.

## Row label test (2026-10-07, on a copy of the sheet)

| Change by another person | Label follows the row |
| --- | --- |
| Insert or delete rows above | Yes |
| Move (drag) the row | Yes |
| Data → Sort range | Yes |
| Sort through the filter header | **No** |
| Cut and paste the cells | **No** |

For the two "No" cases the check before the write refuses, because the label then points
to a different accession. If a filter sort occurs in the 1 second between check and write,
the read-back finds it, restores the other row, and reports an error.

## Single runs (no service, nothing sent)

Use these to try the pipeline before the service runs. Run them on gpu-host.example.invalid in
`/opt/cancer_staging/app`. No command here sends to RIS or writes to the sheet.

```bash
../venv/bin/python -m service.cli sync --doctor 許醫師    # sheet read + read-only RIS fetch
echo 'bash /opt/cancer_staging/app/service/night_once.sh 許醫師' | at 00:05
../venv/bin/python -m service.cli results --doctor 許醫師 # one line for each case
```

Leave out the doctor name to do all doctors. To look at the results in the review page
without the tunnel, start a preview on gpu-host.example.invalid and forward it to the office PC only:

```bash
../venv/bin/python -m service.run --no-poll --no-send    # on gpu-host.example.invalid
ssh -N -L 8767:127.0.0.1:7206 gpu-host.example.invalid                     # on the office PC
```

Then open `http://127.0.0.1:8767/`. With `--no-send`, no name can send from that process.

## Admin commands

Run these on gpu-host.example.invalid in `/opt/cancer_staging/app`, with `../venv/bin/python`:

```bash
../venv/bin/python -m service.cli status
../venv/bin/python -m service.cli sync --limit 5      # one poll now
../venv/bin/python -m service.cli events --limit 30   # audit log
../venv/bin/python -m service.cli set-userid 醫師名 RIS帳號
../venv/bin/python -m service.cli redo                # the next night job writes every proposal again
```

Use `redo` after a change of the model rules or of the catalog corrections. The
proposals stay on the page until the night job replaces them. A case that a person
edited or approved is not written again. `redo --clear` removes the mark.

## Limits to know

- The office PC must stay on. It holds the tunnel.
- Windows Firewall is off on the office PC, so every device that can reach `192.0.2.10`
  can open the page. The page has no login.
- The service cannot see the visitor's IP address through the tunnel.
- `port_monitor_whitelist.json` on gpu-host.example.invalid does not list port 7206 yet.
- Pathology text in the sheet is cut short for some rows. The proposals use what is there.

## Tests

```bash
uv run pytest tests/test_service.py
uv run python tests/service_ui_browser.py --screenshot logs/service_ui.png
```

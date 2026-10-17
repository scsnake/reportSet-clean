# G3PACS stale-study handoff investigation — 2026-09-11

## Summary

After the first RIS study successfully opened in INFINITT PACS, the RIS report page advanced to the next study but the existing `G3PACS.exe` viewer stayed on the previous study. Pressing the report page's manual **PACS** button reproduced the same failure.

The RIS-to-launcher path was working. The failure occurred when a newly launched `G3PACS.exe` instance tried to hand the new study request to the already-running viewer. The new process exited normally, but the existing viewer did not consume the request.

A targeted per-study workaround was confirmed:

1. Terminate only the existing `G3PACS.exe` process.
2. Leave IE, the RIS report page, Java, and the AHK automation running.
3. Press the RIS **PACS** button again.
4. A fresh `G3PACS.exe` starts and opens the current RIS study.

A workstation reboot is the only confirmed way to clear the condition and restore normal subsequent-study handoffs. Restarting only the viewer loads the current study, but the following handoff fails again; it is therefore a workaround, not a recovery.

## Observed normal first launch

At approximately 19:43:13–19:43:21:

1. The RIS report page opened a temporary IE window at `MJB/openimg.jsp`.
2. The temporary window remained responsive and closed normally.
3. The Java 6 browser plug-in started `G3Launcher.exe`.
4. The launch chain continued through `Starter.exe`, `SmartUpdate.exe`, and `InfinittRis.exe`.
5. A persistent `G3PACS.exe` viewer started with `/us:<uuid>.tmp` and `/op:<uuid>.tmp` arguments.
6. The visible INFINITT PACS window loaded the first study.

The process chain was:

```text
IE openimg.jsp
  -> Java 6 plug-in / jp2launcher.exe
    -> G3Launcher.exe
      -> Starter.exe
        -> SmartUpdate.exe
          -> InfinittRis.exe
          -> G3PACS.exe (persistent viewer)
```

## Observed failed second launch

At approximately 19:43:52–19:43:57:

1. RIS correctly advanced to a different accession, chart number, examination time, and examination name.
2. A second temporary IE window was created and closed normally.
3. The Java/G3 launcher chain ran again.
4. A second `G3PACS.exe` process was created while the first viewer remained alive.
5. The second process exited immediately with exit status `0`.
6. The original viewer remained open on the old study.

This is consistent with a single-instance forwarding failure: the transient second process detects the existing viewer and exits successfully after attempting to forward the new `/us` and `/op` request, but the persistent viewer fails to receive or process it.

## Confirmed workaround test

The persistent viewer process was verified by exact image name and executable path, then terminated by PID. IE and RIS were not touched.

After the user pressed the RIS **PACS** button again:

1. `openimg.jsp` opened again.
2. A new Java/G3 launcher chain ran.
3. A fresh persistent `G3PACS.exe` started with a new `/us` and `/op` request pair.
4. The new viewer's study metadata matched the current RIS study.
5. The user confirmed that the new image opened.

## Confirmed recurrence after the workaround

The next report-and-auto-advance cycle reproduced the same fault:

1. RIS advanced correctly from the second study to the third study.
2. The temporary `openimg.jsp` window and complete launcher chain ran again.
3. A new transient `G3PACS.exe` process started and exited normally with status `0`.
4. The persistent viewer remained on the second study.
5. The user confirmed that the third study image did not open.

This shows that the problem is systematic for subsequent handoffs during the affected session, rather than an isolated bad study or one failed popup. Restarting the viewer restores one successful launch, but does not repair its handling of the next single-instance request.

## Post-reboot normal comparison

After rebooting the workstation, the same workflow was traced through three studies. The user confirmed that both the second and third study images matched RIS without restarting G3PACS.

For each successful subsequent-study handoff:

1. RIS advanced and opened the temporary `openimg.jsp` window normally.
2. The Java/G3 launcher chain ran normally.
3. A transient new `G3PACS.exe` process started and exited with status `0`.
4. The original persistent `G3PACS.exe` PID remained alive.
5. The persistent viewer changed its displayed study and rebuilt its internal study windows.

The transient process lifecycle is therefore the same in both healthy and faulty sessions. Its status `0` only indicates that the forwarding client completed; it does not prove that the persistent viewer received or applied the request. The observable discriminator is the persistent viewer: after reboot it changes study and rebuilds child windows, whereas in the faulty session it remains unchanged.

This comparison further localizes the fault to request reception or processing inside the persistent G3PACS instance. The trace does not identify which reboot-reset state causes that receiver to fail.

## Immediate workaround

Use this only when RIS is on the desired study but INFINITT remains on the preceding study:

```powershell
$g3Processes = @(
    Get-CimInstance Win32_Process -Filter "Name='G3PACS.exe'" |
        Where-Object { $_.ExecutablePath -ieq 'C:\INFINITTG3\VIEWER\G3PACS.exe' }
)
if ($g3Processes.Count -eq 1) {
    Stop-Process -Id $g3Processes[0].ProcessId -Force
}
```

Then press the RIS **PACS** button once.

If using the updated AHK source, press **F1** while the C hospital RIS report page is active. F1 first compares the RIS and PACS chart numbers twice. It applies the per-study workaround—restart PACS and click the report page's PACS button once—only when the mismatch persists and the viewer PID belongs to the exact expected executable path. A source reload/rebuild is required before this behavior is active.

The path and count checks intentionally avoid terminating anything if the process identity or state is unexpected. Do not terminate `iexplore.exe`, `java.exe`, `Autorun.exe`, or `AutoHotkey.exe` for this workaround.

## Causes ruled out

- **RIS failed to advance:** ruled out. The RIS DOM and the AHK log showed the new study metadata before the failed PACS handoff.
- **Temporary IE popup was blocked:** ruled out for the captured failure. The second `openimg.jsp` window was observed opening and closing normally.
- **G3 launcher was never called:** ruled out. `G3Launcher`, `Starter`, `SmartUpdate`, and `InfinittRis` all ran on the failed attempt.
- **Hidden IE/G3 window survived after the user closed both applications:** ruled out in the pre-test sweep. No `iexplore.exe`, `G3PACS.exe`, G3 launcher, or related service remained.
- **AHK Shift suppression remained armed:** ruled out. Logical and physical Shift were up, and the `RisHorosSyncSkip.flag` file was absent.
- **RIS/simpleRIS automation selected stale data:** ruled out. Its recorded accession transition was correct.

## Hidden-window observations

`G3PACS.exe` creates many internal MFC windows, including hidden windows titled `INFINITT PACS`, `Lock`, and `WWW_WIN_ASYNC`. Some intermittently do not answer a `WM_NULL` responsiveness probe while the viewer loads. This alone is not proof of a fault because they later respond normally, but one of these windows may participate in the single-instance request receiver.

Several AHK processes also own blank `Internet Explorer_Hidden` helper windows. They were responsive and are internal COM/ActiveX helpers, not orphaned RIS or PACS popup windows.

## Proposed durable workaround automation

A conservative watchdog can automate the confirmed per-study workaround, but it does not repair G3PACS's handoff receiver:

1. On a RIS accession transition, allow the normal PACS handoff time to complete.
2. Compare the current RIS chart number with `INFINITT_PACS.ChartNo_`.
3. If they match, do nothing.
4. If they still differ after a reasonable loading timeout, verify exactly one `G3PACS.exe` exists.
5. Terminate that PID, wait until it exits, and click the current RIS `ImageButton` once.
6. Permit only one automatic retry per RIS accession and log the outcome.

Important safeguards:

- Never kill by the broad `AutoHotkey.exe` image name.
- Never retry repeatedly; one retry per accession prevents a launch loop.
- Do not kill PACS while its displayed chart number already matches RIS.
- Allow for normal PACS loading delay before declaring a mismatch.
- Record the RIS accession transition, old PACS chart, retry PID, and final match status in the debug log.

## Session-only automatic forced-load mode

The AHK workaround now supports escalation after repeated manual use:

1. F1 counts only distinct studies where it actually verified a persistent RIS/PACS mismatch, terminated the exact expected G3PACS PID, and clicked the PACS button successfully.
2. An RIS accession-change hook tracks whether those forced loads occurred on three consecutive studies. Repeated F1 presses on one study do not increase the count, and a study without a forced load breaks the streak.
3. After the third consecutive forced load, a Yes/No dialog offers **automatic forced image loading**.
4. If accepted, each later RIS study transition schedules the same guarded mismatch check automatically.
5. The automatic check waits 4.5 seconds after the accession-change notification, then retains the helper's additional 1.5-second confirmation delay. This gives a normal PACS handoff roughly six seconds to complete before G3PACS can be terminated.
6. At most one automatic attempt is scheduled for each accession. If RIS has moved again, PACS already matches, identity is still unknown/loading, or the executable path is unexpected, no termination occurs.

The mode and its counters exist only in `Autorun.exe` memory. Rerunning `Autorun.exe` restores the default mode with automatic forced loading disabled.

## Diagnostic artifacts

- Monitor script: `tools/monitor_g3pacs.ps1`
- Faulty-session raw capture: `logs/g3pacs_monitor_20260911_194154.log`
- Post-reboot normal raw capture: `logs/g3pacs_monitor_20260911_200722.log`
- RIS/AHK trace: `logs/debug_2026-09-11.log`

The raw logs contain clinical identifiers in window titles and URLs. Keep them local and do not commit or share them without redaction.

## Conclusion

The affected G3PACS session can accept a study passed at process startup, but its already-running single-instance receiver does not accept the next study request. A targeted G3PACS restart followed by one PACS-button click works around one study at a time. Rebooting the workstation is presently the only confirmed way to recover normal multi-study handoffs.

# C hospital RIS Study Transition Safety

## Problem

RIS can expose a mixed DOM during study navigation: identity fields such as
`referno` and `mciname` may already point to the new study while slower fields
still contain the previous study's content.

Observed examples:

- `exam` textarea: after CT -> XR, the new XR accession was visible, but
  `exam.value` still contained the previous CT report. `refresh_info()` copied
  that stale report into the owner GUI, then simpleRIS could pull or push it.
- PACS history (`row_beforereport` / `dbrlist`): `Parse_pacs_hx()` can run
  during the same transition window. Because it caches the parsed table under
  `pacs_hx.data_accno := this.accno`, one premature parse can make later calls
  skip, leaving old or incomplete history for the new accession.

## Implemented Fixes

- On study identity change, `CH_RIS.update_wb()` captures the previous report
  before `get_fields()` overwrites identity state. After reacquiring page
  elements, it clears `reportText.value` only when the current textarea exactly
  matches the previous report. This prevents stale previous-study text from
  being accepted as the new study report.
- On study identity change, PACS history cache is invalidated and a delayed
  forced refresh is armed. While that refresh is pending, non-forced
  `Parse_pacs_hx()` calls defer instead of caching transition data. The delayed
  refresh repeats briefly so late-updating history tables can replace an early
  stale parse.

## TODO

- Treat `remarktx`, `memotx`, and `icdtx` as transition-sensitive clinical
  fields. They do not directly overwrite the report textarea, but stale values
  can affect templates and helper logic.
- Treat action elements (`saveSelectButton`, `ImageButton`, `prerow`,
  `nextrow`) as unsafe while identity is changing or the page is busy.
- Consider a general "stable identity" gate: require the tuple
  `patno + referno + mciname + checktime` to remain unchanged across two reads
  before consuming non-identity DOM fields.
- Consider carrying a DOM content signature for history tables so a delayed
  refresh can prove the table changed, rather than relying only on timed forced
  re-parses.

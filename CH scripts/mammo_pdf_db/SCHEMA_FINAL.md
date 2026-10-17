# Mammo PDF — Consolidated Schema (after FIELDS_TODO_ANS.md review)

## Algorithm (locked)

```
For each form (page 1) of a patient:
  1. text spans       (page.get_text("dict"))                    → typed-overlay values
  2. filled-rect ops  (page.get_drawings, type='f', solid black) → checked checkbox coords
  3. typed-X spans    (text spans starting with 'X')             → "other" annotations
  4. match each (x,y) against form_template.json                 → label / value
NO OCR is used. Page 2 ignored from now on.
```

`form_template.json` maps `(x, y) → {field, value, needs_visual}` with a 4-pt
tolerance. When `needs_visual = yes` AND a checkbox is checked, the AHK GUI
shows an `Open PDF p.N` button so the radiologist reads the handwritten
companion text directly.

---

## Final field list

### Locked (already extracted; unchanged)

| key | type |
|---|---|
| `mg_serial`, `car_plate`, `license_id` | str |
| `national_id`, `name` | str |
| `birth_iso` | str (ISO date) |
| `phone_home`, `phone_mobile` | str |
| `postal`, `address` | str |
| `height_cm`, `weight_kg` | num |
| `menarche_age`, `birth_count`, `first_birth_age` | int |

### A. 支付者

| key | type / values | needs_visual | source |
|---|---|---|---|
| `payer` | enum: `prevention` / `nhi` / `other_gov` / `self_paid` / `other` | `yes` only when value = `other` | 支付者：☐預防保健 ☐健保醫療給付 ☐其他公務預算補助 ☐自費健康檢查 ☐其他 |

(`payer_other_text` dropped — no free-text companion on this row.)

### B. 個人基本資料 — supplementary

| key | type / values | needs_visual | source |
|---|---|---|---|
| `alt_id`   | str (nullable) | no | 統一證號(外籍) — typed overlay |
| `education`| enum: `none` / `elem` / `junior` / `senior` / `college_univ` / `grad` / `decline` | no | 教育：☐無 ☐小學 ☐國(初)中 ☐高中/高職 ☐專科、大學 ☐研究所以上 ☐拒答 |

### C. 病史 / 家族史

| key | type / values | needs_visual | source |
|---|---|---|---|
| `disease_history`           | multi-select: `none` / `breast_benign` / `breast_cancer` / `other_cancer` | `yes` when `other_cancer` ∈ value | 有無得過下列疾病？☐有 ☐乳房良性相關疾病 ☐乳癌 ☐其他癌症：___ ☐無 |
| `family_hx_breast_cancer`   | enum: `yes` / `no` | `yes` when value = `yes` | 家族中是否有人罹患乳癌 ☐無 ☐有 |

(`disease_history_name`, `prior_breast_benign_yn`, `family_hx_relatives`
dropped — relatives table is handled by reopening the PDF when
`family_hx_breast_cancer = yes`.)

### D. 月經史

| key | type / values | needs_visual | source |
|---|---|---|---|
| `menarche_other_text` | str (nullable) | yes | ☐其他：無法填寫此問題的原因：___ |
| `menopause_status`    | enum: `yes` / `no` / `unknown` | auto | 是否已停經？☐是 ☐否 ☐停經狀態未知 |
| `menopause_age`       | int (nullable) | auto | ☐是,停經年齡：__ |
| `menopause_reason`    | enum: `natural` / `hysterectomy` / `oophorectomy` / `other` | `yes` when value = `other` | ☐自然停經 ☐子宮切除 ☐卵巢切除 ☐其他 |

(`hysterectomy_yn`, `oophorectomy_yn` collapsed into `menopause_reason`.)

### E. 生育史

| key | type / values | needs_visual | source |
|---|---|---|---|
| `breastfed_yn` | bool | auto | 是否曾哺乳？☐是 ☐否 |

(`first_live_birth_age`, `breastfeed_months` dropped — same as
`first_birth_age` / not on form.)

### F. 用藥史

| key | type / values | needs_visual | source |
|---|---|---|---|
| `oral_contraceptive_usage` | bool | `yes` when value = true | 是否服用口服避孕藥 ☐是 ☐否 |
| `hrt_usage`                | bool | `yes` when value = true | 是否服用荷爾蒙補充劑 ☐是 ☐否 |

(`hrt_months` dropped.)

### G. 自覺症狀 / 曾接受檢查 / 手術史

| key | type / values | needs_visual | source |
|---|---|---|---|
| `palpable_mass` | multi-select: `mass_or_pain` / `no_symptom` / `never_self_exam` | `yes` when `mass_or_pain` ∈ value | ☐有摸到硬塊或疼痛 ☐沒有症狀 ☐未做過乳房自我檢查 |
| `recent_exam`   | multi-select: `palpation` / `mammo` / `breast_us` / `none_of_above` | no | ☐醫護人員觸診 ☐乳房攝影X光檢查 ☐乳房超音波檢查 ☐以上皆未做過 |
| `op_hx`         | enum encoded: `R` / `L` / `B` / `N` | no | 是否曾接受過乳房手術？☐是+☐左側/☐右側 → R/L/B; ☐否 → N |

(Replaces `prior_mammo_yn` / `prior_mammo_date` / `prior_breast_us_yn` /
`prior_chest_radiation_yn`.)

### H. 其他 — bottom annotations

| key | type | needs_visual | source |
|---|---|---|---|
| `skin_finding_mole`     | bool | yes | `X痣` in `x_marks_json` |
| `skin_finding_polyp`    | bool | yes | `X息肉` |
| `prior_biopsy`          | bool | yes | `X切片` |
| `prior_surgery_no_scar` | bool | yes | `X手術無scar` |
| `other_text`            | str (nullable) | yes | 其他：___ underlined blank |

(`is_first_screen` dropped.)

---

## AHK GUI contract

When a record matches the active study, render:

1. Read-only header with locked typed fields (name, ID, exam date,
   menarche/parity, height/weight, etc.).
2. One button per **needs_visual = yes** field whose checkbox is currently
   selected → opens `pdf_path` at `form_page` in Edge.
3. A generic `Open form (p.N)` button.

Query JSON will emit a `needs_visual` array per record so AHK only renders
buttons for the actually-checked fields.

---

## Open coordinate-pinning task

Each enum / multi-select field above has K options; we know the y-band but
not yet the per-option x. Two paths to finalize:

- **Path 1 (auto)**: for each y-band, sort observed x's left→right and
  assume that order matches the option order printed on the form. Works as
  long as 0 < N < K options were ever checked across patients.
- **Path 2 (manual)**: I render page 1 with checkbox coordinates overlaid
  and you tag each x with its option label.

Path 1 fails for `education` today (9 distinct x at y≈296, but you confirmed
only 7 options visible — so the y-band is bleeding into a neighbor row). I
recommend Path 2 for `education`, Path 1 for the rest.

## Resolved open questions

1. y≈296 row 9 vs 7: caused by neighbor-row bleed. Fix in coord-pinning step.
2. `first_live_birth_age` vs `first_birth_age`: same field; already extracted.
3. Family-history table: not parsed; reopen PDF when `family_hx_breast_cancer = yes`.
4. `payer` "其他公務預算補助": no free-text companion.

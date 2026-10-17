# Mammo PDF — Field Calibration Worksheet

> Edit this file to confirm / correct the proposed schema, then we wire matching.
> Scope: **page 1 of each patient pair only**. Page 2 is ignored going forward.

---

## Algorithm (confirmed)

```
For each form (page 1) of a patient:
  1. Extract positioned text spans  (page.get_text("dict"))      → known field values
  2. Extract filled-rect drawings   (page.get_drawings, type='f', solid black, ~8.5pt sq)
                                    → checked-checkbox coordinates
  3. Extract typed-X annotations    (text spans starting with 'X') → "other" answers
  4. Match each checked coordinate against `form_template.json`  → field label / value
NO OCR is used at any stage.
```

`form_template.json` is the single source of truth for "(x, y) → label".
A small tolerance (default 4 pt) handles minor shifts.

### Free-text companion handling

Some checkboxes have an associated free-text answer (underlined blank, often
handwritten). Two layers in the data:

1. **Typed overlay** — if the answer was typed onto the form, it's in our
   positioned-text spans and we can read it directly (e.g. `disease_name`,
   `menopause_age`).
2. **Handwritten** — if the answer was handwritten, we cannot OCR it cheaply
   on Windows; instead we **flag** the field as `needs_visual`.

When a `needs_visual` checkbox is detected as checked in a record,
`YCH_mammo_Enh.ahk` shows a GUI button labelled with the field name; clicking
it opens the source PDF directly at that record's `form_page` so the
radiologist can read the handwritten text.

Therefore, every checkbox field below has a **`needs_visual`** column:

- `yes` — has a free-text companion. AHK GUI offers an "Open PDF" button when checked.
- `no`  — boolean only; no companion text to inspect.
- `auto` — companion text is reliably typed (in spans); no GUI button needed.

---

## Already extracted (locked)

| key | type | source on form |
|---|---|---|
| `mg_serial`        | str  | top-right `M…` (xray machine serial) |
| `car_plate`        | str  | top header (screening-car licence plate) |
| `license_id`       | str  | top header (govt-issued screening licence id) |
| `national_id`      | str  | 身分證統一編號 |
| `name`             | str  | 姓名 |
| `birth_iso`        | str  | 出生日期 (ROC y/m/d → ISO) |
| `phone_home`       | str  | 電話 |
| `phone_mobile`     | str  | 手機 |
| `postal`           | str  | 郵遞區號 |
| `address`          | str  | 現居住地址 |
| `height_cm`        | num  | 身高 |
| `weight_kg`        | num  | 體重 |
| `menarche_age`     | int  | 初經年齡 |
| `birth_count`      | int  | 生產次數 |
| `first_birth_age`  | int  | 第一胎生產年齡 |

---

## Proposed new fields (please review)

For each block:
- **keep / rename / drop** — write `keep`, the new key, or `drop`.
- **label match** — the exact Chinese label on the form (so we can pin coordinates later).
- **notes** — anything we got wrong.

Where a field maps to a checkbox position, list the candidate `(x, y)` from
the corpus calibration (`search_pdf_db.py template`); blank means "needs the
PDF reopened to identify". Confirm or correct by editing the `(x, y)` cell.

---

### A. Header — payment block

| proposed key | type | label match (Chinese) | candidate (x,y) | needs_visual | keep / rename / drop | notes |
|---|---|---|---|---|---|---|
| `payer`             | enum {nhpa, other_gov, other} | 支付者：☐國民健康署 ☐其他公務預算補助 ☐其他 | (?, ?) | auto | | single-select |
| `payer_other_text`  | str (nullable) | 「其他：___」 underlined blank | n/a (free text) | auto | | only if `payer != nhpa` |

---

### B. Personal basic info — supplementary

| proposed key | type | label match | candidate (x,y) | needs_visual | keep / rename / drop | notes |
|---|---|---|---|---|---|---|
| `alt_id`     | str (nullable) | 統一證號(外籍) | n/a (free text) | auto | | usually empty |
| `education`  | enum {elem, junior, senior, college, univ, grad, decline} | 教育：☐小學(含)以下 ☐國(初)中 ☐高中/高職 ☐專科 ☐大學 ☐研究所以上 ☐拒答 | y≈296 row, 9 obs. coords (`106,133,172,233,300,370,443,221,305`) | no | | y=296 has 9 distinct x; only 7 options expected — please disambiguate |

---

### C. 病史 / 家族史

| proposed key | type | label match | candidate (x,y) | needs_visual | keep / rename / drop | notes |
|---|---|---|---|---|---|---|
| `disease_history_yn`        | bool             | 有無得過下列疾病？☐有 ☐沒有 | (?, ?)  | yes | | "有" usually paired with handwritten 疾病名稱 |
| `disease_history_name`      | str (nullable)   | 疾病名稱：___ | n/a (free text) | yes | | often handwritten |
| `prior_breast_benign_yn`    | bool             | ☐乳房良性疾病/腫瘤 | (?, ?)  | no  | | |
| `family_hx_breast_cancer_yn`| bool             | 家族中是否有人罹患乳癌 ☐有 ☐無 | (?, ?)  | yes | | drives table below |
| `family_hx_relatives`       | obj `{mother, sister, daughter, other}` → `{checked: bool, age: int?}` | 親屬關係 / 罹癌時年齡 表格 | n/a (table cells) | yes | | age cells often handwritten |

---

### D. 月經史

| proposed key | type | label match | candidate (x,y) | needs_visual | keep / rename / drop | notes |
|---|---|---|---|---|---|---|
| `menarche_other_text` | str (nullable) | ☐其他：___ / ☐無法填寫此問題的原因：___ | n/a | yes | | rare; possibly handwritten |
| `menopause_status`    | enum {yes, no, unknown} | 是否已停經？☐是 ☐否 ☐停經狀態未知 | y≈596 + … | auto | | menopause_age is overlay-typed |
| `menopause_age`       | int (nullable)  | ☐是,停經年齡：__ | n/a | auto | | conditional |
| `hysterectomy_yn`     | bool            | ☐曾切除子宮 | (?, ?) | no | | |
| `oophorectomy_yn`     | bool            | ☐曾切除卵巢 | (?, ?) | no | | |

---

### E. 生產史

| proposed key | type | label match | candidate (x,y) | needs_visual | keep / rename / drop | notes |
|---|---|---|---|---|---|---|
| `first_live_birth_age` | int (nullable) | 第一胎活產年齡：__歲 | n/a | auto | | distinct from `first_birth_age`? confirm |
| `breastfed_yn`         | bool            | 是否曾哺乳？☐是 ☐否 | (?, ?) | auto | | |
| `breastfeed_months`    | int (nullable)  | 累計哺乳月數：__ | n/a | auto | | conditional |

---

### F. 用藥史

| proposed key | type | label match | candidate (x,y) | needs_visual | keep / rename / drop | notes |
|---|---|---|---|---|---|---|
| `oral_contraceptive_1y_yn` | bool            | 曾連續服用避孕藥達一年以上 ☐是 ☐否 | y≈627 | no   | | |
| `hrt_yn`                   | bool            | 曾服用荷爾蒙補充劑 ☐是 ☐否 | y≈627 | yes  | | drug name often handwritten |
| `hrt_months`               | int (nullable)  | 服用月數：__ | n/a | auto | | |

---

### G. 是否曾接受相關檢查

| proposed key | type | label match | candidate (x,y) | needs_visual | keep / rename / drop | notes |
|---|---|---|---|---|---|---|
| `prior_mammo_yn`           | bool            | 是否曾接受過乳房攝影檢查 ☐是 ☐否 | y≈661 | auto | | |
| `prior_mammo_date`         | str (nullable)  | 最近一次日期：___ | n/a | yes  | | date often handwritten |
| `prior_breast_us_yn`       | bool            | 是否曾接受乳房超音波 ☐是 ☐否 | y≈683 | auto | | |
| `prior_chest_radiation_yn` | bool            | 胸部曾接受過X光放射治療 ☐是 ☐否 | y≈704–723 | yes  | | indication often handwritten |

---

### H. 其他 — bottom annotations

(Mostly captured today in `x_marks_json`; please confirm we want to lift them
into named flags.)

| proposed key | type | label match | source | needs_visual | keep / rename / drop | notes |
|---|---|---|---|---|---|---|
| `is_first_screen`        | bool | 「首篩」stamp top-left | text span at (x≈20, y≈7) | no  | | observed on some pages |
| `skin_finding_mole`      | bool | X痣        | from `x_marks_json` | no  | | |
| `skin_finding_polyp`     | bool | X息肉      | from `x_marks_json` | no  | | |
| `prior_biopsy`           | bool | X切片      | from `x_marks_json` | yes | | location/date often handwritten next to it |
| `prior_surgery_no_scar`  | bool | X手術無scar | from `x_marks_json` | yes | | site often handwritten |
| `other_text`             | str (nullable) | 其他：___ | underlined blank near bottom | yes | | catch-all; usually handwritten |

---

## Open questions

1. **y≈296 row** has 9 distinct checked positions but 教育 only has 7 options.
   Are 1–2 of these from a different question on the same row (e.g. 婚姻狀況, 族群)?
2. **`first_live_birth_age` vs `first_birth_age`** — same field, or distinct columns
   (i.e., does the form ask both "生產年齡" and "活產年齡")?
3. **Family-history table** — when a relative is "checked" but the age cell is
   empty, do we want `{checked: true, age: null}`, or treat empty as not-checked?
4. **`payer`** — is the line with the underlined blank ("其他公務預算補助：___")
   really an enum option, or always a separate free-text override?

---

## AHK GUI contract (YCH_mammo_Enh.ahk integration)

When a study matches a record in the DB:

1. Show a small popup / panel with the typed fields (name, ID, exam date,
   menarche/parity, height/weight, etc.) — read-only display.
2. For every checkbox field where `needs_visual = yes` AND the box was
   detected as checked in this record, render a button:
       「<field-label>」  →  Open PDF p.<form_page>
   Clicking opens the source PDF in Edge at the form_page so the radiologist
   can read the handwritten companion text directly.
3. Always include a generic 「Open form (p.<form_page>)」 button.

DB query side already has everything needed: each record carries
`pdf_path`, `form_page`, `checkboxes_json` (which positions are checked),
`x_marks_json` (typed-X annotations), and the typed-overlay field values.
The AHK side just needs to know the `needs_visual` flag per field — we'll
emit that in the JSON output once the labels are confirmed.

## Add-your-own (any field we missed?)

| proposed key | type | label match | source | notes |
|---|---|---|---|---|
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |

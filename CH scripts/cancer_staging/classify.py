"""Rules-based 癌別 classifier.

Deterministic regex matching over the four source columns. Result is always shown
to the user for confirmation — see cancer_staging_helper.ahk. No LLM.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable

# Priority order: earlier columns win when multiple rules match different columns.
# Pathology counts only when it states a definite cancer: then it decides the
# template even if the imaging never mentions the primary, and the report
# text (incidental findings such as "lung nodules") is not consulted at all.
# The cancer-committee note outranks the clinical diagnosis and the report.
PRIORITY_COLUMNS = ("patho_txt", "notes_txt", "dx_txt", "report_txt")

DEFINITE_CANCER = re.compile(
    r"carcinoma|malignan|sarcoma|lymphoma|melanoma|myeloma|blastoma|leuk(?:a)?emia|"
    r"gleason|(?-i:\bp?T[0-4])|癌|惡性",
    re.I,
)
NEGATED_CANCER = re.compile(
    r"(?:negative|free)\s+(?:for|of)\s+(?:any\s+)?(?:malignan\w*|carcinoma|tumou?r)|"
    r"no\s+(?:evidence\s+of\s+)?(?:malignan\w*|carcinoma|tumou?r)|"
    r"benign|無(?:明顯)?惡性",
    re.I,
)

# (label, regex). Regex is case-insensitive; `\b` used where meaningful for
# English tokens (Chinese has no word boundaries). Priority within a single
# column is by list order (earlier wins).
RULES: list[tuple[str, re.Pattern[str]]] = [
    ("Lung", re.compile(r"\blung\b|肺(?:癌|腺癌|鱗癌)|adenocarcinoma of\s+lung|NSCLC|SCLC", re.I)),
    ("HCC", re.compile(r"hepatocellular|\bHCC\b|肝(?:細胞)?癌", re.I)),
    ("Cholangiocarcinoma", re.compile(r"cholangi(?:o)?carcinoma|膽管(?:細胞)?癌|klatskin", re.I)),
    ("Breast", re.compile(r"\bbreast\b|乳(?:癌|房癌)|invasive\s+ductal|\bDCIS\b|\bIDC\b|\bILC\b", re.I)),
    ("Colorectal", re.compile(
        r"\bcolon\b|\brectum\b|\brectal\b|c(?:a)?ecum|\bcecal\b|sigmoid|colorectal|"
        r"大腸|直腸|結腸|盲腸|\bCRC\b",
        re.I,
    )),
    ("Gastric", re.compile(r"\bgastric\b|\bstomach\b|胃癌|adenocarcinoma of\s+stomach", re.I)),
    ("Esophageal", re.compile(r"esophag|oesophag|食道", re.I)),
    ("Pancreatic", re.compile(r"pancrea|胰(?:臟|臓|腺)?癌|PDAC", re.I)),
    ("Nasopharyngeal", re.compile(r"nasopharyng|\bNPC\b|鼻咽", re.I)),
    ("Oral cavity", re.compile(r"oral cavity|\btongue\b|口腔|舌癌", re.I)),
    ("Oropharyngeal", re.compile(r"oropharyng|口咽|tonsil", re.I)),
    ("Hypopharyngeal", re.compile(r"hypopharyng|下咽", re.I)),
    ("Laryngeal", re.compile(r"laryng|喉癌|glottic|supraglottic|subglottic", re.I)),
    ("Prostate", re.compile(r"prostate|攝護腺|前列腺", re.I)),
    ("RCC", re.compile(r"renal cell|\bRCC\b|腎(?:細胞)?癌", re.I)),
    ("Urinary bladder", re.compile(r"urothelial|\bbladder\b|膀胱", re.I)),
    ("Ovarian", re.compile(r"\bovar", re.I)),
    ("Endometrial", re.compile(r"endometri|子宮內膜", re.I)),
    ("Cervical", re.compile(r"cervical\s+(?:cancer|carcinoma)|子宮頸|\bcervix\b", re.I)),
    ("GIST", re.compile(r"\bGIST\b|gastrointestinal stromal", re.I)),
    ("Osteosarcoma", re.compile(r"osteosarcoma|骨肉瘤", re.I)),
    ("Cholangiocarcinoma", re.compile(r"膽管", re.I)),  # fallback Chinese-only
]

MAX_SNIPPET = 60


@dataclass
class Guess:
    cancer_type: str
    matched_column: str  # one of PRIORITY_COLUMNS or ""
    matched_snippet: str

    def to_dict(self) -> dict[str, str]:
        return {
            "guess": self.cancer_type,
            "matched_column": self.matched_column,
            "matched_snippet": self.matched_snippet,
        }


def _snippet(text: str, m: re.Match[str]) -> str:
    start = max(0, m.start() - 20)
    end = min(len(text), m.end() + 20)
    s = text[start:end].replace("\n", " ").replace("\r", " ").strip()
    if len(s) > MAX_SNIPPET:
        s = s[: MAX_SNIPPET - 1] + "…"
    return s


def has_definite_cancer(text: str) -> bool:
    """Pathology states a cancer (negated or benign phrases do not count)."""
    return bool(DEFINITE_CANCER.search(NEGATED_CANCER.sub(" ", text or "")))


def classify(row: dict[str, str]) -> Guess:
    """Return the best-matching cancer type across the row's 4 text columns."""
    definite = has_definite_cancer(row.get("patho_txt", ""))
    for col in PRIORITY_COLUMNS:
        if col == "patho_txt" and not definite:
            continue  # benign or equivocal pathology does not pick the template
        if col == "report_txt" and definite:
            continue  # the pathology cancer decides, not incidental imaging findings
        text = row.get(col, "") or ""
        if not text:
            continue
        for label, pat in RULES:
            m = pat.search(text)
            if m:
                return Guess(cancer_type=label, matched_column=col, matched_snippet=_snippet(text, m))
    return Guess(cancer_type="", matched_column="", matched_snippet="")


def classify_many(rows: Iterable[dict[str, str]]) -> list[Guess]:
    return [classify(r) for r in rows]


if __name__ == "__main__":
    import json
    import sys

    if len(sys.argv) > 1:
        payload = json.loads(sys.argv[1])
        g = classify(payload)
    else:
        g = classify(
            {
                "patho_txt": "Invasive ductal carcinoma of the right breast",
                "dx_txt": "",
                "report_txt": "",
                "notes_txt": "",
            }
        )
    print(json.dumps(g.to_dict(), ensure_ascii=False, indent=2))

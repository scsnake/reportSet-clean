"""Local corrections to the cancer-tnm website catalog (AJCC review of 2026-10-08).

`catalog_cache.json` stays an exact copy of the website. `apply()` returns a
corrected copy, and `tnm_catalog.load_catalog` uses it by default. The website
is not ours to edit; `logs/tnm_template_review.html` is the list that went to
its owner. When the owner fixes a template, delete its correction here.

Each correction follows the AJCC version in use for the site in 2026:
Version 9 for lung, nasopharynx, cervix and HPV-associated oropharynx, and the
8th edition for the rest.

Two fields are local additions that the website does not have:

- `Staging_note`: how to choose when one TNM maps to more than one stage group
  (the group needs a factor that the form does not have). The local model and
  the review page show it. The first row that matches is the default.
- `Review_note`: a warning that every proposal of the template shows.
"""

from __future__ import annotations

import copy
from typing import Any, Callable

VERSION = "2026-10-08"

# `update_time` of each corrected template at the review. A different value
# means the website changed the template: review its correction again.
REVIEWED = {
    "Cervix": "2022-09-12T04:06:56.027459Z",
    "Colorectum": "2022-07-27T08:40:27.040313Z",
    "Endometrium": "2019-06-19T09:58:51.769376Z",
    "Esophagus": "2020-11-11T02:44:47.592039Z",
    "GIST": "2019-12-15T15:58:10.835945Z",
    "Hypopharynx": "2022-04-20T10:00:19.627518Z",
    "Intrahepatic_bil_duct": "2019-12-15T15:57:07.234191Z",
    "Lip_Oral_Cavity": "2026-03-25T00:23:03.056331Z",
    "Lung": "2025-02-13T11:03:56.618485Z",
    "OGS_others": "2019-12-15T15:44:22.254874Z",
    "OGS_pelvis": "2019-12-15T15:42:55.073001Z",
    "OGS_spine": "2019-12-15T15:43:07.980872Z",
    "Oropharynx_P16+": "2024-08-14T17:01:38.129654Z",
    "Ovary": "2024-11-25T04:39:16.622241Z",
    "Pancreas": "2019-12-15T16:00:51.317188Z",
    "Prostate": "2025-05-14T03:37:21.002323Z",
    "RCC": "2019-06-19T09:58:51.769376Z",
    "Stomach": "2019-12-15T16:01:13.992791Z",
    "Subglottis": "2019-12-15T16:01:21.300203Z",
    "Urinary_bladder": "2019-12-15T16:01:37.282310Z",
}

Cancer = dict[str, Any]


def _rows(*rows: tuple[str, str]) -> list[dict[str, Any]]:
    """Stage table from (stage, "KEY KEY ...") pairs, in lookup order."""
    return [{"stage": stage, "TNM": keys.split()} for stage, keys in rows]


def _each(ts: str, ns: str) -> str:
    """Every T+N key of the two space-separated code lists."""
    return " ".join(f"{t}{n}" for t in ts.split() for n in ns.split())


def _sub(cancer: Cancer, field: str, code: str, old: str, new: str) -> None:
    """Change part of one definition; the rest stays as the website has it."""
    text = cancer.get(field, {}).get(code)
    if isinstance(text, str):
        cancer[field][code] = text.replace(old, new)


def _without(items: list[str], *drop: str) -> list[str]:
    return [item for item in dict.fromkeys(items) if item not in drop]


def _lung(c: Cancer) -> None:
    # Version 9: T1 N1 is IIA only, and IA is IA1/IA2/IA3. A small tumor with a
    # T2 feature is T2a; the website gave the size only.
    c["T"]["T2a"] = (
        "Tumor >3cm but ≤4 cm; or tumor ≤4 cm that invades the visceral pleura or an adjacent "
        "lobe, involves the main bronchus (not the carina), or causes atelectasis or "
        "obstructive pneumonitis that extends to the hilum"
    )
    c["N"]["N2a"] = "Single N2 station: Metastasis in one ipsilateral mediastinal or subcarinal lymph node station"
    c["N"]["N2b"] = (
        "Multiple N2 stations: Metastasis in more than one ipsilateral mediastinal and/or "
        "subcarinal lymph node station"
    )
    t1, t2 = "T1a T1b T1c", "T2a T2b"
    c["Staging"] = _rows(
        ("IA1", "T1aN0"), ("IA2", "T1bN0"), ("IA3", "T1cN0"), ("IB", "T2aN0"),
        ("IIA", "T2bN0 " + _each(t1, "N1")),
        ("IIB", _each(t2, "N1") + " T3N0 " + _each(t1, "N2a")),
        ("IIIA", _each(t1, "N2b") + " " + _each(t2, "N2a") + " T3N1 T3N2a T4N0 T4N1"),
        ("IIIB", _each(t1, "N3") + " " + _each(t2, "N2b N3") + " T3N2b T4N2a T4N2b"),
        ("IIIC", "T3N3 T4N3"), ("IVA", "M1a M1b"), ("IVB", "M1c1 M1c2"),
    )


def _gist(c: Cancer) -> None:
    # The website had the rows of the intrahepatic bile duct. AJCC 8 groups GIST
    # by site and mitotic rate; N1 is stage IV. Default: gastric, low rate.
    c["Staging"] = _rows(
        ("IA", "T1N0 T2N0"), ("IB", "T3N0"), ("I", "T1N0 T2N0"),
        ("II", "T4N0 T1N0 T2N0 T3N0"), ("IIIA", "T3N0 T1N0 T4N0"), ("IIIB", "T4N0 T2N0 T3N0"),
        ("IV", _each("T1 T2 T3 T4", "N1") + " M1"),
    )
    c["Staging_note"] = (
        "The stage group needs the tumor site and the mitotic rate from pathology (low = 5 or "
        "fewer per 5 mm2). Stomach or omentum, low rate: T1-T2 IA, T3 IB, T4 II; high rate: "
        "T1-T2 II, T3 IIIA, T4 IIIB. Small intestine, esophagus, colorectum, mesentery or "
        "peritoneum, low rate: T1-T2 I, T3 II, T4 IIIA; high rate: T1 IIIA, T2-T4 IIIB. "
        "When the mitotic rate is not stated, use the low-rate group."
    )


def _prostate(c: Cancer) -> None:
    # AJCC 8: T1-T2 N0 M0 is grouped by PSA and Grade Group. The website had the
    # same TNM in two groups, T2cN0 in IIIA, and a "T3c" that is not a category.
    # Default: T alone (AJCC rule when PSA or Grade Group is not available).
    low, all_t = "T1a T1b T1c T2a", "T1a T1b T1c T2a T2b T2c T3a T3b T4"
    organ = _each(low + " T2b T2c", "N0")
    c["Staging"] = _rows(
        ("I", _each(low, "N0")), ("IIA", organ), ("IIB", organ), ("IIC", organ), ("IIIA", organ),
        ("IIIB", "T3aN0 T3bN0 T4N0"), ("IIIC", _each(all_t, "N0")),
        ("IVA", _each(all_t, "N1")), ("IVB", "M1a M1b M1c"),
    )
    c["Staging_note"] = (
        "For N0 M0 the stage group needs the PSA (ng/mL) and the Grade Group (GG: Gleason 6 = "
        "GG1, 3+4 = GG2, 4+3 = GG3, 8 = GG4, 9-10 = GG5). T1-T2 with GG1: PSA < 10 is I for "
        "T1a-T2a and IIA for T2b-T2c; PSA 10 to < 20 is IIA. T1-T2 with PSA < 20: GG2 is IIB, "
        "GG3 or GG4 is IIC. T1-T2 with PSA 20 or more and GG1-GG4 is IIIA. T3-T4 with GG1-GG4 "
        "is IIIB. GG5 with any T and any PSA is IIIC. When PSA or Grade Group is not stated, "
        "use the factors that are stated; with T alone: T1a-T2a I, T2b-T2c IIA, T3-T4 IIIB."
    )
    # Regional nodes are the pelvic nodes below the common iliac bifurcation;
    # common iliac and inguinal nodes are M1a.
    c["N_location"] = _without(c.get("N_location", []), "Common iliac", "Inguinal") + ["Sacral"]
    c["M_location"] = _without(c.get("M_location", []) + ["common iliac lymph nodes", "para-aortic lymph nodes"])


def _endometrium(c: Cancer) -> None:
    # AJCC 8 has no IIIA2 for the corpus uteri: T3a/T3b with N1 is IIIC1.
    t = "T1 T1a T1b T2 T3 T3a T3b"
    c["Staging"] = _rows(
        ("I", "T1N0"), ("IA", "T1aN0"), ("IB", "T1bN0"), ("II", "T2N0"), ("III", "T3N0"),
        ("IIIA", "T3aN0"), ("IIIB", "T3bN0"), ("IIIC1", _each(t, "N1")), ("IIIC2", _each(t, "N2")),
        ("IVA", "T4N0 T4N1 T4N2"), ("IVB", "M1"),
    )
    _gyn_nodes(c)


def _ovary(c: Cancer) -> None:
    # T3b N1 is IIIB, not IIIA2.
    for row in c.get("Staging", []):
        if row.get("stage") == "IIIA2":
            row["TNM"] = _without(row.get("TNM", []), "T3bN1")
    _gyn_nodes(c)


def _gyn_nodes(c: Cancer) -> None:
    # Para-aortic nodes are regional; inguinal nodes are distant (the M text says so).
    c["N_location"] = _without(c.get("N_location", []), "Inguinal", "Para-aortic") + ["Para-aortic"]


def _cervix(c: Cancer) -> None:
    # T1a had the text of T1a2, and T1a N2 returned no stage.
    c["T"]["T1a"] = "Invasive carcinoma diagnosed only by microscopy, with stromal invasion ≤5 mm in depth"
    for row in c.get("Staging", []):
        if row.get("stage") == "IIIC2" and "T1aN2" not in row.get("TNM", []):
            row["TNM"].append("T1aN2")


def _esophagus(c: Cancer) -> None:
    # The website rows are the clinical groups of squamous cell carcinoma. The
    # adenocarcinoma groups come after them, so squamous cell is the default.
    c["Staging"] = list(c.get("Staging", [])) + _rows(
        ("I/IIB", "T1/2N0"), ("IIA/III", "T1/2N1"), ("III", "T3N0 T4aN0 T4aN1"), ("IVA", "T1/2N2 T3N2"),
    )
    c["Staging_note"] = (
        "The stage group depends on the histology. Squamous cell carcinoma: T1/2 N0-N1 I/II, "
        "T3 N0 II, T3 N1 or T1-T3 N2 III, T4 or N3 IVA. Adenocarcinoma: T1/2 N0 I/IIB, "
        "T1/2 N1 IIA/III, T3 N0-N1 or T4a N0-N1 III, N2, N3 or T4b IVA. When the histology "
        "is not stated, use the squamous cell group."
    )


def _ogs_others(c: Cancer) -> None:
    # The website keys had the grade in them (T1N0G1), so no M0 case got a stage.
    # Default: high grade, as conventional osteosarcoma is.
    c["Staging"] = _rows(
        ("IIA", "T1N0"), ("IIB", "T2N0"), ("III", "T3N0"), ("IA", "T1N0"), ("IB", "T2N0 T3N0"),
        ("IVA", "M1a"), ("IVB", "T1N1 T2N1 T3N1 M1b"),
    )
    c["Staging_note"] = (
        "For N0 M0 the stage group needs the histologic grade. High grade (G2-G3, as in "
        "conventional osteosarcoma): T1 IIA, T2 IIB, T3 III. Low grade (G1 or GX): T1 IA, "
        "T2-T3 IB. Use high grade unless pathology states a low-grade tumor."
    )


def _ogs_axial(c: Cancer) -> None:
    _sub(c, "T", "T3", "any nn adjacent segments", "any nonadjacent segments")
    c["Staging"] = []
    c["Review_note"] = "AJCC 8 has no stage groups for bone sarcoma of the spine or the pelvis; the stage is N/A."


def _bladder(c: Cancer) -> None:
    # The general T4 matched no stage row; T4a or T4b decides IIIA or IVA.
    c.get("T", {}).pop("T4", None)
    c["T"]["T4a"] = "Extravesical tumor invades directly into prostatic stroma, seminal vesicles, uterus, vagina"


def _colorectum(c: Cancer) -> None:
    c["Staging_note"] = "With N2a, a T1 tumor is IIIA and a T2 tumor is IIIB."


def _oral_cavity(c: Cancer) -> None:
    # A tumor > 4 cm with DOI > 10 mm is T4a, not T3.
    c["T"]["T3"] = "Tumor ≤ 4 cm with DOI > 10 mm or\nTumor > 4 cm with DOI ≤ 10 mm"
    _sub(c, "T", "T4a", "(oral cavity) Tumor invades adjacent structures only",
         "(oral cavity) Tumor > 4 cm with DOI > 10 mm, or tumor invades adjacent structures only")


def _oropharynx_hpv(c: Cancer) -> None:
    # Version 9 (ACS expert-panel slides, 2026): extranodal extension seen on
    # imaging or examination raises cN1 and cN2 by one category. The clinical
    # stage groups did not change.
    ene = "unequivocal extranodal extension on imaging or examination"
    c["N"]["N1"] = f"One or more ipsilateral lymph nodes, none larger than 6 cm, without {ene}"
    c["N"]["N2"] = (
        f"Ipsilateral lymph node(s), none larger than 6 cm, with {ene}; or contralateral or "
        "bilateral lymph nodes, none larger than 6 cm, without extranodal extension"
    )
    c["N"]["N3"] = f"Lymph node(s) larger than 6 cm; or contralateral or bilateral lymph nodes with {ene}"
    c["Review_note"] = (
        "N follows AJCC Version 9 (diagnosis from 2026-01-01): extranodal extension raises N1 "
        "and N2 by one category. For an earlier diagnosis the 8th edition does not use it."
    )


def _stomach(c: Cancer) -> None:
    # Middle colic nodes are distant, as the retropancreatic and para-aortic nodes are.
    c["N_location"] = _without(c.get("N_location", []), "Middle colic artery")
    c["M_location"] = _without(["Middle colic", *c.get("M_location", [])])


def _intrahepatic(c: Cancer) -> None:
    # The website list was the perihilar one (hepatic ducts), and "hilar" was there twice.
    c["T_location"] = ["Right lobe", "Left lobe", "Bilateral lobes", "S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8"]
    c["N_location"] = _without(c.get("N_location", []))


CORRECTIONS: dict[str, Callable[[Cancer], None]] = {
    "Cervix": _cervix,
    "Colorectum": _colorectum,
    "Endometrium": _endometrium,
    "Esophagus": _esophagus,
    "GIST": _gist,
    "Hypopharynx": lambda c: _sub(c, "T", "T4a", "thyroid gland, or central",
                                  "thyroid gland, esophageal muscle, or central"),
    "Intrahepatic_bil_duct": _intrahepatic,
    "Lip_Oral_Cavity": _oral_cavity,
    "Lung": _lung,
    "OGS_others": _ogs_others,
    "OGS_pelvis": _ogs_axial,
    "OGS_spine": _ogs_axial,
    "Oropharynx_P16+": _oropharynx_hpv,
    "Ovary": _ovary,
    "Pancreas": lambda c: _sub(c, "T", "T1", "<2 cm", "≤2 cm"),
    "Prostate": _prostate,
    "RCC": lambda c: _sub(c, "T", "T1", "< 7 cm", "≤ 7 cm"),
    "Stomach": _stomach,
    "Subglottis": lambda c: _sub(c, "T", "T4a", "invades through the outer cortex of the thyroid cartilage",
                                 "invades cricoid or thyroid cartilage"),
    "Urinary_bladder": _bladder,
}


def apply(snapshot: dict[str, Any]) -> dict[str, Any]:
    """A corrected copy of a website snapshot (the caller sets the new sha256)."""
    out = copy.deepcopy(snapshot)
    for cancer in out.get("documents", []):
        for field in ("T", "N", "M"):
            for code in cancer.get(field, {}):
                _sub(cancer, field, code, "istal metastasis", "istant metastasis")  # "Distal" -> "Distant"
        fix = CORRECTIONS.get(cancer.get("id", ""))
        if fix:
            fix(cancer)
            cancer["corrected"] = VERSION
    out["website_sha256"] = snapshot.get("sha256", "")
    out["corrections"] = VERSION
    return out


def stale(snapshot: dict[str, Any]) -> list[str]:
    """Corrected templates that the website changed after the review."""
    times = {cancer.get("id"): cancer.get("update_time", "") for cancer in snapshot.get("documents", [])}
    return sorted(cancer_id for cancer_id, reviewed in REVIEWED.items() if times.get(cancer_id) != reviewed)

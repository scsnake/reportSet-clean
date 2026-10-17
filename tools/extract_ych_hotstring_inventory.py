from pathlib import Path
import datetime
import json
import re

ROOT = Path(r"C:\Users\raduser\Documents\reportSet")
V2 = Path(r"C:\Users\raduser\Documents\reportSet_v2")
VAULT = Path(r"C:\Users\raduser\Documents\Obsidian Vault")
OUTDIR = VAULT / "YCH Hotstring JS Port"

MODS = [
    ("CT-MR", ROOT / "YCH_Enh.ahk", V2 / "YCH_CTMR.ahk"),
    ("XR", ROOT / "YCH_XR_Enh.ahk", V2 / "YCH_XR.ahk"),
    ("Mammo", ROOT / "YCH_mammo_Enh.ahk", V2 / "YCH_MG.ahk"),
    ("BMD", ROOT / "YCH_BMD.ahk", V2 / "YCH_BMD.ahk"),
]

HOTKEY_RE = re.compile(r"^\s*([^\s;].*?)::(?:\s*(.*))?$")
HOTSTRING_RE = re.compile(r"^\s*:([^:]*):(.+?)::(.*)$")
DIRECTIVE_RE = re.compile(r"^\s*#Hotstring\s*,?\s*(.*)$", re.I)
HOTIF_RE = re.compile(r"^\s*#(If\w*|HotIf)\b\s*,?\s*(.*)$", re.I)
RETURN_RE = re.compile(r"^\s*return\b", re.I)
LABEL_RE = re.compile(r"^\s*[A-Za-z0-9_#$@?]+:\s*(?:;.*)?$")
CALL_NAME_RE = re.compile(r"(?<![A-Za-z0-9_])(dynamic_hotstring|Hotstring)\s*\(", re.I)

KEY_NAMES = set(
    "F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12 Tab Space Enter Return Esc Escape "
    "Up Down Left Right Home End PgUp PgDn AppsKey LButton RButton MButton "
    "WheelUp WheelDown WheelLeft WheelRight Numpad0 Numpad1 Numpad2 Numpad3 "
    "Numpad4 Numpad5 Numpad6 Numpad7 Numpad8 Numpad9 NumpadDot NumpadDiv "
    "NumpadMult NumpadAdd NumpadSub NumpadEnter".split()
)


def strip_comment(s):
    out, inq, esc = [], False, False
    for ch in s:
        if ch == '"' and not esc:
            inq = not inq
        if ch == ";" and not inq:
            break
        out.append(ch)
        esc = ch == "`" and not esc
        if ch != "`":
            esc = False
    return "".join(out).rstrip()


def parse_args(s):
    args, cur, inq, esc, depth = [], [], False, False, 0
    for ch in s:
        if ch == '"' and not esc:
            inq = not inq
        elif not inq:
            if ch in "([{":
                depth += 1
            elif ch in ")]}" and depth:
                depth -= 1
            elif ch == "," and depth == 0:
                args.append("".join(cur).strip())
                cur = []
                continue
        cur.append(ch)
        esc = ch == "`" and not esc
        if ch != "`":
            esc = False
    if cur or s.strip():
        args.append("".join(cur).strip())
    return args


def unquote(s):
    s = s.strip()
    if len(s) >= 2 and s[0] == '"' and s[-1] == '"':
        return s[1:-1]
    return s


class HsContext:
    def __init__(self):
        self.opts = {}
        self.endchars = None

    def apply_directive(self, raw):
        raw = raw.strip()
        if not raw:
            return
        if raw.lower().startswith("endchars"):
            self.endchars = raw[len("endchars") :].strip()
            return
        self.apply_options(raw)

    def apply_options(self, raw):
        for part in re.split(r"\s+", raw.strip()):
            if not part:
                continue
            i = 0
            while i < len(part):
                ch = part[i]
                if ch == ",":
                    i += 1
                    continue
                up = ch.upper()
                if up == "K":
                    m = re.match(r"K-?\d+", part[i:], re.I)
                    self.opts["K"] = m.group(0).upper() if m else "K"
                    i += len(m.group(0)) if m else 1
                elif up in ["B", "P"] and i + 1 < len(part) and part[i + 1].isdigit():
                    self.opts[up] = up + part[i + 1]
                    i += 2
                elif up == "C" and i + 1 < len(part) and part[i + 1] == "1":
                    self.opts["C1"] = "C1"
                    i += 2
                elif up == "S" and i + 1 < len(part) and part[i + 1].upper() in ["I", "E", "P"]:
                    self.opts["SendMode"] = "S" + part[i + 1].upper()
                    i += 2
                elif up in ["*", "?", "O", "C", "Z", "T", "R", "X"]:
                    if i + 1 < len(part) and part[i + 1] == "0":
                        self.opts[up] = up + "0"
                        i += 2
                    else:
                        self.opts[up] = up
                        i += 1
                else:
                    self.opts.setdefault("raw", "")
                    self.opts["raw"] += ch
                    i += 1

    def effective_for(self, local=""):
        c = HsContext()
        c.opts = dict(self.opts)
        c.endchars = self.endchars
        c.apply_options(local)
        bits = [v for k, v in sorted(c.opts.items()) if k != "raw"]
        if c.opts.get("raw"):
            bits.append("raw=" + c.opts["raw"])
        if c.endchars is not None:
            bits.append("EndChars=" + c.endchars)
        return " ".join(bits) if bits else "(default)"


def collect_block(lines, start_idx):
    body, i = [], start_idx + 1
    while i < len(lines):
        line = lines[i]
        if RETURN_RE.match(line):
            return body, i
        if body and (
            DIRECTIVE_RE.match(line)
            or HOTSTRING_RE.match(line)
            or (HOTKEY_RE.match(line) and not line.lstrip().startswith(":"))
        ):
            return body, i - 1
        body.append(line.rstrip("\n"))
        i += 1
    return body, i - 1


def summarize_action(same_line, body):
    if same_line.strip():
        return same_line.strip()
    nonblank = [b.rstrip() for b in body if b.strip()]
    if not nonblank:
        return ""
    joined = "\\n".join(nonblank[:8])
    if len(nonblank) > 8:
        joined += f"\\n... ({len(nonblank) - 8} more lines)"
    return joined


def is_hotkey_candidate(lhs):
    t = lhs.strip()
    if not t or t.startswith(":") or t.startswith("#"):
        return False
    if t.lower() in ["return", "else", "try", "catch"] or t.endswith(")"):
        return False
    if (
        LABEL_RE.match(t + ":")
        and not any(c in t for c in "^!+#~*$&<>")
        and t not in KEY_NAMES
        and not t.isdigit()
    ):
        return False
    if any(c in t for c in "^!+#~*$&<>"):
        return True
    first = re.split(r"\s+|&", t)[0].strip("~*$<>")
    return first in KEY_NAMES or t in KEY_NAMES or re.fullmatch(r"[A-Za-z0-9]", t) is not None


def complete_call(lines, start_idx, start_col):
    text, depth, inq, esc = [], 0, False, False
    for i in range(start_idx, len(lines)):
        segment = strip_comment(lines[i])
        if i == start_idx:
            segment = segment[start_col:]
        text.append(segment.strip())
        for ch in segment:
            if ch == '"' and not esc:
                inq = not inq
            elif not inq:
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        return " ".join(text), i
            esc = ch == "`" and not esc
            if ch != "`":
                esc = False
    return " ".join(text), start_idx


def dynamic_options(args):
    names = ["mode", "clearTrigger", "cond", "forceBreak"]
    bits = []
    for idx, val in enumerate(args[2:6]):
        bits.append(f"{names[idx]}={unquote(val)}")
    return " ".join(bits) if bits else "(none)"


def maybe_dynamic_item(lines, i, clean, current_cond, line_prefix=""):
    m = CALL_NAME_RE.search(clean)
    if not m:
        return None, i
    func = m.group(1)
    call_text, end_idx = complete_call(lines, i, m.start())
    if re.match(r"^(dynamic_hotstring|Hotstring)\s*\([^)]*\)\s*\{", call_text, re.I):
        return None, end_idx
    args_text = call_text.split("(", 1)[1].rsplit(")", 1)[0]
    args = parse_args(args_text)
    if func.lower() == "hotstring" and len(args) >= 3 and "callback" in args[2].lower():
        return None, end_idx
    if func.lower() == "dynamic_hotstring" and len(args) >= 3 and "callback" in args[2].lower():
        return None, end_idx
    trigger = unquote(args[0]) if args else ""
    target = unquote(args[1]) if len(args) > 1 else ""
    item = {
        "type": "dynamic hotstring" if not line_prefix else "dynamic hotstring (v2 reference)",
        "line": f"{line_prefix}{i + 1}" if line_prefix else i + 1,
        "definition": call_text,
        "trigger": trigger,
        "local_options": dynamic_options(args),
        "effective_options": "regex/dynamic matcher",
        "context": current_cond,
        "action": target,
    }
    return item, end_idx


def extract(path, v2path=None):
    lines = path.read_text(encoding="utf-8-sig", errors="replace").splitlines()
    ctx, current_cond, items, i = HsContext(), "", [], 0
    while i < len(lines):
        clean = strip_comment(lines[i])
        dm = DIRECTIVE_RE.match(clean)
        if dm:
            ctx.apply_directive(dm.group(1))
            i += 1
            continue
        hm = HOTIF_RE.match(clean)
        if hm:
            current_cond = clean.strip()
            i += 1
            continue
        dyn, end = maybe_dynamic_item(lines, i, clean, current_cond)
        if dyn:
            items.append(dyn)
            i = end + 1
            continue
        hs = HOTSTRING_RE.match(clean)
        if hs:
            local, trig, repl = hs.group(1), hs.group(2), hs.group(3)
            body, end = [], i
            if not repl.strip():
                body, end = collect_block(lines, i)
            items.append(
                {
                    "type": "hotstring",
                    "line": i + 1,
                    "definition": f":{local}:{trig}::",
                    "trigger": trig,
                    "local_options": local or "(none)",
                    "effective_options": ctx.effective_for(local),
                    "context": current_cond,
                    "action": summarize_action(repl, body),
                }
            )
            i = max(i + 1, end + 1)
            continue
        hk = HOTKEY_RE.match(clean)
        if hk and not HOTSTRING_RE.match(clean):
            lhs, rhs = hk.group(1).strip(), (hk.group(2) or "").strip()
            if is_hotkey_candidate(lhs):
                body, end = [], i
                if not rhs:
                    body, end = collect_block(lines, i)
                items.append(
                    {
                        "type": "hotkey",
                        "line": i + 1,
                        "definition": lhs + "::",
                        "trigger": lhs,
                        "local_options": "n/a",
                        "effective_options": "n/a",
                        "context": current_cond,
                        "action": summarize_action(rhs, body),
                    }
                )
                i = max(i + 1, end + 1)
                continue
        i += 1

    if v2path and v2path.exists():
        v2lines = v2path.read_text(encoding="utf-8-sig", errors="replace").splitlines()
        j = 0
        while j < len(v2lines):
            clean = strip_comment(v2lines[j])
            dyn, end = maybe_dynamic_item(v2lines, j, clean, "", "v2:")
            if dyn and dyn["definition"].lower().startswith("dynamic_hotstring"):
                dyn["effective_options"] = "v2 DynamicHotstring regex matcher"
                items.append(dyn)
                j = end + 1
            else:
                j += 1
    return items


def esc_cell(s):
    s = "" if s is None else str(s)
    return s.replace("\r", "").replace("\n", "<br>").replace("|", "\\|")


def make_md(name, source, v2source, items):
    counts = {}
    for it in items:
        counts[it["type"]] = counts.get(it["type"], 0) + 1
    lines = [f"# YCH {name} Hotstring-Hotkey Inventory", "", f"- Source: `{source}`"]
    if v2source and v2source.exists():
        lines.append(f"- v2 reference: `{v2source}`")
    lines += [
        f"- Generated: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"- Total items: {len(items)}",
        "",
    ]
    for k in sorted(counts):
        lines.append(f"- {k}: {counts[k]}")
    lines += [
        "",
        "Notes: `#Hotstring` directives are not listed as rows. Their active state is folded into `effective options` for each hotstring row. Hotkey rows use `n/a` for hotstring options.",
        "",
        "| type | line | trigger | definition | local options | effective options | context | action / replacement |",
        "|---|---:|---|---|---|---|---|---|",
    ]
    for it in items:
        lines.append(
            "| "
            + " | ".join(
                esc_cell(it.get(k, ""))
                for k in [
                    "type",
                    "line",
                    "trigger",
                    "definition",
                    "local_options",
                    "effective_options",
                    "context",
                    "action",
                ]
            )
            + " |"
        )
    return "\n".join(lines) + "\n"


def main():
    OUTDIR.mkdir(parents=True, exist_ok=True)
    summary = []
    for name, src, v2src in MODS:
        items = extract(src, v2src)
        out = OUTDIR / f"YCH {name} Hotstring Hotkey Inventory.md"
        out.write_text(make_md(name, src, v2src, items), encoding="utf-8")
        summary.append(
            {
                "name": name,
                "path": str(out),
                "items": len(items),
                "counts": {
                    t: sum(1 for it in items if it["type"] == t)
                    for t in sorted(set(it["type"] for it in items))
                },
            }
        )
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

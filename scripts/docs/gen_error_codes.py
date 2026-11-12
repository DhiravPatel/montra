#!/usr/bin/env python3
"""Regenerate the coded-error tables in docs/API.md from the backend source.

Every `apperr.Rule("code", "message", ...)` (422 DOMAIN_RULE_VIOLATION) and
`apperr.ConflictCode("code", "message", ...)` (409 CONFLICT) in non-test Go
files under backend/internal becomes one table row with the first message
found for that code. The tables live between the GENERATED markers in the
"Domain rule codes" section, so clients have one place to look when they
localize `error.details[0].code`.

Usage: python3 scripts/docs/gen_error_codes.py [--check]
  --check  exit 1 when docs/API.md is out of date (for CI).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SRC = ROOT / "backend" / "internal"
DOC = ROOT / "docs" / "API.md"
BEGIN = "<!-- BEGIN GENERATED: error codes (scripts/docs/gen_error_codes.py) -->"
END = "<!-- END GENERATED: error codes -->"

CALL = re.compile(
    r'apperr\.(Rule|ConflictCode)\(\s*"([a-z0-9_]+)"\s*,\s*'
    r'(?:fmt\.Sprintf\(\s*)?"((?:[^"\\]|\\.)*)"(\s*\+)?',
    re.S,
)


def collect():
    rules, conflicts = {}, {}
    for path in sorted(SRC.rglob("*.go")):
        if path.name.endswith("_test.go"):
            continue
        text = path.read_text(encoding="utf-8")
        for kind, code, msg, concat in CALL.findall(text):
            msg = msg.replace('\\"', '"').strip()
            # Placeholders and run-time values are not part of the example.
            msg = re.sub(r"%[-+ #0]*\d*(?:\.\d+)?[a-zA-Z]", "…", msg)
            if concat:
                msg = msg.rstrip(" (") + " …"
            target = rules if kind == "Rule" else conflicts
            target.setdefault(code, msg.replace("|", "\\|"))
    return rules, conflicts


def table(rows):
    out = ["| Code | Example message |", "|---|---|"]
    out += [f"| `{code}` | {msg} |" for code, msg in sorted(rows.items())]
    return "\n".join(out)


def render():
    rules, conflicts = collect()
    both = sorted(set(rules) & set(conflicts))
    if both:
        sys.exit("a code must keep one HTTP status; used as both 422 and 409: " + ", ".join(both))
    return "\n".join([
        BEGIN,
        "",
        f"### 422 `DOMAIN_RULE_VIOLATION` ({len(rules)} codes)",
        "",
        table(rules),
        "",
        f"### 409 `CONFLICT` ({len(conflicts)} codes)",
        "",
        "Conflicts that depend on a record's current state carry a code too",
        "(`VERSION_CONFLICT` and the idempotency conflicts have their own",
        "top-level codes and no detail code).",
        "",
        table(conflicts),
        "",
        END,
    ])


def main():
    doc = DOC.read_text(encoding="utf-8")
    if BEGIN not in doc or END not in doc:
        sys.exit(f"{DOC}: generated-section markers not found")
    head, rest = doc.split(BEGIN, 1)
    _, tail = rest.split(END, 1)
    updated = head + render() + tail
    if "--check" in sys.argv[1:]:
        if updated != doc:
            sys.exit("docs/API.md error-code tables are out of date: run python3 scripts/docs/gen_error_codes.py")
        return
    DOC.write_text(updated, encoding="utf-8")


if __name__ == "__main__":
    main()

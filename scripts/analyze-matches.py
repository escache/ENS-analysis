#!/usr/bin/env python3
"""Parse Sourcegraph SSE matches and classify secret lines."""

import json
import os
import re
import sys

repo = os.environ.get("REPO", "")

PLACEHOLDER_RE = re.compile(
    r"your_|changeme|example|placeholder|xxx+|dummy|test[_-]?key|"
    r"insert[_-]?here|replace[_-]?me|0x\.{3}|\.{3}|<[^>]+>|\[.*\]|TODO|FIXME|"
    r"fake|sample|not[_-]?real|redacted|none|undefined|null",
    re.I,
)
EVM_KEY_RE = re.compile(r"0x[a-fA-F0-9]{64}\b")
HEX_KEY_RE = re.compile(r"\b[a-fA-F0-9]{64}\b")
GHP_RE = re.compile(r"ghp_[A-Za-z0-9]{20,}")
GLPAT_RE = re.compile(r"glpat-[A-Za-z0-9_-]{20,}")
SLACK_RE = re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}")
AWS_KEY_RE = re.compile(r"AKIA[0-9A-Z]{16}")
OPENAI_RE = re.compile(r"sk-[A-Za-z0-9]{20,}")
ANTHROPIC_RE = re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}")
STRIPE_RE = re.compile(r"sk_(live|test)_[A-Za-z0-9]{10,}")
NPM_RE = re.compile(r"npm_[A-Za-z0-9]{30,}")
MNEMONIC_RE = re.compile(r"\b([a-z]+\s+){11,23}[a-z]+\b", re.I)
PRIVATE_BLOCK_RE = re.compile(r"BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY")


def extract_value(line: str) -> str:
    line = line.strip()
    if line.startswith("#"):
        return ""
    if "=" in line:
        return line.split("=", 1)[1].strip().strip('"').strip("'")
    return line


def preview(val: str, n: int = 12) -> str:
    val = val.replace("\t", " ").replace("\n", " ")
    if len(val) <= n * 2 + 3:
        return val
    return f"{val[:n]}...{val[-n:]}"


def classify(path: str, line: str) -> str:
    stripped = line.strip()
    lower_path = path.lower()

    if any(x in lower_path for x in (".example", ".sample", ".template", ".dist")):
        return "example_file"

    if stripped.startswith("#"):
        return "commented"

    val = extract_value(stripped)
    if not val:
        return "empty"

    if PLACEHOLDER_RE.search(val) or PLACEHOLDER_RE.search(stripped):
        return "placeholder"

    checks = [
        EVM_KEY_RE, HEX_KEY_RE, GHP_RE, GLPAT_RE, SLACK_RE,
        AWS_KEY_RE, OPENAI_RE, ANTHROPIC_RE, STRIPE_RE, NPM_RE,
        MNEMONIC_RE, PRIVATE_BLOCK_RE,
    ]
    for rx in checks:
        if rx.search(val) or rx.search(stripped):
            return "potential_leak"

    if len(val) >= 20 and not PLACEHOLDER_RE.search(val):
        return "unknown"

    return "placeholder"


def main() -> None:
    for raw in sys.stdin:
        if not raw.startswith("data: "):
            continue
        try:
            payload = json.loads(raw[6:])
        except json.JSONDecodeError:
            continue
        if not isinstance(payload, list):
            continue
        for match in payload:
            if match.get("type") != "content":
                continue
            path = match.get("path", "")
            for lm in match.get("lineMatches", []):
                line = lm.get("line", "")
                line_no = lm.get("lineNumber", "")
                status = classify(path, line)
                val = extract_value(line.strip())
                prev = preview(val)
                cols = [repo, path, str(line_no), status, prev, line.replace("\t", " ")]
                print("\t".join(cols))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Visit each flagged GitHub repo/file and extract key strings from live source.

Usage:
  python3 scripts/extract-keys.py                    # all crypto + anthropic leaks
  python3 scripts/extract-keys.py --dir analysis/pk-crypto
  python3 scripts/extract-keys.py --tsv analysis/anthropic-key.tsv
  python3 scripts/extract-keys.py --output extracted/keys.tsv
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BRANCH_CACHE: dict[str, str] = {}
SLEEP = float(os.environ.get("EXTRACT_SLEEP", "0.5"))

KEY_PATTERNS = [
    ("evm_hex", re.compile(r"0x[a-fA-F0-9]{64}\b")),
    ("hex64", re.compile(r"(?<![0-9a-fA-F])([a-fA-F0-9]{64})(?![0-9a-fA-F])")),
    ("anthropic", re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}")),
    ("openai", re.compile(r"sk-(?:proj-)?[A-Za-z0-9_-]{20,}")),
    ("mnemonic", re.compile(r"\b(?:[a-z]+\s+){11,23}[a-z]+\b", re.I)),
    ("npm", re.compile(r"npm_[A-Za-z0-9]{30,}")),
    ("ghp", re.compile(r"ghp_[A-Za-z0-9]{20,}")),
]

ENV_VAR_RE = re.compile(
    r"^\s*#?\s*([A-Za-z_][A-Za-z0-9_]*)\s*[=:]\s*(.+?)\s*$"
)

SKIP_PATH = re.compile(
    r"\.example|\.sample|\.fake|\.template|/tests/|__tests__|fixture|\.mdx?$|README",
    re.I,
)

FAMOUS_TEST = re.compile(
    r"abandon abandon|test test test test test test test test test test test junk|"
    r"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80|"
    r"your_|changeme|placeholder|example|xxx+|abcdef1234567890",
    re.I,
)


def parse_repo(repo: str) -> tuple[str, str]:
    repo = repo.removeprefix("github.com/")
    owner, name = repo.split("/", 1)
    return owner, name


def github_api(url: str) -> dict | list | None:
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "ens-analysis-extractor",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode())
    except Exception:
        return None


def default_branch(owner: str, repo: str) -> str:
    key = f"{owner}/{repo}"
    if key in BRANCH_CACHE:
        return BRANCH_CACHE[key]
    data = github_api(f"https://api.github.com/repos/{owner}/{repo}")
    if isinstance(data, dict) and data.get("default_branch"):
        BRANCH_CACHE[key] = data["default_branch"]
        return BRANCH_CACHE[key]
    for branch in ("main", "master", "develop"):
        BRANCH_CACHE[key] = branch
        return branch
    BRANCH_CACHE[key] = "main"
    return "main"


def fetch_raw(owner: str, repo: str, path: str) -> tuple[str | None, str | None]:
    branches = [default_branch(owner, repo), "main", "master", "develop"]
    seen = set()
    for branch in branches:
        if branch in seen:
            continue
        seen.add(branch)
        url = f"https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "ens-analysis-extractor"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                return resp.read().decode("utf-8", errors="replace"), url
        except urllib.error.HTTPError as e:
            if e.code == 404:
                continue
        except Exception:
            continue
    return None, None


def fetch_sourcegraph(owner: str, repo: str, path: str) -> tuple[str | None, str | None]:
    q = f"repo:github.com/{owner}/{repo} file:{path}"
    enc = urllib.parse.quote(q) if False else __import__("urllib.parse").parse.quote(q)
    url = (
        f"https://sourcegraph.com/.api/search/stream?q={enc}"
        f"&patternType=keyword&display=50"
    )
    req = urllib.request.Request(url, headers={"Accept": "text/event-stream", "User-Agent": "ens-analysis"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            for raw in resp:
                line = raw.decode("utf-8", errors="replace")
                if not line.startswith("data: "):
                    continue
                try:
                    payload = json.loads(line[6:])
                except json.JSONDecodeError:
                    continue
                if not isinstance(payload, list):
                    continue
                for match in payload:
                    if match.get("type") != "content":
                        continue
                    lines = []
                    for lm in match.get("lineMatches", []):
                        lines.append(lm.get("line", ""))
                    if lines:
                        sg_url = f"https://github.com/{owner}/{repo}/blob/HEAD/{path}"
                        return "\n".join(lines), sg_url
    except Exception:
        pass
    return None, None


def extract_from_line(line: str) -> list[tuple[str, str, str]]:
    found = []
    stripped = line.strip()
    if not stripped or stripped.startswith("#"):
        return found

    m = ENV_VAR_RE.match(stripped)
    if m:
        var, val = m.group(1), m.group(2).strip().strip('"').strip("'")
        val = val.split("#", 1)[0].strip().strip('"').strip("'")
        if val:
            found.append((var, val, "env"))
        return found

    for kind, rx in KEY_PATTERNS:
        for hit in rx.findall(stripped):
            val = hit if isinstance(hit, str) else hit[0]
            found.append((kind, val, kind))
    return found


def extract_from_content(content: str, target_line: int | None = None) -> list[tuple[str, str, str, int]]:
    results = []
    lines = content.splitlines()
    indices = [target_line - 1] if target_line and 1 <= target_line <= len(lines) else range(len(lines))
    for i in indices:
        if i < 0 or i >= len(lines):
            continue
        for var, val, kind in extract_from_line(lines[i]):
            results.append((var, val, kind, i + 1))
    return results


def load_candidates(tsv_paths: list[Path], statuses: set[str]) -> list[dict]:
    rows = []
    seen = set()
    for path in tsv_paths:
        with path.open() as f:
            reader = csv.DictReader(f, delimiter="\t")
            for row in reader:
                if row.get("status") not in statuses:
                    continue
                if SKIP_PATH.search(row.get("file", "")):
                    continue
                key = (row["repo"], row["file"])
                if key in seen:
                    continue
                seen.add(key)
                line_no = row.get("line_no", "")
                try:
                    ln = int(line_no) if line_no else None
                except ValueError:
                    ln = None
                rows.append(
                    {
                        "preset": path.stem,
                        "repo": row["repo"],
                        "file": row["file"],
                        "line_no": ln,
                        "status": row["status"],
                        "preview": row.get("preview", ""),
                    }
                )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", action="append", default=[])
    parser.add_argument("--tsv", action="append", default=[])
    parser.add_argument("--output", default="extracted/keys.tsv")
    parser.add_argument("--status", default="potential_leak,unknown")
    parser.add_argument("--limit", type=int, default=0)
    args = parser.parse_args()

    statuses = set(args.status.split(","))
    paths: list[Path] = []
    for d in args.dir or ["analysis/pk-crypto", "analysis"]:
        p = Path(d)
        if p.is_dir():
            paths.extend(sorted(p.glob("*.tsv")))
    for t in args.tsv:
        paths.append(Path(t))

    paths = sorted(set(paths))
    if not paths:
        print("No TSV files found", file=sys.stderr)
        return 1

    candidates = load_candidates(paths, statuses)
    if args.limit:
        candidates = candidates[: args.limit]

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)

    print(f"Visiting {len(candidates)} repo/files...", file=sys.stderr)

    with out.open("w", newline="") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(
            [
                "preset",
                "repo",
                "file",
                "line_no",
                "var_name",
                "extracted_value",
                "kind",
                "fetch_status",
                "source_url",
                "is_likely_test",
            ]
        )

        for i, c in enumerate(candidates, 1):
            owner, repo = parse_repo(c["repo"])
            path = c["file"]
            print(f"[{i}/{len(candidates)}] {owner}/{repo} — {path}", file=sys.stderr)

            content, url = fetch_raw(owner, repo, path)
            fetch_status = "ok" if content else "raw_failed"
            if not content:
                content, url = fetch_sourcegraph(owner, repo, path)
                fetch_status = "sourcegraph" if content else "failed"

            time.sleep(SLEEP)

            if not content:
                w.writerow(
                    [c["preset"], c["repo"], path, c["line_no"] or "", "", "", "", fetch_status, "", ""]
                )
                continue

            hits = extract_from_content(content, c["line_no"])
            if not hits:
                # fallback: scan whole file
                hits = extract_from_content(content)

            written = 0
            for var, val, kind, ln in hits:
                if len(val) < 8:
                    continue
                is_test = bool(FAMOUS_TEST.search(val))
                w.writerow(
                    [
                        c["preset"],
                        c["repo"],
                        path,
                        ln,
                        var,
                        val,
                        kind,
                        fetch_status,
                        url or "",
                        "yes" if is_test else "no",
                    ]
                )
                written += 1

            if written == 0:
                w.writerow(
                    [c["preset"], c["repo"], path, c["line_no"] or "", "", "", "", fetch_status, url or "", ""]
                )

    print(f"Wrote {out}", file=sys.stderr)

    # summary
    with out.open() as f:
        rows = list(csv.DictReader(f, delimiter="\t"))
    real = [r for r in rows if r.get("extracted_value") and r.get("is_likely_test") == "no"]
    print(f"Extracted {len(real)} non-test key strings", file=sys.stderr)
    for r in real[:20]:
        print(f"  {r['repo']}:{r['file']}:{r['line_no']} {r['var_name']}={r['extracted_value'][:60]}...", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

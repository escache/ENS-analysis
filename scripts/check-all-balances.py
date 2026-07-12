#!/usr/bin/env python3
"""Check ERC-20 token balances + Solana/Cosmos derivations from extracted keys."""

from __future__ import annotations

import csv
import json
import re
import sys
import time
import urllib.request
from decimal import Decimal
from pathlib import Path

from bip_utils import Bip39SeedGenerator, Bip44, Bip44Changes, Bip44Coins
from eth_account import Account
from web3 import Web3

Account.enable_unaudited_hdwallet_features()

HEX64 = re.compile(r"^(?:0x)?([a-fA-F0-9]{64})$")
MNEMONIC = re.compile(r"^([a-z]+(?:\s+[a-z]+){11,23})$", re.I)
SKIP = re.compile(r"ac0974bec39a17e36ba4a6b4d238ff|abandon abandon|test test test test test test test test test test test junk", re.I)

EVM_RPC = {
    "ethereum": "https://ethereum.publicnode.com",
    "base": "https://base.publicnode.com",
    "polygon": "https://polygon-bor.publicnode.com",
    "arbitrum": "https://arbitrum-one.publicnode.com",
    "bsc": "https://bsc.publicnode.com",
    "optimism": "https://optimism.publicnode.com",
}

# chain -> token -> (address, decimals)
TOKENS = {
    "ethereum": {
        "USDC": ("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 6),
        "USDT": ("0xdAC17F958D2ee523a2206206994597C13D831ec7", 6),
        "DAI": ("0x6B175474E89094C44Da98b94Edeb2A4e4C4C4C4C", 18),
        "WETH": ("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 18),
    },
    "base": {
        "USDC": ("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", 6),
        "USDbC": ("0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA", 6),
    },
    "polygon": {
        "USDC": ("0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", 6),
        "USDT": ("0xc2132D05D31c914a87C6611C10748AEb04B58e8F", 6),
    },
    "arbitrum": {
        "USDC": ("0xaf88d065e77c1cA973D17D1F1A0e0C6Ac2f1e246", 6),
        "USDT": ("0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9", 6),
    },
    "bsc": {
        "USDC": ("0x8AC76a51cc950d9822EDfD4a94d4E3c3c3c3c3c3", 18),
        "USDT": ("0x55d398326f99059fF775485246999027B3197955", 18),
    },
}

ERC20_ABI = [
    {"constant": True, "inputs": [{"name": "_owner", "type": "address"}], "name": "balanceOf",
     "outputs": [{"name": "balance", "type": "uint256"}], "type": "function"},
]

COSMOS_CHAINS = {
    "cosmos": ("https://cosmos-rest.publicnode.com", "uatom", 6),
}

SOLANA_RPC = "https://api.mainnet-beta.solana.com"
SOL_USDC_MINT = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"


def http_json(url: str, data: dict | None = None, timeout: int = 15):
    headers = {"User-Agent": "ens-analysis-balance-check", "Content-Type": "application/json"}
    body = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=body, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode())


def collect_mnemonics() -> list[dict]:
    items, seen = [], set()
    for path in [Path("extracted/crypto-live-keys.tsv"), Path("extracted/pk-crypto-keys.tsv")]:
        if not path.exists():
            continue
        with path.open() as f:
            for row in csv.DictReader(f, delimiter="\t"):
                val = (row.get("extracted_value") or row.get("kind", "")).strip()
                if row.get("kind", "").startswith("mnemonic") or row.get("var_name", "").lower() in ("mnemonic", "seed_phrase"):
                    val = row.get("extracted_value", "").strip()
                m = MNEMONIC.match(val)
                if not m or SKIP.search(val):
                    continue
                if val in seen:
                    continue
                seen.add(val)
                items.append({"repo": row.get("repo", ""), "mnemonic": val})
    return items


def load_evm_addresses() -> list[str]:
    path = Path("extracted/addresses-balances.tsv")
    if not path.exists():
        return []
    addrs = []
    seen = set()
    with path.open() as f:
        for row in csv.DictReader(f, delimiter="\t"):
            a = row.get("address", "")
            if a and a not in seen:
                seen.add(a)
                addrs.append(a)
    return addrs


def derive_solana(mnemonic: str) -> str:
    seed = Bip39SeedGenerator(mnemonic).Generate()
    ctx = Bip44.FromSeed(seed, Bip44Coins.SOLANA)
    return ctx.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT).AddressIndex(0).PublicKey().ToAddress()


def derive_cosmos(mnemonic: str, coin: Bip44Coins) -> str:
    seed = Bip39SeedGenerator(mnemonic).Generate()
    ctx = Bip44.FromSeed(seed, coin)
    return ctx.Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT).AddressIndex(0).PublicKey().ToAddress()


def evm_native(w3: Web3, addr: str) -> Decimal:
    wei = w3.eth.get_balance(Web3.to_checksum_address(addr))
    return Decimal(wei) / Decimal(10**18)


def evm_token(w3: Web3, token: str, addr: str, decimals: int) -> Decimal:
    c = w3.eth.contract(address=Web3.to_checksum_address(token), abi=ERC20_ABI)
    bal = c.functions.balanceOf(Web3.to_checksum_address(addr)).call()
    return Decimal(bal) / Decimal(10**decimals)


def solana_native(addr: str) -> Decimal:
    r = http_json(SOLANA_RPC, {"jsonrpc": "2.0", "id": 1, "method": "getBalance", "params": [addr]})
    lamports = r.get("result", {}).get("value", 0)
    return Decimal(lamports) / Decimal(10**9)


def solana_usdc(owner: str) -> Decimal:
    r = http_json(
        SOLANA_RPC,
        {
            "jsonrpc": "2.0", "id": 1,
            "method": "getTokenAccountsByOwner",
            "params": [owner, {"mint": SOL_USDC_MINT}, {"encoding": "jsonParsed"}],
        },
    )
    total = 0
    for item in r.get("result", {}).get("value", []):
        info = item["account"]["data"]["parsed"]["info"]["tokenAmount"]
        total += int(info["amount"])
    return Decimal(total) / Decimal(10**6)


def cosmos_balance(rest: str, addr: str, denom: str) -> Decimal:
    url = f"{rest}/cosmos/bank/v1beta1/balances/{addr}"
    r = http_json(url)
    for b in r.get("balances", []):
        if b.get("denom") == denom:
            amt = int(b["amount"])
            return Decimal(amt)
    return Decimal(0)


def main():
    out = Path("extracted/full-balance-report.tsv")
    fields = ["chain", "network", "address", "repo", "source", "asset", "balance", "has_funds"]
    rows = []

    # --- EVM native + tokens ---
    evm_addrs = load_evm_addresses()
    print(f"Checking {len(evm_addrs)} EVM addresses for native + ERC-20...", file=sys.stderr)
    w3_cache = {c: Web3(Web3.HTTPProvider(u, request_kwargs={"timeout": 12})) for c, u in EVM_RPC.items()}

    for i, addr in enumerate(evm_addrs, 1):
        print(f"  EVM [{i}/{len(evm_addrs)}] {addr}", file=sys.stderr)
        for chain, w3 in w3_cache.items():
            try:
                native = evm_native(w3, addr)
                if native > 0:
                    rows.append({"chain": "evm", "network": chain, "address": addr, "repo": "", "source": "derived", "asset": "NATIVE", "balance": str(native), "has_funds": "yes"})
            except Exception:
                pass
            for sym, (token, dec) in TOKENS.get(chain, {}).items():
                try:
                    bal = evm_token(w3, token, addr, dec)
                    if bal > 0:
                        rows.append({"chain": "evm", "network": chain, "address": addr, "repo": "", "source": "derived", "asset": sym, "balance": str(bal), "has_funds": "yes"})
                except Exception:
                    pass
            time.sleep(0.02)

    # --- Solana + Cosmos from mnemonics ---
    mnemonics = collect_mnemonics()
    print(f"\nDeriving {len(mnemonics)} mnemonics for Solana/Cosmos...", file=sys.stderr)

    cosmos_coins = [
        ("cosmos", Bip44Coins.COSMOS),
    ]

    for i, item in enumerate(mnemonics, 1):
        m = item["mnemonic"]
        repo = item["repo"]
        print(f"  MNemonic [{i}/{len(mnemonics)}] {repo[:40]}", file=sys.stderr)
        try:
            sol_addr = derive_solana(m)
            sol = solana_native(sol_addr)
            if sol > 0:
                rows.append({"chain": "solana", "network": "mainnet", "address": sol_addr, "repo": repo, "source": "mnemonic", "asset": "SOL", "balance": str(sol), "has_funds": "yes"})
            usdc = solana_usdc(sol_addr)
            if usdc > 0:
                rows.append({"chain": "solana", "network": "mainnet", "address": sol_addr, "repo": repo, "source": "mnemonic", "asset": "USDC", "balance": str(usdc), "has_funds": "yes"})
        except Exception as e:
            print(f"    solana err: {e}", file=sys.stderr)

        for name, coin in cosmos_coins:
            try:
                addr = derive_cosmos(m, coin)
                rest, denom, dec = COSMOS_CHAINS[name]
                raw = cosmos_balance(rest, addr, denom)
                bal = raw / Decimal(10**dec)
                if bal > 0:
                    rows.append({"chain": "cosmos", "network": name, "address": addr, "repo": repo, "source": "mnemonic", "asset": denom, "balance": str(bal), "has_funds": "yes"})
            except Exception as e:
                print(f"    {name} err: {e}", file=sys.stderr)
        time.sleep(0.1)

    # Also derive ETH addresses from mnemonics for token check (index 0)
    print("\nRe-checking mnemonic-derived EVM addresses for tokens...", file=sys.stderr)
    for item in mnemonics:
        try:
            acct = Account.from_mnemonic(item["mnemonic"], account_path="m/44'/60'/0'/0/0")
            addr = acct.address
            for chain, w3 in w3_cache.items():
                for sym, (token, dec) in TOKENS.get(chain, {}).items():
                    try:
                        bal = evm_token(w3, token, addr, dec)
                        if bal > 0:
                            rows.append({"chain": "evm", "network": chain, "address": addr, "repo": item["repo"], "source": "mnemonic", "asset": sym, "balance": str(bal), "has_funds": "yes"})
                    except Exception:
                        pass
        except Exception:
            pass

    with out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
        w.writeheader()
        w.writerows(rows)

    print(f"\nWrote {out} — {len(rows)} non-zero balances", file=sys.stderr)
    print("\n" + "=" * 90)
    print("NON-ZERO BALANCES (native + tokens + Solana + Cosmos)")
    print("=" * 90)
    if not rows:
        print("No funded addresses found.")
    for r in rows:
        print(f"{r['chain']}/{r['network']} {r['asset']:8} {r['balance']:>20}  {r['address']}")
        if r.get("repo"):
            print(f"  repo: {r['repo']}")

    # write derivation map for sol/cosmos
    deriv_out = Path("extracted/multi-chain-addresses.tsv")
    with deriv_out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["repo", "mnemonic_preview", "evm", "solana", "cosmos"], delimiter="\t")
        w.writeheader()
        for item in mnemonics:
            m = item["mnemonic"]
            preview = " ".join(m.split()[:3]) + "..."
            try:
                evm = Account.from_mnemonic(m, account_path="m/44'/60'/0'/0/0").address
                sol = derive_solana(m)
                cos = derive_cosmos(m, Bip44Coins.COSMOS)
                w.writerow({"repo": item["repo"], "mnemonic_preview": preview, "evm": evm, "solana": sol, "cosmos": cos})
            except Exception:
                pass
    print(f"\nDerivation map: {deriv_out}", file=sys.stderr)


if __name__ == "__main__":
    main()

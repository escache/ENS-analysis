#!/usr/bin/env bash
# Crypto/Web3-focused private key search — filters repos and env var names to blockchain context.
#
# Usage:
#   ./scripts/search-pk-crypto.sh search
#   ./scripts/search-pk-crypto.sh analyze
#   ./scripts/search-pk-crypto.sh leaks
#   ./scripts/search-pk-crypto.sh all

set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-results/pk-crypto}"
ANALYSIS_DIR="${ANALYSIS_DIR:-analysis/pk-crypto}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/analyze-results.sh"

# Sourcegraph crypto scope: repo topics + common web3 config files
CRYPTO_CTX='(repo:has.topic(ethereum) or repo:has.topic(blockchain) or repo:has.topic(web3) or repo:has.topic(defi) or repo:has.topic(crypto) or repo:has.topic(solidity) or repo:has.topic(solana) or repo:has.topic(smart-contracts) or file:hardhat.config or file:foundry.toml or file:truffle-config.js)'

# Crypto-relevant env var names only
VARIANTS=(
  "evm-private-key|EVM_PRIVATE_KEY"
  "eth-private-key|ETH_PRIVATE_KEY"
  "wallet-private-key|WALLET_PRIVATE_KEY"
  "private-key|PRIVATE_KEY"
  "deployer-private-key|DEPLOYER_PRIVATE_KEY"
  "signer-private-key|SIGNER_PRIVATE_KEY"
  "owner-private-key|OWNER_PRIVATE_KEY"
  "operator-private-key|OPERATOR_PRIVATE_KEY"
  "relayer-private-key|RELAYER_PRIVATE_KEY"
  "proposer-private-key|PROPOSER_PRIVATE_KEY"
  "validator-private-key|VALIDATOR_PRIVATE_KEY"
  "burner-private-key|BURNER_PRIVATE_KEY"
  "funder-private-key|FUNDER_PRIVATE_KEY"
  "treasury-private-key|TREASURY_PRIVATE_KEY"
  "bridge-private-key|BRIDGE_PRIVATE_KEY"
  "keeper-private-key|KEEPER_PRIVATE_KEY"
  "liquidator-private-key|LIQUIDATOR_PRIVATE_KEY"
  "mev-private-key|MEV_PRIVATE_KEY"
  "sniper-private-key|SNIPER_PRIVATE_KEY"
  "flashloan-private-key|FLASHLOAN_PRIVATE_KEY"
  "bot-private-key|BOT_PRIVATE_KEY"
  "trader-private-key|TRADER_PRIVATE_KEY"
  "market-maker-key|MARKET_MAKER_PRIVATE_KEY"
  "gas-private-key|GAS_PRIVATE_KEY"
  "oracle-private-key|ORACLE_PRIVATE_KEY"
  "mnemonic|MNEMONIC"
  "seed-phrase|SEED_PHRASE"
  "solana-private-key|SOLANA_PRIVATE_KEY"
  "sol-private-key|SOL_PRIVATE_KEY"
  "polygon-private-key|POLYGON_PRIVATE_KEY"
  "bsc-private-key|BSC_PRIVATE_KEY"
  "arbitrum-private-key|ARBITRUM_PRIVATE_KEY"
  "base-private-key|BASE_PRIVATE_KEY"
  "optimism-private-key|OPTIMISM_PRIVATE_KEY"
  "avax-private-key|AVAX_PRIVATE_KEY"
  "stark-private-key|STARK_PRIVATE_KEY"
  "zksync-private-key|ZKSYNC_PRIVATE_KEY"
  "near-private-key|NEAR_PRIVATE_KEY"
  "sui-private-key|SUI_PRIVATE_KEY"
  "aptos-private-key|APTOS_PRIVATE_KEY"
  "cosmos-private-key|COSMOS_PRIVATE_KEY"
  "btc-private-key|BTC_PRIVATE_KEY"
  "ens-private-key|ENS_PRIVATE_KEY"
  "mainnet-private-key|MAINNET_PRIVATE_KEY"
  "testnet-private-key|TESTNET_PRIVATE_KEY"
  "devnet-private-key|DEVNET_PRIVATE_KEY"
  "hot-wallet-key|HOT_WALLET_PRIVATE_KEY"
  "cold-wallet-key|COLD_WALLET_PRIVATE_KEY"
)

CRYPTO_REPO_RE='ethereum|blockchain|web3|defi|crypto|solidity|solana|polygon|arbitrum|optimism|uniswap|aave|compound|chainlink|wormhole|layerzero|polymarket|mev|dex|swap|bridge|rollup|zksync|stark|cosmos|aptos|sui|near|avax|fantom|bera|mantle|metis|taiko|eigen|ens|nft|token|wallet|hardhat|foundry|liquidat|sniper|flashloan|arb-|base-|eth-|sol-|btc|chain|protocol|validator|signer|deploy|bridge|keeper|oracle|gas-|x402|eliza|agent.*chain'

is_crypto_repo() {
  echo "$1" | rg -qi "$CRYPTO_REPO_RE"
}

run_search_variant() {
  local name="$1" term="$2"
  local outfile="${RESULTS_DIR}/${name}.txt"
  local query="context:global ${term} file:.env ${CRYPTO_CTX}"
  local encoded tmp

  mkdir -p "$RESULTS_DIR"
  encoded="$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$query")"

  echo "[search] $name ($term)" >&2
  tmp="$(mktemp)"
  curl -fsSL "https://sourcegraph.com/.api/search/stream?q=${encoded}&patternType=keyword&display=3000" \
    -H 'Accept: text/event-stream' 2>/dev/null \
    | rg -o 'github\.com/[^/"\\]+/[^/"\\]+' \
    | sort -u > "$tmp"

  : > "$outfile"
  while IFS= read -r repo; do
    is_crypto_repo "$repo" && echo "$repo"
  done < "$tmp" >> "$outfile"
  rm -f "$tmp"

  echo "  -> $(wc -l < "$outfile" | tr -d ' ') crypto repos" >&2
}

run_analyze_variant() {
  local name="$1" term="$2"
  local infile="${RESULTS_DIR}/${name}.txt"
  local outfile="${ANALYSIS_DIR}/${name}.tsv"
  [[ -s "$infile" ]] || return 0

  mkdir -p "$ANALYSIS_DIR" "${ANALYSIS_DIR}/.tmp"
  echo "[analyze] $name ($(wc -l < "$infile" | tr -d ' ') repos)" >&2

  local repo running=0
  while IFS= read -r repo; do
    [[ -n "$repo" ]] || continue
    local safe
    safe="$(echo "$repo" | tr '/:' '__')"
    (
      analyze_repo "$repo" "${term} file:.env" > "${ANALYSIS_DIR}/.tmp/${safe}" 2>/dev/null || true
    ) &
    running=$((running + 1))
    if (( running >= ${JOBS:-6} )); then
      wait -n 2>/dev/null || wait
      running=$((running - 1))
    fi
  done < "$infile"
  wait

  {
    printf 'repo\tfile\tline_no\tstatus\tpreview\tline\n'
    cat "${ANALYSIS_DIR}/.tmp"/* 2>/dev/null || true
  } > "$outfile"
  rm -f "${ANALYSIS_DIR}"/.tmp/*

  local hits leaks
  hits=$(tail -n +2 "$outfile" | wc -l | tr -d ' ')
  leaks=$(awk -F'\t' 'NR>1 && $4=="potential_leak"' "$outfile" | wc -l | tr -d ' ')
  echo "  -> $hits hits, $leaks potential leaks" >&2
}

cmd_search() {
  mkdir -p "$RESULTS_DIR"
  local entry name term
  for entry in "${VARIANTS[@]}"; do
    name="${entry%%|*}"
    term="${entry##*|}"
    run_search_variant "$name" "$term" || true
    sleep 0.3
  done
  echo >&2
  echo "Union: $(cat "${RESULTS_DIR}"/*.txt 2>/dev/null | sort -u | wc -l | tr -d ' ') unique crypto repos" >&2
}

cmd_analyze() {
  mkdir -p "${ANALYSIS_DIR}/.tmp"
  local entry name term
  for entry in "${VARIANTS[@]}"; do
    name="${entry%%|*}"
    term="${entry##*|}"
    run_analyze_variant "$name" "$term" || true
  done
}

cmd_leaks() {
  python3 - <<'PY'
import csv, re, glob, os

ANALYSIS_DIR = os.environ.get("ANALYSIS_DIR", "analysis/pk-crypto")
KNOWN = {
    "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
    "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d",
    "5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a",
    "4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d",
    "6cbed15c793ce57650b9877cf6fa156fbef513c4e6134f022a85b1ffdd59b2a1",
    "fffdbb37105441e14b0ee6330d855d8504ff39e705c3afa8f859ac9865f99306",
    "6587ae678cf4fc9a33000cdbf9f35226b71dcc6a4684a31203241f9bcfd55d27",
    "27593fea79697e947890ecbecce7901b0008345e5d7259710d0dd5e500d040be",
    "0000000000000000000000000000000000000000000000000000000000000000",
    "0000000000000000000000000000000000000000000000000000000000000001",
}
KEY_RE = re.compile(r'(?:0x)?[a-fA-F0-9]{64}\b')
MNEMONIC_RE = re.compile(r'\b([a-z]+\s+){11,23}[a-z]+\b', re.I)

def is_example(path):
    p = (path or '').lower()
    return any(x in p for x in ('.example','.sample','.fake','.template','/tests/','__tests__','fixture','.md','testing.env','devnet','regtest','goerli','sepolia'))

def norm(k):
    return k.lower().replace('0x','')

findings = []
for path in sorted(glob.glob(f"{ANALYSIS_DIR}/*.tsv")):
    variant = os.path.basename(path).replace('.tsv','')
    with open(path) as f:
        for row in csv.DictReader(f, delimiter='\t'):
            text = row.get('line') or ''
            if row['status'] not in ('potential_leak','unknown'): continue
            m = KEY_RE.search(text) or MNEMONIC_RE.search(text)
            if not m: continue
            key = m.group(0)
            if norm(key) in KNOWN: continue
            if re.search(r'your_|example|placeholder|changeme|xxx|abcdef1234', text, re.I): continue
            path_l = (row['file'] or '').lower()
            if path_l.endswith('.env') and not is_example(row['file']):
                risk = 'HIGH'
            elif any(x in path_l for x in ('hardhat','foundry','deploy','operators.env','mainnet')) and not is_example(row['file']):
                risk = 'HIGH'
            elif not is_example(row['file']):
                risk = 'MEDIUM'
            else:
                continue
            findings.append((risk, variant, row['repo'], row['file'], row['line_no'], key))

print("CRYPTO PRIVATE KEY LEAKS")
print("="*110)
for f in sorted(findings, key=lambda x: (0 if x[0]=='HIGH' else 1, x[2])):
    print(f"[{f[0]}] {f[1]:22} {f[2]}")
    print(f"     {f[3]}:{f[4]}")
    print(f"     {f[5]}")
    print()
print(f"Total: {len(findings)}")
PY
}

cmd_list() {
  echo "Crypto context: ${CRYPTO_CTX}"
  echo
  printf '%-28s %s\n' "VARIANT" "TERM"
  for entry in "${VARIANTS[@]}"; do
    printf '%-28s %s\n' "${entry%%|*}" "${entry##*|}"
  done
  echo
  echo "Total: ${#VARIANTS[@]} crypto-focused variants"
}

main() {
  export ANALYSIS_DIR RESULTS_DIR
  case "${1:-all}" in
    list) cmd_list ;;
    search) cmd_search ;;
    analyze) cmd_analyze ;;
    leaks) cmd_leaks ;;
    all) cmd_search; cmd_analyze; echo; cmd_leaks ;;
    -h|--help|help)
      echo "Usage: $0 {list|search|analyze|leaks|all}"
      ;;
    *) echo "Usage: $0 {list|search|analyze|leaks|all}"; exit 1 ;;
  esac
}

main "$@"

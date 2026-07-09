#!/usr/bin/env bash
# Search Sourcegraph for private key env var naming variations.
#
# Usage:
#   ./scripts/search-pk-variants.sh search     # collect repos for all variants
#   ./scripts/search-pk-variants.sh analyze  # analyze all variant result files
#   ./scripts/search-pk-variants.sh all      # search + analyze + report
#   ./scripts/search-pk-variants.sh list       # show variants
#   ./scripts/search-pk-variants.sh leaks      # show high-signal keys from analysis

set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-results/pk-variants}"
ANALYSIS_DIR="${ANALYSIS_DIR:-analysis/pk-variants}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/analyze-results.sh"

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

VARIANTS=(
  "private-key|PRIVATE_KEY"
  "deployer-private-key|DEPLOYER_PRIVATE_KEY"
  "signer-private-key|SIGNER_PRIVATE_KEY"
  "owner-private-key|OWNER_PRIVATE_KEY"
  "operator-private-key|OPERATOR_PRIVATE_KEY"
  "bot-private-key|BOT_PRIVATE_KEY"
  "trader-private-key|TRADER_PRIVATE_KEY"
  "relayer-private-key|RELAYER_PRIVATE_KEY"
  "executor-private-key|EXECUTOR_PRIVATE_KEY"
  "validator-private-key|VALIDATOR_PRIVATE_KEY"
  "funder-private-key|FUNDER_PRIVATE_KEY"
  "admin-private-key|ADMIN_PRIVATE_KEY"
  "dev-private-key|DEV_PRIVATE_KEY"
  "main-private-key|MAIN_PRIVATE_KEY"
  "deploy-private-key|DEPLOY_PRIVATE_KEY"
  "account-private-key|ACCOUNT_PRIVATE_KEY"
  "funding-private-key|FUNDING_PRIVATE_KEY"
  "minter-private-key|MINTER_PRIVATE_KEY"
  "proposer-private-key|PROPOSER_PRIVATE_KEY"
  "submitter-private-key|SUBMITTER_PRIVATE_KEY"
  "burner-private-key|BURNER_PRIVATE_KEY"
  "hot-wallet-key|HOT_WALLET_PRIVATE_KEY"
  "cold-wallet-key|COLD_WALLET_PRIVATE_KEY"
  "agent-private-key|AGENT_PRIVATE_KEY"
  "backend-private-key|BACKEND_PRIVATE_KEY"
  "signer-key|SIGNER_KEY"
  "priv-key|PRIV_KEY"
  "privkey|PRIVKEY"
  "secret-key-env|SECRET_KEY"
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
  "treasury-private-key|TREASURY_PRIVATE_KEY"
  "protocol-private-key|PROTOCOL_PRIVATE_KEY"
  "bridge-private-key|BRIDGE_PRIVATE_KEY"
  "keeper-private-key|KEEPER_PRIVATE_KEY"
  "liquidator-private-key|LIQUIDATOR_PRIVATE_KEY"
  "mm-private-key|MM_PRIVATE_KEY"
  "market-maker-key|MARKET_MAKER_PRIVATE_KEY"
  "gas-private-key|GAS_PRIVATE_KEY"
  "fee-private-key|FEE_PRIVATE_KEY"
  "oracle-private-key|ORACLE_PRIVATE_KEY"
  "whale-private-key|WHALE_PRIVATE_KEY"
  "sniper-private-key|SNIPER_PRIVATE_KEY"
  "mev-private-key|MEV_PRIVATE_KEY"
  "flashloan-private-key|FLASHLOAN_PRIVATE_KEY"
)

usage() {
  echo "Search private key env var naming variations."
  echo "Results: ${RESULTS_DIR}/<variant>.txt"
  echo "Analysis: ${ANALYSIS_DIR}/<variant>.tsv"
  echo
  echo "Commands: list | search | analyze | leaks | all"
}

run_search_variant() {
  local name="$1" term="$2"
  local outfile="${RESULTS_DIR}/${name}.txt"
  local query="context:global ${term} file:.env"
  local encoded

  mkdir -p "$RESULTS_DIR"
  encoded="$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$query")"

  echo "[search] $name ($term)" >&2
  curl -fsSL "https://sourcegraph.com/.api/search/stream?q=${encoded}&patternType=keyword&display=3000" \
    -H 'Accept: text/event-stream' 2>/dev/null \
    | rg -o 'github\.com/[^/"\\]+/[^/"\\]+' \
    | sort -u > "$outfile"

  echo "  -> $(wc -l < "$outfile" | tr -d ' ') repos" >&2
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
  echo "Union: $(cat "${RESULTS_DIR}"/*.txt 2>/dev/null | sort -u | wc -l | tr -d ' ') unique repos" >&2
}

cmd_analyze() {
  mkdir -p "$ANALYSIS_DIR/.tmp"
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

ANALYSIS_DIR = os.environ.get("ANALYSIS_DIR", "analysis/pk-variants")
HARDHAT = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
KNOWN = {HARDHAT, HARDHAT[2:], "4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d",
         "6cbed15c793ce57650b9877cf6fa156fbef513c4e6134f022a85b1ffdd59b2a1",
         "fffdbb37105441e14b0ee6330d855d8504ff39e705c3afa8f859ac9865f99306",
         "0000000000000000000000000000000000000000000000000000000000000000",
         "0000000000000000000000000000000000000000000000000000000000000001"}

KEY_RE = re.compile(r'(?:0x)?[a-fA-F0-9]{64}\b')

def is_example(path):
    p = path.lower()
    return any(x in p for x in ('.example','.sample','.fake','.template','/tests/','__tests__','fixture','.md','testing.env'))

findings = []
for path in sorted(glob.glob(f"{ANALYSIS_DIR}/*.tsv")):
    variant = os.path.basename(path).replace('.tsv','')
    with open(path) as f:
        for row in csv.DictReader(f, delimiter='\t'):
            text = row.get('line') or ''
            if row['status'] not in ('potential_leak','unknown'): continue
            m = KEY_RE.search(text)
            if not m: continue
            key = m.group(0)
            if key.replace('0x','') in {k.replace('0x','') for k in KNOWN}: continue
            if re.search(r'your_|example|placeholder|changeme|xxx', text, re.I): continue
            risk = 'HIGH' if (row['file'].endswith('.env') and not is_example(row['file'])) else 'MEDIUM' if not is_example(row['file']) else 'LOW'
            if risk in ('HIGH','MEDIUM'):
                findings.append((risk, variant, row['repo'], row['file'], row['line_no'], key, text[:100]))

print(f"{'RISK':6} {'VARIANT':25} {'REPO':45} FILE")
print("="*120)
for f in sorted(findings, key=lambda x: (0 if x[0]=='HIGH' else 1, x[2])):
    print(f"{f[0]:6} {f[1]:25} {f[2]:45} {f[3]}:{f[4]}")
    print(f"       KEY: {f[5]}")
    if f[0]=='HIGH': print()
PY
}

cmd_list() {
  printf '%-30s %s\n' "VARIANT" "SEARCH_TERM"
  for entry in "${VARIANTS[@]}"; do
    printf '%-30s %s\n' "${entry%%|*}" "${entry##*|}"
  done
  echo
  echo "Total variants: ${#VARIANTS[@]}"
}

main() {
  export ANALYSIS_DIR RESULTS_DIR
  case "${1:-all}" in
    list) cmd_list ;;
    search) cmd_search ;;
    analyze) cmd_analyze ;;
    leaks) cmd_leaks ;;
    all)
      cmd_search
      cmd_analyze
      echo
      cmd_leaks
      ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"

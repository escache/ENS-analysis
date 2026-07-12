#!/usr/bin/env bash
# Analyze saved results: for each repo, fetch source matches and classify keys.
#
# Usage:
#   ./scripts/analyze-results.sh list
#   ./scripts/analyze-results.sh summary
#   ./scripts/analyze-results.sh leaks [preset]
#   ./scripts/analyze-results.sh all
#   ./scripts/analyze-results.sh <preset>
#
# Reads:   results/<preset>.txt
# Writes:  analysis/<preset>.tsv  (repo, file, line_no, status, preview, line)
#
# Status: potential_leak | placeholder | example_file | empty | commented | unknown

set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-results}"
ANALYSIS_DIR="${ANALYSIS_DIR:-analysis}"
SG_API="https://sourcegraph.com/.api/search/stream"
DELAY_SEC="${DELAY_SEC:-0.2}"
JOBS="${JOBS:-4}"

usage() {
  cat <<EOF
Analyze repos in ${RESULTS_DIR}/ by fetching source matches from Sourcegraph.

Usage:
  ./scripts/analyze-results.sh list              List result files + repo counts
  ./scripts/analyze-results.sh summary           Summary of analysis/*.tsv
  ./scripts/analyze-results.sh leaks [preset]    Show potential_leak rows
  ./scripts/analyze-results.sh all               Analyze every results/*.txt
  ./scripts/analyze-results.sh <preset>          Analyze one preset

Output: ${ANALYSIS_DIR}/<preset>.tsv
Columns: repo, file, line_no, status, preview, line

Env:
  RESULTS_DIR   Input directory (default: results)
  ANALYSIS_DIR  Output directory (default: analysis)
  DELAY_SEC     Pause between repo lookups per worker (default: 0.2)
  JOBS          Parallel workers (default: 4)
EOF
}

preset_query() {
  case "$1" in
    evm-private-key)       echo "EVM_PRIVATE_KEY file:.env" ;;
    eth-private-key)       echo "ETH_PRIVATE_KEY file:.env" ;;
    wallet-private-key)    echo "WALLET_PRIVATE_KEY file:.env" ;;
    mnemonic)              echo "MNEMONIC file:.env" ;;
    seed-phrase)           echo "SEED_PHRASE file:.env" ;;
    infura-key)            echo "INFURA_API_KEY" ;;
    alchemy-key)           echo "ALCHEMY_API_KEY" ;;
    etherscan-key)         echo "ETHERSCAN_API_KEY" ;;
    hardhat-env)           echo "PRIVATE_KEY file:hardhat.config" ;;
    web3-provider-key)     echo "WEB3_PROVIDER file:.env" ;;
    aws-secret)            echo "AWS_SECRET_ACCESS_KEY file:.env" ;;
    aws-access-key)        echo "AWS_ACCESS_KEY_ID file:.env" ;;
    azure-client-secret)   echo "AZURE_CLIENT_SECRET file:.env" ;;
    digitalocean-token)    echo "DIGITALOCEAN_TOKEN file:.env" ;;
    openai-key)            echo "OPENAI_API_KEY file:.env" ;;
    anthropic-key)         echo "ANTHROPIC_API_KEY file:.env" ;;
    stripe-secret)         echo "STRIPE_SECRET_KEY file:.env" ;;
    github-token)          echo "ghp_ file:.env" ;;
    gitlab-token)          echo "glpat- file:.env" ;;
    slack-token)           echo "xoxb- file:.env" ;;
    sendgrid-key)          echo "SENDGRID_API_KEY file:.env" ;;
    twilio-auth)           echo "TWILIO_AUTH_TOKEN file:.env" ;;
    npm-token)             echo "npm_ file:.npmrc" ;;
    pypi-token)            echo "pypi- file:.pypirc" ;;
    database-url)          echo "DATABASE_URL file:.env" ;;
    postgres-password)     echo "POSTGRES_PASSWORD file:.env" ;;
    mongodb-uri)           echo "MONGODB_URI file:.env" ;;
    redis-url)             echo "REDIS_URL file:.env" ;;
    ens-private-key)       echo "ENS_PRIVATE_KEY file:.env" ;;
    resolver-owner-key)    echo "RESOLVER_OWNER_KEY file:.env" ;;
    dotenv-secret)         echo "SECRET file:.env" ;;
    dotenv-password)       echo "PASSWORD file:.env" ;;
    dotenv-api-key)        echo "API_KEY file:.env" ;;
    rsa-private-key)       echo '"BEGIN RSA PRIVATE KEY"' ;;
    openssh-private-key)   echo '"BEGIN OPENSSH PRIVATE KEY"' ;;
    pkcs8-private-key)     echo '"BEGIN PRIVATE KEY"' ;;
    id-rsa-file)           echo "file:id_rsa" ;;
    gcp-service-account)   echo "type:service_account file:.json" ;;
    credentials-json)      echo "credentials file:.json" ;;
    env-not-example)       echo "file:.env -file:.env.example -file:.env.sample" ;;
    custom-*)
      echo "file:.env"
      ;;
    *)
      return 1
      ;;
  esac
}

urlencode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

analyze_repo() {
  local repo="$1"
  local sg_query="$2"
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  local q="repo:${repo} ${sg_query}"
  local encoded
  encoded="$(urlencode "$q")"

  sleep "$DELAY_SEC"
  curl -fsSL "${SG_API}?q=${encoded}&patternType=keyword&display=3000" \
    -H 'Accept: text/event-stream' 2>/dev/null \
    | REPO="$repo" python3 "${script_dir}/analyze-matches.py"
}

analyze_preset() {
  local preset="$1"
  local infile="${RESULTS_DIR}/${preset}.txt"
  local outfile="${ANALYSIS_DIR}/${preset}.tsv"
  local tmpdir sg_query total running=0

  [[ -f "$infile" ]] || { echo "Missing $infile" >&2; return 1; }
  sg_query="$(preset_query "$preset")" || {
    echo "No query mapping for preset: $preset (skipping)" >&2
    return 1
  }

  mkdir -p "$ANALYSIS_DIR"
  tmpdir="$(mktemp -d)"
  total=$(wc -l < "$infile" | tr -d ' ')
  echo "[$preset] analyzing $total repos with $JOBS workers..." >&2

  while IFS= read -r repo; do
    [[ -n "$repo" ]] || continue
    local safe
    safe="$(echo "$repo" | tr '/:' '__')"
    (
      analyze_repo "$repo" "$sg_query" > "${tmpdir}/${safe}" 2>/dev/null || true
    ) &
    running=$((running + 1))
    if (( running >= JOBS )); then
      wait -n 2>/dev/null || wait
      running=$((running - 1))
    fi
  done < "$infile"
  wait

  {
    printf 'repo\tfile\tline_no\tstatus\tpreview\tline\n'
    cat "$tmpdir"/* 2>/dev/null || true
  } > "$outfile"
  rm -rf "$tmpdir"

  local hits leaks
  hits=$(tail -n +2 "$outfile" | wc -l | tr -d ' ')
  leaks=$(awk -F'\t' 'NR>1 && $4=="potential_leak"' "$outfile" | wc -l | tr -d ' ')
  echo "Wrote $outfile — $total repos, $hits hits, $leaks potential leaks" >&2
}

cmd_list() {
  local f
  shopt -s nullglob
  if [[ ! -d "$RESULTS_DIR" ]] || ! compgen -G "${RESULTS_DIR}/*.txt" > /dev/null; then
    echo "No result files in ${RESULTS_DIR}/" >&2
    return 1
  fi
  printf '%-40s %8s  %s\n' "PRESET" "REPOS" "QUERY"
  for f in "${RESULTS_DIR}"/*.txt; do
    local preset count q
    preset="$(basename "$f" .txt)"
    count=$(wc -l < "$f" | tr -d ' ')
    if q="$(preset_query "$preset" 2>/dev/null)"; then
      printf '%-40s %8s  %s\n' "$preset" "$count" "$q"
    else
      printf '%-40s %8s  %s\n' "$preset" "$count" "(no mapping)"
    fi
  done
  shopt -u nullglob
}

cmd_summary() {
  local f
  shopt -s nullglob
  [[ -d "$ANALYSIS_DIR" ]] || { echo "No analysis output yet." >&2; return 1; }
  printf '%-40s %8s %8s %8s %8s\n' "PRESET" "HITS" "LEAKS" "UNKNOWN" "EXAMPLE"
  for f in "${ANALYSIS_DIR}"/*.tsv; do
    local preset hits leaks unknown examples
    preset="$(basename "$f" .tsv)"
    hits=$(tail -n +2 "$f" | wc -l | tr -d ' ')
    leaks=$(awk -F'\t' 'NR>1 && $4=="potential_leak"' "$f" | wc -l | tr -d ' ')
    unknown=$(awk -F'\t' 'NR>1 && $4=="unknown"' "$f" | wc -l | tr -d ' ')
    examples=$(awk -F'\t' 'NR>1 && $4=="example_file"' "$f" | wc -l | tr -d ' ')
    printf '%-40s %8s %8s %8s %8s\n' "$preset" "$hits" "$leaks" "$unknown" "$examples"
  done
  shopt -u nullglob
}

cmd_leaks() {
  local preset="${1:-}"
  local f
  shopt -s nullglob
  if [[ -n "$preset" ]]; then
    f="${ANALYSIS_DIR}/${preset}.tsv"
    [[ -f "$f" ]] || { echo "No analysis for $preset" >&2; return 1; }
    awk -F'\t' 'NR==1 || $4=="potential_leak" || $4=="unknown"' "$f"
    return
  fi
  for f in "${ANALYSIS_DIR}"/*.tsv; do
    echo "# $(basename "$f" .tsv)" >&2
    awk -F'\t' 'NR>1 && ($4=="potential_leak" || $4=="unknown")' "$f"
  done
  shopt -u nullglob
}

main() {
  local cmd="${1:-all}"

  case "$cmd" in
    -h|--help|help)
      usage
      ;;
    list)
      cmd_list
      ;;
    summary)
      cmd_summary
      ;;
    leaks)
      shift || true
      cmd_leaks "${1:-}"
      ;;
    all)
      local f preset
      shopt -s nullglob
      for f in "${RESULTS_DIR}"/*.txt; do
        preset="$(basename "$f" .txt)"
        analyze_preset "$preset" || true
      done
      shopt -u nullglob
      echo >&2
      cmd_summary
      ;;
    *)
      analyze_preset "$cmd"
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

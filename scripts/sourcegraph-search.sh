#!/usr/bin/env bash
# Sourcegraph secret/credential search helpers.
# Streams global search results, extracts unique GitHub org/repo pairs, saves to file.
#
# Usage:
#   ./scripts/sourcegraph-search.sh <preset>
#   ./scripts/sourcegraph-search.sh custom "context:global MY_QUERY file:.env"
#   ./scripts/sourcegraph-search.sh list
#
# Output: results/<preset>.txt (override dir with RESULTS_DIR)
#
# Examples:
#   ./scripts/sourcegraph-search.sh evm-private-key
#   ./scripts/sourcegraph-search.sh aws-secret
#   ./scripts/sourcegraph-search.sh custom "context:global INFURA_API_KEY"

set -euo pipefail

SG_API="https://sourcegraph.com/.api/search/stream"
RESULTS_DIR="${RESULTS_DIR:-results}"

urlencode() {
  local s="$1"
  local out="" c hex
  while IFS= read -r -n1 c || [[ -n "${c:-}" ]]; do
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      ' ') out+='+' ;;
      '') ;;
      *)
        printf -v hex '%%%02X' "'$c"
        out+="$hex"
        ;;
    esac
  done <<< "$s"
  printf '%s' "$out"
}

sg_search() {
  local query="$1"
  local outfile="$2"
  local encoded
  encoded="$(urlencode "$query")"

  mkdir -p "$RESULTS_DIR"
  curl -fsSL "${SG_API}?q=${encoded}&patternType=keyword&display=3000" \
    -H 'Accept: text/event-stream' 2>/dev/null \
    | rg -o 'github\.com/[^/"\\]+/[^/"\\]+' \
    | sort -u > "$outfile"

  local count
  count=$(wc -l < "$outfile" | tr -d ' ')
  echo "Saved $count repos to $outfile" >&2
}

run_preset() {
  local name="$1"
  local query=""
  local outfile="${RESULTS_DIR}/${name}.txt"

  case "$name" in
    # --- EVM / Web3 ---
    evm-private-key)
      query="context:global EVM_PRIVATE_KEY file:.env"
      ;;
    eth-private-key)
      query="context:global ETH_PRIVATE_KEY file:.env"
      ;;
    wallet-private-key)
      query="context:global WALLET_PRIVATE_KEY file:.env"
      ;;
    mnemonic)
      query="context:global MNEMONIC file:.env"
      ;;
    seed-phrase)
      query="context:global SEED_PHRASE file:.env"
      ;;
    infura-key)
      query="context:global INFURA_API_KEY"
      ;;
    alchemy-key)
      query="context:global ALCHEMY_API_KEY"
      ;;
    etherscan-key)
      query="context:global ETHERSCAN_API_KEY"
      ;;
    hardhat-env)
      query="context:global PRIVATE_KEY file:hardhat.config"
      ;;
    solidity-private-key)
      query="context:global private_key lang:Solidity"
      ;;
    web3-provider-key)
      query="context:global WEB3_PROVIDER file:.env"
      ;;

    # --- AWS / Cloud ---
    aws-secret)
      query="context:global AWS_SECRET_ACCESS_KEY file:.env"
      ;;
    aws-access-key)
      query="context:global AWS_ACCESS_KEY_ID file:.env"
      ;;
    gcp-service-account)
      query="context:global type:service_account file:.json"
      ;;
    azure-client-secret)
      query="context:global AZURE_CLIENT_SECRET file:.env"
      ;;
    digitalocean-token)
      query="context:global DIGITALOCEAN_TOKEN file:.env"
      ;;

    # --- API keys / SaaS ---
    openai-key)
      query="context:global OPENAI_API_KEY file:.env"
      ;;
    anthropic-key)
      query="context:global ANTHROPIC_API_KEY file:.env"
      ;;
    stripe-secret)
      query="context:global STRIPE_SECRET_KEY file:.env"
      ;;
    github-token)
      query="context:global ghp_ file:.env"
      ;;
    gitlab-token)
      query="context:global glpat- file:.env"
      ;;
    slack-token)
      query="context:global xoxb- file:.env"
      ;;
    sendgrid-key)
      query="context:global SENDGRID_API_KEY file:.env"
      ;;
    twilio-auth)
      query="context:global TWILIO_AUTH_TOKEN file:.env"
      ;;
    npm-token)
      query="context:global npm_ file:.npmrc"
      ;;
    pypi-token)
      query="context:global pypi- file:.pypirc"
      ;;

    # --- Databases ---
    database-url)
      query="context:global DATABASE_URL file:.env"
      ;;
    postgres-password)
      query="context:global POSTGRES_PASSWORD file:.env"
      ;;
    mongodb-uri)
      query="context:global MONGODB_URI file:.env"
      ;;
    redis-url)
      query="context:global REDIS_URL file:.env"
      ;;

    # --- SSH / TLS ---
    rsa-private-key)
      query='context:global "BEGIN RSA PRIVATE KEY"'
      ;;
    openssh-private-key)
      query='context:global "BEGIN OPENSSH PRIVATE KEY"'
      ;;
    id-rsa-file)
      query="context:global file:id_rsa"
      ;;
    pkcs8-private-key)
      query='context:global "BEGIN PRIVATE KEY"'
      ;;

    # --- Generic env leaks ---
    dotenv-secret)
      query="context:global SECRET file:.env"
      ;;
    dotenv-password)
      query="context:global PASSWORD file:.env"
      ;;
    dotenv-api-key)
      query="context:global API_KEY file:.env"
      ;;
    env-not-example)
      query="context:global file:.env -file:.env.example -file:.env.sample"
      ;;
    credentials-json)
      query="context:global credentials file:.json"
      ;;

    # --- ENS / Ethereum naming ---
    ens-private-key)
      query="context:global ENS_PRIVATE_KEY file:.env"
      ;;
    resolver-owner-key)
      query="context:global RESOLVER_OWNER_KEY file:.env"
      ;;

    *)
      echo "Unknown preset: $name" >&2
      echo "Run: $0 list" >&2
      return 1
      ;;
  esac

  echo "# preset: $name" >&2
  echo "# query:  $query" >&2
  sg_search "$query" "$outfile"
}

list_presets() {
  cat <<EOF
Presets (run: ./scripts/sourcegraph-search.sh <preset>)
Results saved to: ${RESULTS_DIR}/<preset>.txt

EVM / Web3
  evm-private-key       EVM_PRIVATE_KEY in .env
  eth-private-key       ETH_PRIVATE_KEY in .env
  wallet-private-key    WALLET_PRIVATE_KEY in .env
  mnemonic              MNEMONIC in .env
  seed-phrase           SEED_PHRASE in .env
  infura-key            INFURA_API_KEY
  alchemy-key           ALCHEMY_API_KEY
  etherscan-key         ETHERSCAN_API_KEY
  hardhat-env           PRIVATE_KEY in hardhat.config
  solidity-private-key  private_key in Solidity
  web3-provider-key     WEB3_PROVIDER in .env
  ens-private-key       ENS_PRIVATE_KEY in .env
  resolver-owner-key    RESOLVER_OWNER_KEY in .env

AWS / Cloud
  aws-secret            AWS_SECRET_ACCESS_KEY in .env
  aws-access-key        AWS_ACCESS_KEY_ID in .env
  gcp-service-account   GCP service account JSON
  azure-client-secret   AZURE_CLIENT_SECRET in .env
  digitalocean-token    DIGITALOCEAN_TOKEN in .env

API keys / SaaS
  openai-key            OPENAI_API_KEY in .env
  anthropic-key         ANTHROPIC_API_KEY in .env
  stripe-secret         STRIPE_SECRET_KEY in .env
  github-token          ghp_ in .env
  gitlab-token          glpat- in .env
  slack-token           xoxb- in .env
  sendgrid-key          SENDGRID_API_KEY in .env
  twilio-auth           TWILIO_AUTH_TOKEN in .env
  npm-token             npm_ in .npmrc
  pypi-token            pypi- in .pypirc

Databases
  database-url          DATABASE_URL in .env
  postgres-password     POSTGRES_PASSWORD in .env
  mongodb-uri           MONGODB_URI in .env
  redis-url             REDIS_URL in .env

SSH / TLS
  rsa-private-key       BEGIN RSA PRIVATE KEY
  openssh-private-key   BEGIN OPENSSH PRIVATE KEY
  id-rsa-file           file:id_rsa
  pkcs8-private-key     BEGIN PRIVATE KEY

Generic
  dotenv-secret         SECRET in .env
  dotenv-password       PASSWORD in .env
  dotenv-api-key        API_KEY in .env
  env-not-example       .env files excluding examples
  credentials-json      credentials in .json
EOF
}

main() {
  local cmd="${1:-list}"

  case "$cmd" in
    list|-h|--help|help)
      list_presets
      ;;
    custom)
      [[ -n "${2:-}" ]] || { echo "Usage: $0 custom \"<query>\"" >&2; exit 1; }
      local slug outfile
      slug="custom-$(date -u +%Y%m%d-%H%M%S)"
      outfile="${RESULTS_DIR}/${slug}.txt"
      echo "# custom query: $2" >&2
      sg_search "$2" "$outfile"
      ;;
    *)
      run_preset "$cmd"
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

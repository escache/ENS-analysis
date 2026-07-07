#!/usr/bin/env bash
# One-liner Sourcegraph searches — copy/paste or source and run by name.
# Each function saves all unique github.com/org/repo pairs to results/<name>.txt

SG='https://sourcegraph.com/.api/search/stream'
HDR=(-H 'Accept: text/event-stream')
RESULTS_DIR="${RESULTS_DIR:-results}"

_sg() {
  local q="$1" name="$2"
  local outfile="${RESULTS_DIR}/${name}.txt"
  mkdir -p "$RESULTS_DIR"
  curl -fsSL "${SG}?q=${q}&patternType=keyword&display=3000" "${HDR[@]}" 2>/dev/null \
    | rg -o 'github.com/[^/]+/[^/]+' | sort -u > "$outfile"
  echo "Saved $(wc -l < "$outfile" | tr -d ' ') repos to $outfile" >&2
}

# --- EVM / Web3 ---
sg_evm_private_key()      { _sg 'context:global+EVM_PRIVATE_KEY+file:.env' evm-private-key; }
sg_eth_private_key()      { _sg 'context:global+ETH_PRIVATE_KEY+file:.env' eth-private-key; }
sg_wallet_private_key()   { _sg 'context:global+WALLET_PRIVATE_KEY+file:.env' wallet-private-key; }
sg_mnemonic()             { _sg 'context:global+MNEMONIC+file:.env' mnemonic; }
sg_infura()               { _sg 'context:global+INFURA_API_KEY' infura-key; }
sg_alchemy()              { _sg 'context:global+ALCHEMY_API_KEY' alchemy-key; }
sg_hardhat_pk()           { _sg 'context:global+PRIVATE_KEY+file:hardhat.config' hardhat-env; }
sg_ens_private_key()      { _sg 'context:global+ENS_PRIVATE_KEY+file:.env' ens-private-key; }

# --- AWS / Cloud ---
sg_aws_secret()           { _sg 'context:global+AWS_SECRET_ACCESS_KEY+file:.env' aws-secret; }
sg_aws_access_key()       { _sg 'context:global+AWS_ACCESS_KEY_ID+file:.env' aws-access-key; }
sg_gcp_sa()               { _sg 'context:global+type:service_account+file:.json' gcp-service-account; }

# --- API keys ---
sg_openai()               { _sg 'context:global+OPENAI_API_KEY+file:.env' openai-key; }
sg_stripe()               { _sg 'context:global+STRIPE_SECRET_KEY+file:.env' stripe-secret; }
sg_github_pat()           { _sg 'context:global+ghp_+file:.env' github-token; }
sg_slack()                { _sg 'context:global+xoxb-+file:.env' slack-token; }

# --- Databases ---
sg_database_url()         { _sg 'context:global+DATABASE_URL+file:.env' database-url; }
sg_mongodb()              { _sg 'context:global+MONGODB_URI+file:.env' mongodb-uri; }

# --- SSH / keys ---
sg_rsa_key()              { _sg 'context:global+%22BEGIN+RSA+PRIVATE+KEY%22' rsa-private-key; }
sg_openssh_key()          { _sg 'context:global+%22BEGIN+OPENSSH+PRIVATE+KEY%22' openssh-private-key; }
sg_id_rsa()               { _sg 'context:global+file:id_rsa' id-rsa-file; }

# --- Generic ---
sg_dotenv_secret()        { _sg 'context:global+SECRET+file:.env' dotenv-secret; }
sg_dotenv_not_example()   { _sg 'context:global+file:.env+-file:.env.example' env-not-example; }

# Raw curl one-liners (no functions) — paste directly:
: <<'RAW'
mkdir -p results

# EVM private key in .env (original)
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+EVM_PRIVATE_KEY+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u > results/evm-private-key.txt

# AWS secret access key
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+AWS_SECRET_ACCESS_KEY+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u > results/aws-secret.txt

# OpenAI API key
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+OPENAI_API_KEY+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u > results/openai-key.txt

# GitHub personal access token prefix
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+ghp_+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u > results/github-token.txt

# RSA private key block
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+%22BEGIN+RSA+PRIVATE+KEY%22&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u > results/rsa-private-key.txt

# Database connection strings
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+DATABASE_URL+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u > results/database-url.txt

# Infura API key
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+INFURA_API_KEY&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u > results/infura-key.txt

# .env files excluding examples (higher signal)
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+file:.env+-file:.env.example+-file:.env.sample&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u > results/env-not-example.txt

# ENS private key
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+ENS_PRIVATE_KEY+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u > results/ens-private-key.txt

# Mnemonic / seed phrase variable names
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+MNEMONIC+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u > results/mnemonic.txt
RAW

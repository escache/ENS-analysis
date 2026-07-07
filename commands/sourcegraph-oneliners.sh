#!/usr/bin/env bash
# One-liner Sourcegraph searches — copy/paste or source and run by name.
# Each function prints unique github.com/org/repo pairs (default: top 20).

SG='https://sourcegraph.com/.api/search/stream'
HDR=(-H 'Accept: text/event-stream')

_sg() {
  local q="$1" n="${2:-20}"
  curl -fsSL "${SG}?q=${q}&patternType=keyword&display=3000" "${HDR[@]}" 2>/dev/null \
    | rg -o 'github.com/[^/]+/[^/]+' | sort -u | head -n "$n"
}

# --- EVM / Web3 ---
sg_evm_private_key()      { _sg 'context:global+EVM_PRIVATE_KEY+file:.env' "$@"; }
sg_eth_private_key()      { _sg 'context:global+ETH_PRIVATE_KEY+file:.env' "$@"; }
sg_wallet_private_key()   { _sg 'context:global+WALLET_PRIVATE_KEY+file:.env' "$@"; }
sg_mnemonic()             { _sg 'context:global+MNEMONIC+file:.env' "$@"; }
sg_infura()               { _sg 'context:global+INFURA_API_KEY' "$@"; }
sg_alchemy()              { _sg 'context:global+ALCHEMY_API_KEY' "$@"; }
sg_hardhat_pk()           { _sg 'context:global+PRIVATE_KEY+file:hardhat.config' "$@"; }
sg_ens_private_key()      { _sg 'context:global+ENS_PRIVATE_KEY+file:.env' "$@"; }

# --- AWS / Cloud ---
sg_aws_secret()           { _sg 'context:global+AWS_SECRET_ACCESS_KEY+file:.env' "$@"; }
sg_aws_access_key()       { _sg 'context:global+AWS_ACCESS_KEY_ID+file:.env' "$@"; }
sg_gcp_sa()               { _sg 'context:global+type:service_account+file:.json' "$@"; }

# --- API keys ---
sg_openai()               { _sg 'context:global+OPENAI_API_KEY+file:.env' "$@"; }
sg_stripe()               { _sg 'context:global+STRIPE_SECRET_KEY+file:.env' "$@"; }
sg_github_pat()           { _sg 'context:global+ghp_+file:.env' "$@"; }
sg_slack()                { _sg 'context:global+xoxb-+file:.env' "$@"; }

# --- Databases ---
sg_database_url()         { _sg 'context:global+DATABASE_URL+file:.env' "$@"; }
sg_mongodb()              { _sg 'context:global+MONGODB_URI+file:.env' "$@"; }

# --- SSH / keys ---
sg_rsa_key()              { _sg 'context:global+%22BEGIN+RSA+PRIVATE+KEY%22' "$@"; }
sg_openssh_key()          { _sg 'context:global+%22BEGIN+OPENSSH+PRIVATE+KEY%22' "$@"; }
sg_id_rsa()               { _sg 'context:global+file:id_rsa' "$@"; }

# --- Generic ---
sg_dotenv_secret()        { _sg 'context:global+SECRET+file:.env' "$@"; }
sg_dotenv_not_example()   { _sg 'context:global+file:.env+-file:.env.example' "$@"; }

# Raw curl one-liners (no functions) — paste directly:
: <<'RAW'
# EVM private key in .env (original)
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+EVM_PRIVATE_KEY+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u | head -20

# AWS secret access key
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+AWS_SECRET_ACCESS_KEY+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u | head -20

# OpenAI API key
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+OPENAI_API_KEY+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u | head -20

# GitHub personal access token prefix
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+ghp_+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u | head -20

# RSA private key block
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+%22BEGIN+RSA+PRIVATE+KEY%22&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u | head -20

# Database connection strings
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+DATABASE_URL+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u | head -20

# Infura API key
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+INFURA_API_KEY&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u | head -20

# .env files excluding examples (higher signal)
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+file:.env+-file:.env.example+-file:.env.sample&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u | head -20

# ENS private key
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+ENS_PRIVATE_KEY+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u | head -20

# Mnemonic / seed phrase variable names
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+MNEMONIC+file:.env&patternType=keyword&display=3000' -H 'Accept: text/event-stream' 2>/dev/null | rg -o 'github.com/[^/]+/[^/]+' | sort -u | head -20
RAW

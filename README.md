# ENS-analysis

Sourcegraph-based searches for leaked credentials and secrets in public GitHub repositories.

## Quick start

```bash
chmod +x scripts/sourcegraph-search.sh commands/sourcegraph-oneliners.sh

# List all presets
./scripts/sourcegraph-search.sh list

# Run a preset (default: top 20 repos)
./scripts/sourcegraph-search.sh evm-private-key
./scripts/sourcegraph-search.sh aws-secret 50

# Custom query
./scripts/sourcegraph-search.sh custom "context:global INFURA_API_KEY file:.env" 30
```

## Original one-liner

```bash
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+EVM_PRIVATE_KEY+file:.env&patternType=keyword&display=3000' \
  -H 'Accept: text/event-stream' 2>/dev/null \
  | rg -o 'github.com/[^/]+/[^/]+' | sort -u | head -20
```

## Files

| File | Purpose |
|------|---------|
| `scripts/sourcegraph-search.sh` | 40+ named presets with URL encoding and `custom` mode |
| `commands/sourcegraph-oneliners.sh` | Shell functions + raw curl one-liners to copy/paste |

## Preset categories

- **EVM / Web3** — `evm-private-key`, `mnemonic`, `infura-key`, `ens-private-key`, …
- **AWS / Cloud** — `aws-secret`, `gcp-service-account`, `azure-client-secret`, …
- **API keys** — `openai-key`, `stripe-secret`, `github-token`, `slack-token`, …
- **Databases** — `database-url`, `postgres-password`, `mongodb-uri`, …
- **SSH / TLS** — `rsa-private-key`, `openssh-private-key`, `id-rsa-file`, …
- **Generic** — `dotenv-secret`, `env-not-example`, `credentials-json`, …

## Shell functions

```bash
source commands/sourcegraph-oneliners.sh
sg_evm_private_key
sg_aws_secret 50
sg_openai
```

## Notes

- Results are streamed from [Sourcegraph](https://sourcegraph.com) global search; many hits are `.env.example` placeholders — verify before assuming a real leak.
- Append `archived:yes` or `fork:yes` to queries to include archived/forked repos.
- Requires `curl` and `rg` (ripgrep).

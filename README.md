# ENS-analysis

Sourcegraph-based searches for leaked credentials and secrets in public GitHub repositories.

## Quick start

```bash
chmod +x scripts/sourcegraph-search.sh scripts/analyze-results.sh commands/sourcegraph-oneliners.sh

# List all presets
./scripts/sourcegraph-search.sh list

# Run a preset — saves all repos to results/<preset>.txt
./scripts/sourcegraph-search.sh evm-private-key
./scripts/sourcegraph-search.sh aws-secret

# Custom query — saves to results/custom-<timestamp>.txt
./scripts/sourcegraph-search.sh custom "context:global INFURA_API_KEY file:.env"
```

## Output

All results are saved under `results/` (override with `RESULTS_DIR`):

```
results/evm-private-key.txt
results/aws-secret.txt
results/custom-20260707-153500.txt
```

Each file contains one `github.com/org/repo` per line, sorted and deduplicated.

## Original one-liner

```bash
mkdir -p results
curl -fsSL 'https://sourcegraph.com/.api/search/stream?q=context:global+EVM_PRIVATE_KEY+file:.env&patternType=keyword&display=3000' \
  -H 'Accept: text/event-stream' 2>/dev/null \
  | rg -o 'github.com/[^/]+/[^/]+' | sort -u > results/evm-private-key.txt
```

## Analyze results (fetch source per repo)

After collecting repos into `results/`, inspect each repo's actual source via Sourcegraph:

```bash
./scripts/analyze-results.sh list
./scripts/analyze-results.sh evm-private-key     # -> analysis/evm-private-key.tsv
./scripts/analyze-results.sh all                 # analyze every results/*.txt
./scripts/analyze-results.sh summary
./scripts/analyze-results.sh leaks               # show potential_leak + unknown rows
./scripts/analyze-results.sh leaks evm-private-key
```

Each TSV row: `repo`, `file`, `line_no`, `status`, `preview`, `line`

Status values: `potential_leak`, `placeholder`, `example_file`, `empty`, `commented`, `unknown`

```bash
JOBS=8 DELAY_SEC=0.1 ./scripts/analyze-results.sh all
```

## Files

| File | Purpose |
|------|---------|
| `scripts/sourcegraph-search.sh` | 40+ named presets; saves repos to `results/<preset>.txt` |
| `scripts/analyze-results.sh` | Fetches source per repo, classifies key values |
| `commands/sourcegraph-oneliners.sh` | Shell functions + raw curl one-liners |
| `results/` | Repo lists from search (gitignored) |
| `analysis/` | Per-repo source analysis TSVs (gitignored) |

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
sg_evm_private_key    # -> results/evm-private-key.txt
sg_aws_secret         # -> results/aws-secret.txt
```

## Notes

- Results are streamed from [Sourcegraph](https://sourcegraph.com) global search; many hits are `.env.example` placeholders — verify before assuming a real leak.
- Append `archived:yes` or `fork:yes` to queries to include archived/forked repos.
- Requires `curl` and `rg` (ripgrep).

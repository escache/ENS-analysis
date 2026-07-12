#!/usr/bin/env bash
# Search and analyze saved Sourcegraph result files in results/.
#
# Usage:
#   ./scripts/search-results.sh list
#   ./scripts/search-results.sh grep <pattern> [preset...]
#   ./scripts/search-results.sh org <org> [preset...]
#   ./scripts/search-results.sh find <repo-or-pattern> [preset...]
#   ./scripts/search-results.sh union [preset...]
#   ./scripts/search-results.sh intersect <preset> <preset> [...]
#   ./scripts/search-results.sh diff <preset-a> <preset-b>
#   ./scripts/search-results.sh stats
#   ./scripts/search-results.sh save <output> <subcommand> [args...]
#
# Preset names map to results/<preset>.txt (override dir with RESULTS_DIR).

set -euo pipefail

RESULTS_DIR="${RESULTS_DIR:-results}"

usage() {
  cat <<EOF
Search saved Sourcegraph repo lists in ${RESULTS_DIR}/

Commands:
  list                         List result files with repo counts
  grep <pattern> [preset...]   Match repos by regex (default: all files)
  org <org> [preset...]        Filter repos by GitHub org/user
  find <repo> [preset...]      Find which presets contain a repo
  union [preset...]              Merge repos, deduplicated (default: all)
  intersect <p1> <p2> [...]      Repos present in every listed preset
  diff <preset-a> <preset-b>     Repos in A but not in B
  stats                          Summary counts and top orgs
  save <file> <cmd> [args...]    Run a command and write output to file

Examples:
  ./scripts/search-results.sh grep eliza
  ./scripts/search-results.sh org LayerZero-Labs
  ./scripts/search-results.sh find github.com/elizaOS/eliza
  ./scripts/search-results.sh intersect evm-private-key aws-secret
  ./scripts/search-results.sh save results/web3.txt union evm-private-key infura-key
EOF
}

resolve_file() {
  local name="$1"
  if [[ -f "$name" ]]; then
    printf '%s' "$name"
    return
  fi
  local base="${name%.txt}"
  local path="${RESULTS_DIR}/${base}.txt"
  if [[ -f "$path" ]]; then
    printf '%s' "$path"
    return
  fi
  echo "No result file for: $name" >&2
  return 1
}

all_files() {
  local f
  shopt -s nullglob
  for f in "${RESULTS_DIR}"/*.txt; do
    printf '%s\n' "$f"
  done
  shopt -u nullglob
}

resolve_files() {
  if [[ $# -eq 0 ]]; then
    all_files
    return
  fi
  local name path
  for name in "$@"; do
    path="$(resolve_file "$name")" || return 1
    printf '%s\n' "$path"
  done
}

preset_label() {
  local f="$1"
  basename "$f" .txt
}

cmd_list() {
  local f count
  if ! files="$(all_files)" || [[ -z "$files" ]]; then
    echo "No result files in ${RESULTS_DIR}/" >&2
    return 1
  fi
  printf '%-40s %s\n' "PRESET" "REPOS"
  while IFS= read -r f; do
    count=$(wc -l < "$f" | tr -d ' ')
    printf '%-40s %s\n' "$(preset_label "$f")" "$count"
  done <<< "$files"
}

cmd_grep() {
  local pattern="$1"
  shift
  local files
  files="$(resolve_files "$@")"
  rg -i --no-line-number "$pattern" $files 2>/dev/null | sort -u
}

cmd_org() {
  local org="$1"
  shift
  local files
  files="$(resolve_files "$@")"
  rg -i --no-line-number "github\.com/${org}/" $files 2>/dev/null | sort -u
}

cmd_find() {
  local needle="$1"
  shift
  local files f match
  files="$(resolve_files "$@")"
  while IFS= read -r f; do
    if match=$(rg -i --no-line-number "$needle" "$f" 2>/dev/null | sort -u); then
      while IFS= read -r line; do
        [[ -n "$line" ]] && printf '%s\t%s\n' "$(preset_label "$f")" "$line"
      done <<< "$match"
    fi
  done <<< "$files"
}

cmd_union() {
  local files
  files="$(resolve_files "$@")"
  cat $files 2>/dev/null | sort -u
}

cmd_intersect() {
  [[ $# -ge 2 ]] || { echo "Usage: $0 intersect <preset> <preset> [...]" >&2; exit 1; }
  local files first rest
  files="$(resolve_files "$@")"
  first=$(head -n1 <<< "$files")
  rest=$(tail -n +2 <<< "$files")

  local line
  while IFS= read -r line; do
    local ok=1 other
    while IFS= read -r other; do
      if ! rg -Fxq "$line" "$other" 2>/dev/null; then
        ok=0
        break
      fi
    done <<< "$rest"
    [[ $ok -eq 1 ]] && printf '%s\n' "$line"
  done < "$first" | sort -u
}

cmd_diff() {
  [[ $# -eq 2 ]] || { echo "Usage: $0 diff <preset-a> <preset-b>" >&2; exit 1; }
  local a b
  a="$(resolve_file "$1")"
  b="$(resolve_file "$2")"
  comm -23 <(sort -u "$a") <(sort -u "$b")
}

cmd_stats() {
  local files total unique orgs
  files="$(all_files)" || { echo "No result files in ${RESULTS_DIR}/" >&2; return 1; }

  total=0
  while IFS= read -r f; do
    total=$((total + $(wc -l < "$f" | tr -d ' ')))
  done <<< "$files"

  unique=$(cmd_union | wc -l | tr -d ' ')
  local file_count
  file_count=$(wc -l <<< "$files" | tr -d ' ')

  echo "Files:        $file_count"
  echo "Total lines:  $total"
  echo "Unique repos: $unique"
  echo
  echo "Top orgs:"
  cmd_union \
    | rg -o 'github\.com/[^/]+' \
    | sed 's|github.com/||' \
    | sort \
    | uniq -c \
    | sort -rn \
    | head -20 \
    | awk '{printf "  %5d  %s\n", $1, $2}'
}

cmd_save() {
  local outfile="$1"
  shift
  mkdir -p "$(dirname "$outfile")"
  "$0" "$@" > "$outfile"
  echo "Saved $(wc -l < "$outfile" | tr -d ' ') lines to $outfile" >&2
}

main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    list)       cmd_list "$@" ;;
    grep)       [[ $# -ge 1 ]] || { usage; exit 1; }; cmd_grep "$@" ;;
    org)        [[ $# -ge 1 ]] || { usage; exit 1; }; cmd_org "$@" ;;
    find)       [[ $# -ge 1 ]] || { usage; exit 1; }; cmd_find "$@" ;;
    union)      cmd_union "$@" ;;
    intersect)  cmd_intersect "$@" ;;
    diff)       cmd_diff "$@" ;;
    stats)      cmd_stats "$@" ;;
    save)
      [[ $# -ge 2 ]] || { usage; exit 1; }
      local outfile="$1"
      shift
      cmd_save "$outfile" "$@"
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi

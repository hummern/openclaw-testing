#!/usr/bin/env bash
set -euo pipefail

TARGET_MODE="${1:-repo}"
shift || true

PATTERNS=(
  'github_pat_[A-Za-z0-9_]+'
  'ghp_[A-Za-z0-9]{36}'
  'sk-or-v1-[A-Za-z0-9]+'
  'gsk_[A-Za-z0-9]+'
  'AIza[0-9A-Za-z\-_]{35}'
  'xox[baprs]-[A-Za-z0-9-]+'
  '([0-9]{9,12}:[A-Za-z0-9_-]{30,})'
  '"botToken"\s*:\s*"[^"]+"'
  '"token"\s*:\s*"[A-Fa-f0-9]{32,}"'
  'Authorization:\s*Bearer\s+[A-Za-z0-9._-]{16,}'
  'OPENCLAW_TOKEN\s*=\s*"[^"]+"'
  'OPENCLAW_GATEWAY_TOKEN\s*=\s*"[^"]+"'
)

EXCLUDES=(
  '.git/'
  'node_modules/'
  '.venv/'
  '__pycache__/'
  '.openclaw/'
  '*.example.json'
  '*.example.env'
)

build_exclude_args() {
  local args=()
  for ex in "${EXCLUDES[@]}"; do
    args+=("--glob" "!$ex")
  done
  printf '%s\n' "${args[@]}"
}

scan_files() {
  local files=()
  if [[ "$TARGET_MODE" == "staged" ]]; then
    while IFS= read -r f; do
      [[ -n "$f" ]] && files+=("$f")
    done < <(git diff --cached --name-only)
  elif [[ "$TARGET_MODE" == "files" ]]; then
    files=("$@")
  else
    files=(.)
  fi

  if [[ "${#files[@]}" -eq 0 ]]; then
    echo "No files to scan."
    return 0
  fi

  local found=0
  local exclude_args=()
  while IFS= read -r line; do
    exclude_args+=("$line")
  done < <(build_exclude_args)

  for pattern in "${PATTERNS[@]}"; do
    if rg -n --hidden --pcre2 "${pattern}" "${files[@]}" "${exclude_args[@]}" >/tmp/secret_scan_matches.txt 2>/dev/null; then
      if [[ -s /tmp/secret_scan_matches.txt ]]; then
        echo "Potential secret detected (pattern: ${pattern})"
        cat /tmp/secret_scan_matches.txt
        found=1
      fi
    fi
  done

  if [[ "$found" -ne 0 ]]; then
    echo ""
    echo "Secret scan failed. Remove or redact secrets before committing."
    return 1
  fi

  echo "Secret scan passed."
}

scan_files "$@"

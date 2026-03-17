#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
git config core.hooksPath "$repo_root/.githooks"
echo "Configured git hooks path: $repo_root/.githooks"
echo "Pre-commit secret scan enabled."

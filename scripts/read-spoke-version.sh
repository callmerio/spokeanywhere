#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLER_TOML="$ROOT_DIR/spoke/Bundler.toml"

if [[ ! -f "$BUNDLER_TOML" ]]; then
  echo "error: Bundler.toml not found at $BUNDLER_TOML" >&2
  exit 1
fi

VERSION_LINE="$(grep -E '^version = "' "$BUNDLER_TOML" | head -n 1 || true)"

if [[ -z "$VERSION_LINE" ]]; then
  echo "error: version entry not found in $BUNDLER_TOML" >&2
  exit 1
fi

VERSION="$(printf '%s\n' "$VERSION_LINE" | sed -E 's/^version = "([^"]+)"$/\1/')"

if [[ -z "$VERSION" || "$VERSION" == "$VERSION_LINE" ]]; then
  echo "error: failed to parse version from $BUNDLER_TOML" >&2
  exit 1
fi

printf '%s\n' "$VERSION"

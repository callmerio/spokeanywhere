#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <version-tag>" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_TAG="$1"
NOTES_PATH="$ROOT_DIR/docs/releases/${VERSION_TAG}.md"

if [[ ! -f "$NOTES_PATH" ]]; then
  echo "error: release notes file not found for ${VERSION_TAG}: $NOTES_PATH" >&2
  exit 1
fi

printf '%s\n' "$NOTES_PATH"

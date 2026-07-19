#!/usr/bin/env bash


set -euo pipefail

DRY_RUN=0
CACHE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    -c|--cache) CACHE=1 ;;
    -h|--help)
      echo "$0:"
      echo "    -n, --dry-run   Just list actions"
      echo "    -c, --cache     Clean .zig-cache"
      echo "    -h, --help      Show this help"
      exit 0
      ;;
    *) echo "unknown arg: $1 (try -h)"; exit 1 ;;
  esac
  shift
done

LOCAL_PATHS=(
  "zig-out"
  "build"
  "dist"
  "checksums.txt"
)

remove() {
  local p="$1"
  if [[ ! -e "$p" && ! -L "$p" ]]; then
    echo "Skip $p (not present)"
    return
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "Will rm -rf $p"
  else
    rm -rf "$p"
    echo "Removed $p"
  fi
}

echo "==> Cleaning project-local artifacts"
for p in "${LOCAL_PATHS[@]}"; do
  remove "$p"
done

if [[ $CACHE -eq 1 ]]; then
    remove ".zig-cache"
fi

if [[ $DRY_RUN -eq 1 ]]; then
  echo "==> Dry-run done, nothing deleted."
else
  echo "==> Clean done."
fi

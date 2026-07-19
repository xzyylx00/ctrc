#!/usr/bin/env bash

# "x86_64-linux-gnu"
# "aarch64-linux-gnu"
# "x86_64-windows-gnu"
# "x86_64-macos-none"
set -euo pipefail

check_deps() {
  local fail=0

  # Necessary tools
  for cmd in zig tar zip sha256sum git; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Cannot find '$cmd'."
      fail=1
    else
      echo "Found $cmd at $(command -v "$cmd")"
    fi
  done

  # Tar version verify
  if ! tar --version 2>&1 | grep -q GNU; then
    echo "'tar' must be GNU version."
    fail=1
  else
    echo "Found $(tar --version | head -1)"
  fi

  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Cannot find a git repository -- SOURCE_DATE_EPOCH cannot be derived from git log"
    fail=1
  else
    echo "Found a git repository"
  fi

  if [[ -z "${SOURCE_DATE_EPOCH:-}" ]]; then
    echo "SOURCE_DATE_EPOCH not set externally, will derive from git log"
  else
    echo "SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH"
  fi

  if [[ $fail -ne 0 ]]; then
    echo ""
    echo "Dependency check FAILED, abort."
    exit 1
  fi
  echo ""
}

check_deps

[ -n "$1" ] || exit 1

export SOURCE_DATE_EPOCH="$(git log -1 --pretty=%ct)"
export LC_ALL=C.UTF-8

OPTIMIZE="ReleaseSafe"
JOBS=1

VERSION="$(git describe --tags --always --dirty 2>/dev/null || echo "0.0.1-$(git rev-parse --short HEAD)")"
APP_NAME="$(basename "$(pwd)")"

rm -rf build zig-out zig-cache
mkdir -p build

target=$1

  triple="${target%%@*}"
  echo "==> Building ${target}"

  zig build \
    -Dtarget="$target" \
    -Doptimize="$OPTIMIZE" \
    -j"$JOBS" \

  # staging: exculde zig-out/bin/
  stage="build/stage/${triple}"
  mkdir -p "$stage"

  case "$triple" in
    *windows*) cp zig-out/bin/*.exe "$stage/" 2>/dev/null || true ;;
    *)         cp zig-out/bin/*     "$stage/" 2>/dev/null || true ;;
  esac

  # Add LICENSE / README
  cp LICENSE README.md "$stage/" 2>/dev/null || true

  rm -rf zig-out

# Packing
rm -rf dist && mkdir -p dist

for d in build/stage/*/; do
  triple="$(basename "$d")"
  pkg="dist/${APP_NAME}-${triple}-v${VERSION}"

  case "$triple" in
    *windows*)
      ( cd "$d" && zip -r "../../../${pkg}.zip" . )
      ;;
    *)
      tar \
        --sort=name \
        --mtime="@${SOURCE_DATE_EPOCH}" \
        --owner=0 --group=0 --numeric-owner \
        --pax-option='delete=atime,delete=ctime' \
        -czf "${pkg}.tar.gz" \
        -C "$d" .
      ;;
  esac
done

# checksum
sha256sum dist/* > checksums.txt
echo "==> Artifacts:"
ls -lh dist/
cat checksums.txt

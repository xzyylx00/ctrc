#!/usr/bin/env bash
set -euo pipefail

tmp_dir = $(mktemp -d);

cp ./test/* $tmp_dir -r;
cp ./zig-out/bin/* $tmp_dir -r;

cd $tmp_dir;
bash ./format/test.sh;
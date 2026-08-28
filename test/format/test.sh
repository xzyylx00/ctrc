#!/usr/bin/env bash
set -euo pipefail

testAndCheck() {
        cp "$1" "$1.result" $tmp_dir
        cd $tmp_dir
        ./ctrc fmt $1
        if [ -n `diff -q $1 $1.result` ]; then
        else
                exit -1;
        fi
}

testAndCheck "1.ctr"
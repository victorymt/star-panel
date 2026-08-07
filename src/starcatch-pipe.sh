#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "usage: starcatch-pipe.sh <starcatch-bin> <todo|idea|log> <text>" >&2
    exit 2
fi

starcatch_bin=$1
entry_type=$2
input_text=$3

case "$entry_type" in
    todo|idea|log) ;;
    *)
        echo "unsupported Starcatch entry type: $entry_type" >&2
        exit 2
        ;;
esac

printf '%s\n' "$input_text" | "$starcatch_bin" pipe "$entry_type"

#!/usr/bin/env bash
set -u

usage() {
    echo "usage: clipboard-image.sh capture|cleanup|prune <cache-dir> [paths...]" >&2
    exit 2
}

choose_mime() {
    local offered_types=$1
    local preferred offered

    for preferred in image/png image/jpeg image/webp image/gif image/bmp image/tiff image/svg+xml; do
        while IFS= read -r offered; do
            if [ "$offered" = "$preferred" ]; then
                printf '%s\n' "$preferred"
                return 0
            fi
        done <<< "$offered_types"
    done

    return 1
}

extension_for_mime() {
    case "$1" in
        image/png) printf 'png\n' ;;
        image/jpeg) printf 'jpg\n' ;;
        image/webp) printf 'webp\n' ;;
        image/gif) printf 'gif\n' ;;
        image/bmp) printf 'bmp\n' ;;
        image/tiff) printf 'tiff\n' ;;
        image/svg+xml) printf 'svg\n' ;;
        *) return 1 ;;
    esac
}

normalize_cache_dir() {
    local requested=$1
    mkdir -p -- "$requested" || return 1
    readlink -f -- "$requested"
}

cleanup_path() {
    local cache_dir=$1
    local requested=$2
    local resolved

    [ -e "$requested" ] || return 0
    resolved=$(readlink -f -- "$requested") || return 0
    case "$resolved" in
        "$cache_dir"/paste-*) rm -f -- "$resolved" ;;
    esac
}

prune_stale() {
    local cache_dir=$1
    local stale

    while IFS= read -r -d '' stale; do
        cleanup_path "$cache_dir" "$stale"
    done < <(find "$cache_dir" -maxdepth 1 -type f -name 'paste-*' -mmin +1440 -print0 2>/dev/null)
}

[ "$#" -ge 2 ] || usage

mode=$1
cache_dir=$(normalize_cache_dir "$2") || {
    echo "无法创建图片暂存目录" >&2
    exit 4
}
shift 2

case "$mode" in
    capture)
        [ "$#" -eq 0 ] || usage
        prune_stale "$cache_dir"

        if ! command -v wl-paste >/dev/null 2>&1; then
            echo "缺少 wl-paste，请安装 wl-clipboard" >&2
            exit 127
        fi

        offered_types=$(wl-paste --list-types 2>/dev/null) || {
            echo "无法读取剪贴板格式" >&2
            exit 4
        }
        mime=$(choose_mime "$offered_types") || exit 3
        extension=$(extension_for_mime "$mime") || exit 3

        umask 077
        staged_file=$(mktemp --tmpdir="$cache_dir" "paste-XXXXXXXX.$extension") || {
            echo "无法创建图片暂存文件" >&2
            exit 4
        }
        trap 'rm -f -- "$staged_file"' EXIT

        if ! wl-paste --no-newline --type "$mime" > "$staged_file"; then
            echo "读取剪贴板图片失败" >&2
            exit 4
        fi
        if [ ! -s "$staged_file" ]; then
            echo "剪贴板图片为空" >&2
            exit 4
        fi

        trap - EXIT
        printf '%s\n' "$staged_file"
        ;;
    cleanup)
        for staged_file in "$@"; do
            cleanup_path "$cache_dir" "$staged_file"
        done
        ;;
    prune)
        [ "$#" -eq 0 ] || usage
        prune_stale "$cache_dir"
        ;;
    *) usage ;;
esac

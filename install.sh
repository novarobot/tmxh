#!/bin/sh
# A Debian-csomag nyilvános parancslinkjeinek telepítése és eltávolítása.
set -eu

root=${DPKG_ROOT:-}
script=/opt/ds/tools/tmxh/bin/tmxh
ds_link=/opt/ds/bin/tmxh
opt_link=/opt/bin/tmxh
usr_link=/usr/bin/tmxh

check_link() {
    path=$1
    shift
    if [ -L "$root$path" ]; then
        current=$(readlink "$root$path")
        for allowed in "$@"; do
            [ "$current" != "$allowed" ] || return 0
        done
    elif [ ! -e "$root$path" ]; then
        return 0
    fi
    printf 'tmxh: a telepítő megőrzi a már használt útvonalat: %s\n' "$path" >&2
    exit 1
}

remove_link() {
    path=$1
    shift
    [ -L "$root$path" ] || return 0
    current=$(readlink "$root$path")
    for target in "$@"; do
        if [ "$current" = "$target" ]; then
            unlink "$root$path"
            return 0
        fi
    done
}

case "${1:-}" in
    -t)
        check_link "$ds_link" "$script"
        check_link "$usr_link" "$opt_link" "$ds_link"
        usr_target=$ds_link
        if [ -d "$root/opt/bin" ]; then
            check_link "$opt_link" "$ds_link"
            usr_target=$opt_link
        fi
        mkdir -p "$root/opt/ds/bin"
        ln -sfnT "$script" "$root$ds_link"
        if [ "$usr_target" = "$opt_link" ]; then
            ln -sfnT "$ds_link" "$root$opt_link"
        fi
        ln -sfnT "$usr_target" "$root$usr_link"
        ;;
    -r)
        remove_link "$usr_link" "$opt_link" "$ds_link"
        remove_link "$opt_link" "$ds_link"
        remove_link "$ds_link" "$script"
        ;;
    *)
        printf 'Használat: %s -t|-r\n' "$0" >&2
        exit 2
        ;;
esac

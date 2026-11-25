#!/bin/sh

# English
# ./make-deb.sh                     Build tmux-VERSION.deb in the current directory.
# ./make-deb.sh --set-version 1.2.7 Update the release version in the source files without building.
# The current release version is stored in debian/version.
#
# Magyar
# ./make-deb.sh                     ElkÃ©szÃ­ti a tmux-VERZIÃ.deb csomagot az aktuÃ¡lis kÃ¶nyvtÃ¡rban.
# ./make-deb.sh --set-version 1.2.7 FrissÃ­ti a verziÃ³t a forrÃ¡sfÃ¡jlokban, csomagÃ©pÃ­tÃ©s nÃ©lkÃ¼l.
# Az aktuÃ¡lis kiadÃ¡si verziÃ³t a debian/version fÃ¡jl tÃ¡rolja.

set -eu

source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
metadata="$source_dir/debian"
version=$(cat "$metadata/version")

fail() {
    printf 'make-deb.sh: %s\n' "$*" >&2
    exit 1
}

validate_version() {
    case "$1" in
        [0-9]*) ;;
        *) fail "Invalid version: $1" ;;
    esac
    case "$1" in
        *[!0-9a-zA-Z.+:~-]*) fail "Invalid version: $1" ;;
    esac
    dpkg --validate-version "$1" || fail "Invalid Debian version: $1"
}

check_versions() {
    control_version=$(sed -n 's/^Version: //p' "$metadata/control")
    helper_version=$(perl -ne 'print "$1\n" if /^our \$VERSION\s*=\s*\x27([^\x27]+)\x27\s*;/' "$source_dir/bin/tmxh")
    [ "$control_version" = "$version" ] && [ "$helper_version" = "$version" ] ||
        fail "debian/version, debian/control and bin/tmxh must agree on the release version."
}

set_version() {
    new_version=$1
    validate_version "$new_version"
    [ "$version" != "$new_version" ] || return 0
    perl - "$source_dir" "$version" "$new_version" <<'PERL'
use strict;
use warnings;
use File::Basename qw(dirname);
use File::Find qw(find);
use File::Temp ();

my ($root, $old, $new) = @ARGV;
my $version_file = "$root/debian/version";
my @pending;
find({
    no_chdir => 1,
    wanted => sub {
        my $path = $File::Find::name;
        if ($path =~ m{/(?:\.git|\.tmxh-deb\.[^/]+)\z} && -d $path) {
            $File::Find::prune = 1;
            return;
        }
        return if -l $path || !-f _ || $path =~ /\.deb\z/i;
        open my $in, '<:raw', $path or die "Cannot read $path: $!\n";
        my $mode = (stat $in)[2] & 0777;
        my $text = do { local $/; <$in> } // '';
        close $in or die "Cannot close $path: $!\n";
        return if $text =~ /[\x00-\x08\x0b\x0c\x0e-\x1f]/;
        return unless $text =~ s/(?<![0-9])(?<![0-9]\.)\Q$old\E(?![0-9]|\.[0-9])/$new/g;
        my $temp = File::Temp->new(DIR => dirname($path), TEMPLATE => '.tmxh-version.XXXXXXXX');
        binmode $temp, ':raw';
        print {$temp} $text or die "Cannot write update for $path: $!\n";
        close $temp or die "Cannot save update for $path: $!\n";
        chmod $mode, $temp->filename or die "Cannot preserve permissions for $path: $!\n";
        push @pending, [$path, $temp];
    },
}, $root);
# Commit the version file after updating the source files.
for my $entry (sort { ($a->[0] eq $version_file) <=> ($b->[0] eq $version_file) } @pending) {
    my ($path, $temp) = @$entry;
    rename $temp->filename, $path or die "Cannot update $path: $!\n";
}
PERL
    version=$new_version
    check_versions
    printf 'Version set to %s\n' "$version"
}

validate_version "$version"
check_versions
case "${1:-}" in
    --help|-h)
        printf '%s\n' 'Usage: ./make-deb.sh [--set-version VERSION]' \
            'Build tmux-VERSION.deb in the current directory, or update the version without building.'
        exit 0
        ;;
    --set-version)
        [ "$#" -le 2 ] || fail "Usage: ./make-deb.sh --set-version VERSION"
        if [ "$#" -eq 1 ]; then
            printf 'New version: '
            IFS= read -r requested_version || fail "No version supplied."
        else
            requested_version=$2
        fi
        set_version "$requested_version"
        exit 0
        ;;
    '') [ "$#" -eq 0 ] || fail "Unknown argument." ;;
    *) fail "Unknown argument: $1" ;;
esac

destination="$PWD/tmux-$version.deb"
stage=$(mktemp -d "$PWD/.tmxh-deb.XXXXXXXX")
trap 'rm -rf -- "$stage"' 0
trap 'exit 130' INT
trap 'exit 143' TERM

package="$stage/package"
payload="$package/opt/ds/tools/tmxh"
install -d -m 0755 "$package/DEBIAN" "$payload/bin"
install -m 0755 "$source_dir/bin/tmxh" "$payload/bin/tmxh"
install -m 0755 "$source_dir/install.sh" "$source_dir/make-deb.sh" "$source_dir/test-tmuxh.sh" "$payload/"
install -m 0644 "$source_dir/"*.md "$payload/"
cp -a -- "$metadata" "$payload/debian"
install -m 0644 "$metadata/control" "$package/DEBIAN/control"
install -m 0755 "$metadata/postinst" "$metadata/prerm" "$package/DEBIAN/"
size=$(du -sk "$package/opt" | cut -f1)
printf 'Installed-Size: %s\n' "$size" >> "$package/DEBIAN/control"
(
    cd "$package"
    find opt -type f -print0 | LC_ALL=C sort -z | xargs -0 md5sum > DEBIAN/md5sums
)
dpkg-deb --root-owner-group --build "$package" "$stage/package.deb"
mv -fT -- "$stage/package.deb" "$destination"
printf '%s\n' "$destination"

#!/usr/bin/env bash
# Puts the diffacto command-line tool on the PATH of the steps that follow.
#
# In:  BINARY_URL         where to download it: the tool itself or a .tar.gz holding it
#      VERSION            used when there is no BINARY_URL, to fill RELEASE_URL;
#                         with Diffacto's own RELEASE_URL, the newest when empty
#      RELEASE_URL        a template with {version}, {os} and {arch}
#      BUILD_FROM_SOURCE  "true" to build the copy of the source this action came with
#      ACTION_PATH        this action's folder
#      DIFFACTO_DOWNLOADS where Diffacto's own downloads are, if not at
#                         https://downloads.diffacto.com
#      RUNNER_TEMP, RUNNER_OS, RUNNER_ARCH, GITHUB_PATH
set -euo pipefail

root="${RUNNER_TEMP:?}/diffacto"
bin="$root/bin"
mkdir -p "$bin"
# The release-url the action gives by default: Diffacto's own tarballs, beside
# their SHA256SUMS and latest.txt, the newest version.
ours='https://downloads.diffacto.com/diffacto-{version}-{os}-{arch}.tar.gz'
downloads=${DIFFACTO_DOWNLOADS:-https://downloads.diffacto.com}

fetch() {
    curl --fail --silent --show-error --location --retry 3 "$@"
}

if [ "${BUILD_FROM_SOURCE:-false}" = true ]; then
    # The published action is this folder alone, without the source.
    if [ ! -f "${ACTION_PATH:?}/../../crates/diffacto-cli/Cargo.toml" ]; then
        echo "::error::build-from-source needs Diffacto's source beside the action, and this copy of the action has none. Set version or binary-url instead."
        exit 1
    fi
    # On Linux the tool decodes video with the system's FFmpeg, linked
    # dynamically; its headers and clang (for the bindings) come first.
    if [ "${RUNNER_OS:-Linux}" = Linux ] && command -v apt-get >/dev/null &&
        ! { pkg-config --exists libavcodec libavformat libavutil 2>/dev/null && command -v clang >/dev/null; }; then
        sudo=
        [ "$(id -u)" = 0 ] || sudo=sudo
        $sudo apt-get update -qq
        $sudo apt-get install -y --no-install-recommends \
            libavcodec-dev libavformat-dev libavutil-dev clang libclang-dev pkg-config
    fi
    cargo install --locked --path "${ACTION_PATH:?}/../../crates/diffacto-cli" --root "$root"
else
    case ${RUNNER_OS:-Linux} in
    macOS) os=macos ;;
    Windows) os=windows ;;
    *) os=linux ;;
    esac
    case ${RUNNER_ARCH:-X64} in
    ARM64) arch=arm64 ;;
    *) arch=x64 ;;
    esac
    url=${BINARY_URL:-}
    version=${VERSION:-}
    official=false
    if [ -z "$url" ]; then
        url=${RELEASE_URL:-$ours}
        if [ "$url" = "$ours" ]; then
            official=true
            url="$downloads/diffacto-{version}-{os}-{arch}.tar.gz"
            if [ "$os" = windows ]; then
                echo "::error::There is no diffacto download for Windows yet. Set binary-url to a diffacto.exe of your own, or build-from-source."
                exit 1
            fi
            if [ -z "$version" ]; then
                version=$(fetch "$downloads/latest.txt" | tr -d '[:space:]') || version=
                if ! [[ $version =~ ^[0-9]+(\.[0-9]+)+(-[0-9A-Za-z.]+)?$ ]]; then
                    echo "::error::The newest version couldn't be read from $downloads/latest.txt. Set version."
                    exit 1
                fi
                echo "The newest diffacto is $version."
            fi
        elif [ -z "$version" ]; then
            echo "::error::Set version, binary-url or build-from-source, so the action knows which diffacto to run."
            exit 1
        fi
    fi
    url=${url//\{version\}/$version}
    url=${url//\{os\}/$os}
    url=${url//\{arch\}/$arch}

    work=$(mktemp -d)
    fetch --output "$work/download" "$url"
    if [ "$official" = true ]; then
        # Each release's sums stay in SHA256SUMS-VERSION; a release from
        # before those has only SHA256SUMS, which lists the newest alone.
        name=${url##*/}
        sums=SHA256SUMS-$version
        code=$(fetch --output "$work/SHA256SUMS" --write-out '%{http_code}' "$downloads/$sums") || {
            if [ "$code" != 404 ]; then
                echo "::error::$downloads/$sums couldn't be downloaded."
                exit 1
            fi
            sums=SHA256SUMS
            echo "There is no $downloads/SHA256SUMS-$version, so checking against $downloads/SHA256SUMS."
            fetch --output "$work/SHA256SUMS" "$downloads/SHA256SUMS"
        }
        want=$(awk -v name="$name" '$2 == name { print $1 }' "$work/SHA256SUMS")
        if [ -z "$want" ] && [ "$sums" = SHA256SUMS ]; then
            echo "::error::$downloads/SHA256SUMS doesn't list $name, as it lists the newest release alone and there is no SHA256SUMS-$version. Leave version empty for the newest, or set release-url to install $version unchecked."
            exit 1
        elif [ -z "$want" ]; then
            echo "::error::$downloads/$sums doesn't list $name."
            exit 1
        fi
        if command -v sha256sum >/dev/null; then
            got=$(sha256sum "$work/download" | cut -d' ' -f1)
        else
            got=$(shasum -a 256 "$work/download" | cut -d' ' -f1)
        fi
        if [ "$got" != "$want" ]; then
            echo "::error::$name doesn't match its SHA-256 in $downloads/$sums, so it isn't installed."
            exit 1
        fi
    elif [ -z "${BINARY_URL:-}" ]; then
        echo "Not checking $url against a SHA256SUMS, as release-url isn't Diffacto's own."
    fi
    case $url in
    *.tar.gz | *.tgz)
        mkdir "$work/unpacked"
        tar -xzf "$work/download" -C "$work/unpacked"
        found=$(find "$work/unpacked" -type f \( -name diffacto -o -name diffacto.exe \) | head -n 1)
        if [ -z "$found" ]; then
            echo "::error::The archive at $url holds no diffacto."
            exit 1
        fi
        install -m 755 "$found" "$bin/$(basename "$found")"
        ;;
    *)
        install -m 755 "$work/download" "$bin/diffacto"
        ;;
    esac
    rm -rf "$work"

    # Diffacto's Linux tool links Ubuntu 24.04's FFmpeg, whose packages are
    # named for the libraries: libavcodec.so.60 is in libavcodec60.
    if [ "$official" = true ] && [ "$os" = linux ]; then
        linked=$(ldd "$bin/diffacto" 2>/dev/null || true)
        missing=$(sed -n 's/^[[:space:]]*\(libav[a-z]*\)\.so\.\([0-9]*\) => not found.*/\1\2/p' <<<"$linked" |
            sort -u | tr '\n' ' ')
        if [ -n "$missing" ]; then
            sudo=
            [ "$(id -u)" = 0 ] || sudo="sudo -n"
            # shellcheck disable=SC2086 # sudo and missing are lists of words
            if ! { command -v apt-get >/dev/null && { [ -z "$sudo" ] || command -v sudo >/dev/null; } &&
                $sudo apt-get update -qq && $sudo apt-get install -y --no-install-recommends $missing; }; then
                echo "::warning::diffacto needs FFmpeg's libraries, built for Ubuntu 24.04, and they couldn't be installed. Install these packages: $missing"
            fi
        fi
    fi
fi

echo "$bin" >>"${GITHUB_PATH:-/dev/null}"
"$bin/diffacto" --version

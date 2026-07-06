#!/usr/bin/env sh
set -eu

repo="${AMESH_RELEASE_REPO:-jtsang4/amesh-release}"
version="${AMESH_VERSION:-latest}"
install_dir="${AMESH_INSTALL_DIR:-$HOME/.local/bin}"

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then
	checksum_cmd="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
	checksum_cmd="shasum -a 256"
else
	echo "sha256sum or shasum is required" >&2
	exit 1
fi

case "$(uname -s)" in
	Darwin) os="darwin" ;;
	Linux) os="linux" ;;
	*) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

case "$(uname -m)" in
	x86_64|amd64) arch="amd64" ;;
	arm64|aarch64) arch="arm64" ;;
	*) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;;
esac

asset="amesh_${os}_${arch}.tar.gz"
base="https://github.com/$repo/releases"
if [ "$version" = "latest" ]; then
	base="$base/latest/download"
else
	base="$base/download/$version"
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "$base/$asset" -o "$tmp/$asset"
curl -fsSL "$base/checksums.txt" -o "$tmp/checksums.txt"

line=$(grep "  $asset\$" "$tmp/checksums.txt" || true)
[ -n "$line" ] || { echo "checksum missing for $asset" >&2; exit 1; }

(
	cd "$tmp"
	printf '%s\n' "$line" | $checksum_cmd -c -
)

tar -xzf "$tmp/$asset" -C "$tmp"
mkdir -p "$install_dir"
install -m 0755 "$tmp/amesh" "$install_dir/amesh"

printf 'amesh installed to %s\n' "$install_dir/amesh"
"$install_dir/amesh" version

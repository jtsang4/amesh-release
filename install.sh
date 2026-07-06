#!/usr/bin/env sh
set -eu

repo="${AMESH_RELEASE_REPO:-jtsang4/amesh-release}"
version="${AMESH_VERSION:-latest}"
install_dir="${AMESH_INSTALL_DIR:-$HOME/.local/bin}"
amesh_home="${AMESH_HOME:-$HOME/.amesh}"
daemon_mode="${AMESH_DAEMON:-auto}"
launchd_label="io.github.jtsang4.amesh.daemon"
systemd_unit="amesh-daemon.service"

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
install_dir=$(CDPATH= cd -- "$install_dir" && pwd)
install -m 0755 "$tmp/amesh" "$install_dir/amesh"

printf 'amesh installed to %s\n' "$install_dir/amesh"
"$install_dir/amesh" version

xml_escape() {
	printf '%s' "$1" | sed \
		-e 's/&/\&amp;/g' \
		-e 's/</\&lt;/g' \
		-e 's/>/\&gt;/g' \
		-e 's/"/\&quot;/g' \
		-e "s/'/\&apos;/g"
}

daemon_service_exists() {
	case "$os" in
		darwin) [ -f "$HOME/Library/LaunchAgents/$launchd_label.plist" ] ;;
		linux) [ -f "$HOME/.config/systemd/user/$systemd_unit" ] ;;
		*) return 1 ;;
	esac
}

should_manage_daemon() {
	case "$daemon_mode" in
		1|true|yes|on) return 0 ;;
		0|false|no|off) return 1 ;;
		auto|"") daemon_service_exists ;;
		*) echo "invalid AMESH_DAEMON=$daemon_mode; use 1, 0, or auto" >&2; exit 1 ;;
	esac
}

manage_launchd_daemon() {
	uid=$(id -u)
	plist="$HOME/Library/LaunchAgents/$launchd_label.plist"
	log_dir="$amesh_home/log"
	mkdir -p "$(dirname "$plist")" "$log_dir"

	binary_xml=$(xml_escape "$install_dir/amesh")
	home_xml=$(xml_escape "$amesh_home")
	stdout_xml=$(xml_escape "$log_dir/daemon.log")
	stderr_xml=$(xml_escape "$log_dir/daemon.err.log")

	cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$launchd_label</string>
	<key>ProgramArguments</key>
	<array>
		<string>$binary_xml</string>
		<string>daemon</string>
		<string>run</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>AMESH_HOME</key>
		<string>$home_xml</string>
	</dict>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>$stdout_xml</string>
	<key>StandardErrorPath</key>
	<string>$stderr_xml</string>
</dict>
</plist>
EOF

	launchctl bootout "gui/$uid/$launchd_label" >/dev/null 2>&1 || true
	launchctl bootstrap "gui/$uid" "$plist"
	launchctl kickstart -k "gui/$uid/$launchd_label"
	echo "amesh daemon managed by launchd: $launchd_label"
}

manage_systemd_daemon() {
	command -v systemctl >/dev/null 2>&1 || { echo "systemctl is required for daemon management" >&2; exit 1; }
	unit_dir="$HOME/.config/systemd/user"
	log_dir="$amesh_home/log"
	mkdir -p "$unit_dir" "$log_dir"

	cat > "$unit_dir/$systemd_unit" <<EOF
[Unit]
Description=amesh daemon

[Service]
ExecStart=$install_dir/amesh daemon run
Environment=AMESH_HOME=$amesh_home
Restart=always
RestartSec=5
StandardOutput=append:$log_dir/daemon.log
StandardError=append:$log_dir/daemon.err.log

[Install]
WantedBy=default.target
EOF

	systemctl --user daemon-reload
	systemctl --user enable --now "$systemd_unit"
	systemctl --user restart "$systemd_unit"
	echo "amesh daemon managed by systemd user unit: $systemd_unit"
}

if should_manage_daemon; then
	if [ ! -f "$amesh_home/config.toml" ]; then
		echo "daemon management needs $amesh_home/config.toml; run amesh init, then rerun with AMESH_DAEMON=1" >&2
		exit 1
	fi
	case "$os" in
		darwin) manage_launchd_daemon ;;
		linux) manage_systemd_daemon ;;
	esac
fi

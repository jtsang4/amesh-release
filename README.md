# amesh release

Public binary and container image distribution for amesh.

## Run the hub with Docker

The container image runs the amesh hub (multi-arch: amd64/arm64):

```sh
docker run -d --name amesh-hub \
  -p 8787:8787 \
  -v amesh-hub:/data \
  -e AMESH_SECRET=change-me \
  ghcr.io/jtsang4/amesh:latest
```

`AMESH_SECRET` is required — the hub refuses to start without one. The SQLite database lives in `/data`; keep it on a volume. Pin a version with `ghcr.io/jtsang4/amesh:0.0.4`. Environments and agents still install the binary below; the image is for the hub service.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/jtsang4/amesh-release/main/install.sh | sh
```

Install a specific version:

```sh
curl -fsSL https://raw.githubusercontent.com/jtsang4/amesh-release/main/install.sh | AMESH_VERSION=v0.0.2 sh
```

Set the install directory:

```sh
curl -fsSL https://raw.githubusercontent.com/jtsang4/amesh-release/main/install.sh | AMESH_INSTALL_DIR=/usr/local/bin sh
```

Manage the daemon with the platform user service manager after `amesh init`:

```sh
curl -fsSL https://raw.githubusercontent.com/jtsang4/amesh-release/main/install.sh | AMESH_DAEMON=1 sh
```

Future installs restart an already managed daemon automatically. Disable daemon management for one install:

```sh
curl -fsSL https://raw.githubusercontent.com/jtsang4/amesh-release/main/install.sh | AMESH_DAEMON=0 sh
```

The daemon service captures your `PATH` at install time so it can find runtime CLIs like `claude` or `codex`; rerun the installer after installing a new runtime. On Linux the installer also enables `loginctl` linger so the daemon survives logout.

## Windows

Install with PowerShell:

```powershell
irm https://raw.githubusercontent.com/jtsang4/amesh-release/main/install.ps1 | iex
```

Manage the daemon with a user-level Scheduled Task after `amesh init`:

```powershell
$env:AMESH_DAEMON = "1"; irm https://raw.githubusercontent.com/jtsang4/amesh-release/main/install.ps1 | iex
```

Future installs restart an already managed daemon automatically. Disable daemon management for one install:

```powershell
$env:AMESH_DAEMON = "0"; irm https://raw.githubusercontent.com/jtsang4/amesh-release/main/install.ps1 | iex
```

Waking runtimes from the daemon runs commands through `sh`, so `sh` must be on `PATH` (it ships with Git for Windows).

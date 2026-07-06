# amesh release

Public binary distribution for amesh.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/jtsang4/amesh-release/main/install.sh | sh
```

Install a specific version:

```sh
curl -fsSL https://raw.githubusercontent.com/jtsang4/amesh-release/main/install.sh | AMESH_VERSION=v0.1.1 sh
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

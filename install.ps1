$ErrorActionPreference = "Stop"

$Repo = if ($env:AMESH_RELEASE_REPO) { $env:AMESH_RELEASE_REPO } else { "jtsang4/amesh-release" }
$Version = if ($env:AMESH_VERSION) { $env:AMESH_VERSION } else { "latest" }
$InstallDir = if ($env:AMESH_INSTALL_DIR) { $env:AMESH_INSTALL_DIR } else { Join-Path $HOME ".local\bin" }
$AmeshHome = if ($env:AMESH_HOME) { $env:AMESH_HOME } else { Join-Path $HOME ".amesh" }
$DaemonMode = if ($env:AMESH_DAEMON) { $env:AMESH_DAEMON } else { "auto" }
$TaskName = if ($env:AMESH_TASK_NAME) { $env:AMESH_TASK_NAME } else { "amesh-daemon" }

$Arch = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()) {
	"X64" { "amd64" }
	"Arm64" { "arm64" }
	default { throw "unsupported arch: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)" }
}

$Asset = "amesh_windows_$Arch.zip"
$Base = if ($Version -eq "latest") {
	"https://github.com/$Repo/releases/latest/download"
} else {
	"https://github.com/$Repo/releases/download/$Version"
}

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("amesh-install-" + [System.Guid]::NewGuid())
New-Item -ItemType Directory -Path $Tmp | Out-Null

try {
	$Zip = Join-Path $Tmp $Asset
	$Checksums = Join-Path $Tmp "checksums.txt"
	Invoke-WebRequest -Uri "$Base/$Asset" -OutFile $Zip
	Invoke-WebRequest -Uri "$Base/checksums.txt" -OutFile $Checksums

	$Line = Get-Content $Checksums | Where-Object { $_ -match "\s+$([regex]::Escape($Asset))$" } | Select-Object -First 1
	if (-not $Line) { throw "checksum missing for $Asset" }
	$Expected = ($Line -split "\s+")[0].ToLowerInvariant()
	$Actual = (Get-FileHash -Path $Zip -Algorithm SHA256).Hash.ToLowerInvariant()
	if ($Actual -ne $Expected) { throw "checksum mismatch for $Asset" }
	Write-Host "${Asset}: OK"

	Expand-Archive -Path $Zip -DestinationPath $Tmp -Force
	New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
	$InstallDir = (Resolve-Path $InstallDir).Path
	$Binary = Join-Path $InstallDir "amesh.exe"
	Copy-Item -Path (Join-Path $Tmp "amesh.exe") -Destination $Binary -Force

	Write-Host "amesh installed to $Binary"
	& $Binary version

	function Test-DaemonTask {
		return [bool](Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)
	}

	function Test-ManageDaemon {
		switch ($DaemonMode.ToLowerInvariant()) {
			"1" { return $true }
			"true" { return $true }
			"yes" { return $true }
			"on" { return $true }
			"0" { return $false }
			"false" { return $false }
			"no" { return $false }
			"off" { return $false }
			"auto" { return (Test-DaemonTask) }
			"" { return (Test-DaemonTask) }
			default { throw "invalid AMESH_DAEMON=$DaemonMode; use 1, 0, or auto" }
		}
	}

	function Quote-PowerShellLiteral([string]$Value) {
		return "'" + ($Value -replace "'", "''") + "'"
	}

	if (Test-ManageDaemon) {
		$Config = Join-Path $AmeshHome "config.toml"
		if (-not (Test-Path $Config)) {
			throw "amesh binary installed, but daemon setup needs $Config; run amesh init, then rerun with AMESH_DAEMON=1"
		}

		New-Item -ItemType Directory -Path $AmeshHome -Force | Out-Null
		$LogDir = Join-Path $AmeshHome "log"
		New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
		$Launcher = Join-Path $AmeshHome "amesh-daemon.ps1"
		@(
			'$ErrorActionPreference = "Stop"'
			'$env:AMESH_HOME = ' + (Quote-PowerShellLiteral $AmeshHome)
			'$log = ' + (Quote-PowerShellLiteral (Join-Path $LogDir "daemon.log"))
			'& ' + (Quote-PowerShellLiteral $Binary) + ' daemon run *>> $log'
		) | Set-Content -Path $Launcher -Encoding UTF8

		$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$Launcher`""
		$Trigger = New-ScheduledTaskTrigger -AtLogOn
		$Settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
		Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "amesh daemon" -Force | Out-Null
		Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
		Start-ScheduledTask -TaskName $TaskName
		Write-Host "amesh daemon managed by Scheduled Task: $TaskName"
	}
} finally {
	Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

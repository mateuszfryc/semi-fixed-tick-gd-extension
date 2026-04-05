param(
    [string]$ProjectPath = "."
)

$ErrorActionPreference = "Stop"

function Import-LocalEnvFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$EnvFilePath
    )

    if (-not (Test-Path $EnvFilePath)) {
        return
    }

    foreach ($rawLine in Get-Content $EnvFilePath) {
        $line = $rawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }

        $separatorIndex = $line.IndexOf("=")
        if ($separatorIndex -lt 1) {
            continue
        }

        $name = $line.Substring(0, $separatorIndex).Trim()
        $value = $line.Substring($separatorIndex + 1).Trim()

        if (
            ($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))
        ) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        if (-not [string]::IsNullOrWhiteSpace($name) -and [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

function Get-GodotExecutable {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT4_BIN)) {
        return $env:GODOT4_BIN
    }

    $commandCandidates = @(
        "godot",
        "godot4",
        "godot4.5",
        "godot4.6"
    )

    foreach ($candidate in $commandCandidates) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Source
        }
    }

    throw "Could not find Godot editor. Set GODOT4_BIN or add a Godot executable to PATH."
}

function Get-GdextensionDebugLibraryPaths {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResolvedProjectPath
    )

    $gdextensionPath = Join-Path $ResolvedProjectPath 'addons\semi_fixed_tick\semi_fixed_tick.gdextension'
    if (-not (Test-Path $gdextensionPath)) {
        return @()
    }

    $libraryPaths = New-Object System.Collections.Generic.List[string]
    foreach ($line in Get-Content $gdextensionPath) {
        if ($line -match '^\s*windows\.debug\.x86_64\s*=\s*"res://(.+\.dll)"\s*$') {
            $relativePath = $matches[1] -replace '/', '\'
            $libraryPaths.Add((Join-Path $ResolvedProjectPath $relativePath))
        }
    }

    $binDir = Join-Path $ResolvedProjectPath 'addons\semi_fixed_tick\bin'
    if (Test-Path $binDir) {
        foreach ($dll in Get-ChildItem $binDir -Filter *.dll -File -ErrorAction SilentlyContinue) {
            if (-not $libraryPaths.Contains($dll.FullName)) {
                $libraryPaths.Add($dll.FullName)
            }
        }
    }

    return $libraryPaths
}

function Wait-ForReadableFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [int]$TimeoutMs = 15000
    )

    $deadline = (Get-Date).AddMilliseconds($TimeoutMs)
    while ((Get-Date) -lt $deadline) {
        if (-not (Test-Path $FilePath)) {
            Start-Sleep -Milliseconds 200
            continue
        }

        try {
            $stream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            $stream.Dispose()
            return
        }
        catch {
            Start-Sleep -Milliseconds 250
        }
    }

    throw "Timed out waiting for file access: $FilePath"
}

Import-LocalEnvFile -EnvFilePath (Join-Path $PSScriptRoot "..\.env")

$godotExe = Get-GodotExecutable
$resolvedProjectPath = [System.IO.Path]::GetFullPath($ProjectPath)

if (-not (Test-Path (Join-Path $resolvedProjectPath "project.godot"))) {
    throw "project.godot not found in $resolvedProjectPath"
}

foreach ($libraryPath in Get-GdextensionDebugLibraryPaths -ResolvedProjectPath $resolvedProjectPath) {
    Wait-ForReadableFile -FilePath $libraryPath
}

Start-Process -FilePath $godotExe -ArgumentList "--editor", "--path", $resolvedProjectPath -WorkingDirectory $resolvedProjectPath

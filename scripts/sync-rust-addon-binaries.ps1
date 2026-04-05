param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("debug", "release")]
    [string]$Profile
)

$ErrorActionPreference = "Stop"

$workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$addonRoot = Join-Path $workspaceRoot "addons\semi_fixed_tick"
$sourceRoot = Join-Path $addonRoot ("target\" + $Profile)
$targetRoot = Join-Path $addonRoot "bin"
$manifestPath = Join-Path $addonRoot "semi_fixed_tick.gdextension"

if (-not (Test-Path $sourceRoot)) {
    throw "Rust build output not found: $sourceRoot"
}

function Update-GdextensionLibraryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,
        [Parameter(Mandatory = $true)]
        [string]$LibraryKey,
        [Parameter(Mandatory = $true)]
        [string]$LibraryValue
    )

    $lines = Get-Content $ManifestPath
    $updatedLines = foreach ($line in $lines) {
        if ($line -match ('^\s*' + [regex]::Escape($LibraryKey) + '\s*=')) {
            $LibraryKey + ' = "' + $LibraryValue + '"'
        }
        else {
            $line
        }
    }

    Set-Content -LiteralPath $ManifestPath -Value $updatedLines
}

$stagedDll = Get-ChildItem -Path $sourceRoot -Filter "semi_fixed_tick.dll" -File -ErrorAction SilentlyContinue |
    Select-Object -First 1

if (-not $stagedDll) {
    throw "Expected Rust DLL not found in $sourceRoot"
}

New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null

$versionToken = (Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmssfff")
$versionedBaseName = "semi_fixed_tick.$Profile.$versionToken"

$relatedFiles = Get-ChildItem -Path $sourceRoot -File -ErrorAction SilentlyContinue |
    Where-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) -eq "semi_fixed_tick" }

foreach ($file in $relatedFiles) {
    $destinationName = $versionedBaseName + $file.Extension
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $targetRoot $destinationName) -Force
}

$manifestKey = "windows.$Profile.x86_64"
$manifestValue = "res://addons/semi_fixed_tick/bin/$versionedBaseName.dll"
Update-GdextensionLibraryPath -ManifestPath $manifestPath -LibraryKey $manifestKey -LibraryValue $manifestValue

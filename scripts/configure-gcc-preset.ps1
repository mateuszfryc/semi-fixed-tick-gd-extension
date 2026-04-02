param(
    [Parameter(Mandatory = $true)]
    [string]$Preset
)

$ErrorActionPreference = "Stop"

function Test-CrossCompilerPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    return $PathValue -match '(?i)(arm-none-eabi|aarch64|riscv|xtensa|avr)'
}

function Get-DesktopGccToolchainDir {
    $searchDirs = New-Object System.Collections.Generic.List[string]

    foreach ($entry in ($env:PATH -split ';')) {
        if (-not [string]::IsNullOrWhiteSpace($entry) -and (Test-Path $entry)) {
            $searchDirs.Add($entry)
        }
    }

    $commonDirs = @(
        'C:\msys64\ucrt64\bin',
        'C:\msys64\mingw64\bin',
        'C:\msys64\clang64\bin',
        'C:\w64devkit\bin',
        'C:\mingw64\bin',
        'C:\mingw\bin'
    )

    foreach ($dir in $commonDirs) {
        if (Test-Path $dir) {
            $searchDirs.Add($dir)
        }
    }

    $seen = @{}
    foreach ($dir in $searchDirs) {
        if ($seen.ContainsKey($dir)) {
            continue
        }
        $seen[$dir] = $true

        $gccPath = Join-Path $dir 'gcc.exe'
        $gxxPath = Join-Path $dir 'g++.exe'

        if ((Test-Path $gccPath) -and (Test-Path $gxxPath)) {
            if ((Test-CrossCompilerPath $gccPath) -or (Test-CrossCompilerPath $gxxPath)) {
                continue
            }
            return $dir
        }
    }

    throw "Could not find a desktop gcc/g++ toolchain. Add it to PATH or install MSYS2 UCRT64."
}

function Get-NinjaPath {
    $command = Get-Command ninja -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        'C:\Users\dev\AppData\Local\Microsoft\WinGet\Packages\Ninja-build.Ninja_Microsoft.Winget.Source_8wekyb3d8bbwe\ninja.exe',
        'C:\msys64\ucrt64\bin\ninja.exe',
        'C:\msys64\mingw64\bin\ninja.exe',
        'C:\msys64\usr\bin\ninja.exe'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "Could not find ninja.exe. Add it to PATH or install Ninja."
}

function Get-DesiredGodotApiVersion {
    $gdextensionPath = Join-Path $PSScriptRoot '..\addons\semi_fixed_tick\semi_fixed_tick.gdextension'
    $resolvedPath = [System.IO.Path]::GetFullPath($gdextensionPath)

    if (-not (Test-Path $resolvedPath)) {
        return '4.2'
    }

    $match = Select-String -Path $resolvedPath -Pattern 'compatibility_minimum\s*=\s*"([0-9]+\.[0-9]+)"' | Select-Object -First 1
    if ($match -and $match.Matches.Count -gt 0) {
        return $match.Matches[0].Groups[1].Value
    }

    return '4.2'
}

function Get-GitOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepositoryPath,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & git -C $RepositoryPath @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        return @()
    }

    if ($output -is [string]) {
        return @($output)
    }

    return @($output)
}

function Get-PreferredGodotCppRef {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GodotCppDir,
        [Parameter(Mandatory = $true)]
        [string]$ApiVersion
    )

    $tags = Get-GitOutput -RepositoryPath $GodotCppDir -Arguments @('tag')
    $localBranches = Get-GitOutput -RepositoryPath $GodotCppDir -Arguments @('for-each-ref', '--format=%(refname:short)', 'refs/heads')
    $remoteBranches = Get-GitOutput -RepositoryPath $GodotCppDir -Arguments @('for-each-ref', '--format=%(refname:short)', 'refs/remotes/origin')

    $tagCandidates = @(
        $tags |
            Where-Object { $_ -match "^godot-$([regex]::Escape($ApiVersion))(\.[0-9]+)?-stable$" } |
            Sort-Object {[version](($_ -replace '^godot-', '') -replace '-stable$', '')} -Descending
    )
    if ($tagCandidates.Count -gt 0) {
        return $tagCandidates[0]
    }

    $stableBranch = "origin/$ApiVersion"
    if ($remoteBranches -contains $stableBranch) {
        return "refs/remotes/$stableBranch"
    }

    if ($localBranches -contains $ApiVersion) {
        return $ApiVersion
    }

    return $null
}

function Ensure-CompatibleGodotCppRef {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GodotCppDir,
        [Parameter(Mandatory = $true)]
        [string]$ApiVersion
    )

    $preferredRef = Get-PreferredGodotCppRef -GodotCppDir $GodotCppDir -ApiVersion $ApiVersion
    if (-not $preferredRef) {
        throw "Could not find a local godot-cpp tag or branch matching Godot $ApiVersion in $GodotCppDir"
    }

    $status = Get-GitOutput -RepositoryPath $GodotCppDir -Arguments @('status', '--porcelain')
    $meaningfulStatus = @(
        $status | Where-Object {
            $_ -and
            ($_ -notmatch '^\?\?\s+build(/|\\|$)') -and
            ($_ -notmatch '^\?\?\s+bin(/|\\|$)') -and
            ($_ -notmatch '^\?\?\s+gen(/|\\|$)')
        }
    )

    if ($meaningfulStatus.Count -gt 0) {
        throw "godot-cpp worktree is dirty. Commit or stash changes in $GodotCppDir before auto-switching branches."
    }

    $currentCommit = (Get-GitOutput -RepositoryPath $GodotCppDir -Arguments @('rev-parse', 'HEAD') | Select-Object -First 1)
    $preferredCommit = (Get-GitOutput -RepositoryPath $GodotCppDir -Arguments @('rev-parse', $preferredRef) | Select-Object -First 1)

    if (-not $currentCommit -or -not $preferredCommit) {
        throw "Could not resolve git refs in $GodotCppDir"
    }

    if ($currentCommit -eq $preferredCommit) {
        return $preferredRef
    }

    Write-Host "Switching godot-cpp to $preferredRef for Godot $ApiVersion compatibility..."
    & git -C $GodotCppDir checkout --detach $preferredRef
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    return $preferredRef
}

function Get-GodotCppBuildSettings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PresetName
    )

    if ($PresetName -match 'debug') {
        return @{
            BuildType = 'Debug'
            Target = 'template_debug'
            BuildDirName = 'windows-debug'
        }
    }

    return @{
        BuildType = 'Release'
        Target = 'template_release'
        BuildDirName = 'windows-release'
    }
}

function Find-GodotCppLibrary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BinDir,
        [Parameter(Mandatory = $true)]
        [string]$TargetName
    )

    if (-not (Test-Path $BinDir)) {
        return $null
    }

    $cmakeTargetName = if ($TargetName -eq 'template_debug') { 'debug' } else { 'release' }

    $patterns = @(
        "libgodot-cpp.windows.$cmakeTargetName.64.a",
        "godot-cpp.windows.$cmakeTargetName.64.lib",
        "libgodot-cpp.windows.$cmakeTargetName.x86_64.a",
        "godot-cpp.windows.$cmakeTargetName.x86_64.lib",
        "libgodot-cpp.windows.$TargetName.x86_64.*",
        "godot-cpp.windows.$TargetName.x86_64.*",
        "libgodot-cpp.linux.$cmakeTargetName.64.a",
        "libgodot-cpp.linux.$cmakeTargetName.x86_64.a",
        "libgodot-cpp.*$TargetName*.a",
        "godot-cpp.*$TargetName*.lib"
    )

    foreach ($pattern in $patterns) {
        $match = Get-ChildItem -Path $BinDir -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($match) {
            return $match.FullName
        }
    }

    return $null
}

function Ensure-GodotCppBuilt {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GodotCppDir,
        [Parameter(Mandatory = $true)]
        [string]$PresetName,
        [Parameter(Mandatory = $true)]
        [string]$GccPath,
        [Parameter(Mandatory = $true)]
        [string]$GxxPath,
        [Parameter(Mandatory = $true)]
        [string]$NinjaExe
    )

    $settings = Get-GodotCppBuildSettings -PresetName $PresetName
    $sourceIncludeDir = Join-Path $GodotCppDir 'include'
    $sourceGenIncludeDir = Join-Path $GodotCppDir 'gen\include'
    $sourceBinDir = Join-Path $GodotCppDir 'bin'
    $buildDir = Join-Path $GodotCppDir ("build\" + $settings.BuildDirName)
    $buildGenIncludeDir = Join-Path $buildDir 'gen\include'
    $buildBinDir = Join-Path $buildDir 'bin'

    if (-not (Test-Path $sourceIncludeDir)) {
        throw "godot-cpp is missing include/. Check that GODOT_CPP_DIR points at the repo root: $GodotCppDir"
    }

    $sourceLibrary = Find-GodotCppLibrary -BinDir $sourceBinDir -TargetName $settings.Target
    if ((Test-Path $sourceGenIncludeDir) -and $sourceLibrary) {
        return @{
            BuildDir = ''
            LibraryPath = $sourceLibrary
        }
    }

    $buildLibrary = Find-GodotCppLibrary -BinDir $buildBinDir -TargetName $settings.Target
    if ((Test-Path $buildGenIncludeDir) -and $buildLibrary) {
        return @{
            BuildDir = $buildDir
            LibraryPath = $buildLibrary
        }
    }

    Write-Host "godot-cpp is not built for $($settings.Target). Bootstrapping it now..."

    $configureArgs = @(
        '-S', $GodotCppDir
        '-B', $buildDir
        '-G', 'Ninja'
        '-DCMAKE_BUILD_TYPE=' + $settings.BuildType
        '-DGODOTCPP_TARGET=' + $settings.Target
        '-DCMAKE_C_COMPILER:FILEPATH=' + $GccPath
        '-DCMAKE_CXX_COMPILER:FILEPATH=' + $GxxPath
        '-DCMAKE_MAKE_PROGRAM:FILEPATH=' + $NinjaExe
    )

    & cmake --fresh @configureArgs
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    & cmake --build $buildDir --parallel 8
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    $buildLibrary = Find-GodotCppLibrary -BinDir $buildBinDir -TargetName $settings.Target
    if ((-not (Test-Path $buildGenIncludeDir)) -or (-not $buildLibrary)) {
        throw "godot-cpp bootstrap finished but expected outputs are missing in $buildDir"
    }

    return @{
        BuildDir = $buildDir
        LibraryPath = $buildLibrary
    }
}

$toolchainDir = Get-DesktopGccToolchainDir
$gccPath = Join-Path $toolchainDir 'gcc.exe'
$gxxPath = Join-Path $toolchainDir 'g++.exe'
$ninjaPath = Get-NinjaPath
$godotCppDir = $env:GODOT_CPP_DIR
 $desiredApiVersion = Get-DesiredGodotApiVersion

if ([string]::IsNullOrWhiteSpace($godotCppDir)) {
    $godotCppDir = 'C:\godot-cpp'
}

if (-not (Test-Path $godotCppDir)) {
    throw "GODOT_CPP_DIR does not exist: $godotCppDir"
}

$godotCppRef = Ensure-CompatibleGodotCppRef -GodotCppDir $godotCppDir -ApiVersion $desiredApiVersion

$godotCppBuild = Ensure-GodotCppBuilt `
    -GodotCppDir $godotCppDir `
    -PresetName $Preset `
    -GccPath $gccPath `
    -GxxPath $gxxPath `
    -NinjaExe $ninjaPath

Write-Host "Using gcc toolchain from: $toolchainDir"
Write-Host "Using ninja from: $ninjaPath"
Write-Host "Using GODOT_CPP_DIR: $godotCppDir"
Write-Host "Using godot-cpp ref: $godotCppRef"
Write-Host "Targeting Godot API: $desiredApiVersion"
if (-not [string]::IsNullOrWhiteSpace($godotCppBuild.BuildDir)) {
    Write-Host "Using GODOT_CPP_BUILD_DIR: $($godotCppBuild.BuildDir)"
}

$cmakeArgs = @(
    '--fresh'
    '--preset', $Preset
    "-DCMAKE_CXX_COMPILER:FILEPATH=$gxxPath"
    "-DCMAKE_MAKE_PROGRAM:FILEPATH=$ninjaPath"
    "-DGODOT_CPP_DIR:PATH=$godotCppDir"
)

if (-not [string]::IsNullOrWhiteSpace($godotCppBuild.BuildDir)) {
    $cmakeArgs += "-DGODOT_CPP_BUILD_DIR:PATH=$($godotCppBuild.BuildDir)"
}

& cmake @cmakeArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Get-Content "$Root/packages/windows/common.json" -Raw | ConvertFrom-Json | Out-Null
$DesktopManifest = Get-Content "$Root/packages/windows/desktop.json" -Raw |
    ConvertFrom-Json
$DesktopPackageIds = @(
    $DesktopManifest.Sources |
        ForEach-Object { $_.Packages.PackageIdentifier }
)
$RequiredDesktopPackages = @(
    'Docker.DockerDesktop',
    'Microsoft.VisualStudioCode',
    'wez.wezterm'
)
foreach ($PackageId in $RequiredDesktopPackages) {
    if ($DesktopPackageIds -notcontains $PackageId) {
        throw "Windows desktop manifest is missing $PackageId."
    }
}

function Assert-PowerShellSyntax([string]$Path) {
    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $Path, [ref]$Tokens, [ref]$Errors
    ) | Out-Null
    if ($Errors.Count -gt 0) {
        throw "PowerShell syntax error in ${Path}: $($Errors -join '; ')"
    }
}

Assert-PowerShellSyntax "$Root/scripts/bootstrap-windows.ps1"
Assert-PowerShellSyntax "$Root/scripts/update-powershell-profile.ps1"
Assert-PowerShellSyntax "$Root/home/private_dot_config/powershell/main.ps1"
Assert-PowerShellSyntax "$Root/home/run_once_after_10-migrate-mise-lock.ps1"

if (-not (Test-Path "$Root/home/private_dot_config/mise-managed/mise.lock")) {
    throw 'Shared mise lockfile is missing.'
}
if (-not (Test-Path "$Root/home/private_dot_config/mise/create_config.toml") -or
    -not (Test-Path "$Root/home/private_dot_config/mise/create_mise.lock")) {
    throw 'Machine-local mise create files are missing.'
}

$Ignore = Get-Content "$Root/home/.chezmoiignore" -Raw
if ($Ignore -notmatch '\.config/sheldon' -or
    $Ignore -notmatch '\.gitconfig' -or
    $Ignore -notmatch '\.config/git/config') {
    throw 'Windows chezmoi ignore is missing a platform-specific exclusion.'
}

$WindowsBootstrap = Get-Content "$Root/scripts/bootstrap-windows.ps1" -Raw
if ($WindowsBootstrap -notmatch 'Add-GitInclude' -or
    $WindowsBootstrap -notmatch "GetFolderPath\('MyDocuments'\)" -or
    $WindowsBootstrap -notmatch '-ProfilePath \$ProfilePath') {
    throw 'Windows bootstrap must configure Git includes and pass its profile path.'
}
$FullBootstrap = Get-Content "$Root/.github/workflows/full-bootstrap.yml" -Raw
if ($FullBootstrap -match 'bootstrap-windows\.ps1[^\r\n]*-Desktop') {
    throw 'Windows full bootstrap must not enable Desktop.'
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'CI must use PowerShell 7 or later.'
}

$PreviousMiseSystemConfig = $env:MISE_SYSTEM_CONFIG_DIR
$PreviousMiseConfig = $env:MISE_CONFIG_DIR
try {
    function global:lsd { }
    function global:bat { }
    function global:nvim { }
    . "$Root/home/private_dot_config/powershell/main.ps1"
    if ($env:MISE_SYSTEM_CONFIG_DIR -ne (Join-Path $HOME '.config/mise-managed')) {
        throw 'MISE_SYSTEM_CONFIG_DIR does not point to mise-managed.'
    }
    if ($env:MISE_CONFIG_DIR -ne (Join-Path $HOME '.config/mise')) {
        throw 'MISE_CONFIG_DIR does not point to the user mise directory.'
    }
    if ((Get-Alias ls).Definition -ne 'lsd') { throw 'ls alias was not replaced.' }
    if ((Get-Alias cat).Definition -ne 'bat') { throw 'cat alias was not replaced.' }
    if ((Get-Alias vi).Definition -ne 'nvim') { throw 'vi alias was not replaced.' }
}
finally {
    $env:MISE_SYSTEM_CONFIG_DIR = $PreviousMiseSystemConfig
    $env:MISE_CONFIG_DIR = $PreviousMiseConfig
    Remove-Item Function:\lsd, Function:\bat, Function:\nvim -ErrorAction SilentlyContinue
}

function Test-PowerShellProfileUpdate {
    $Work = Join-Path ([System.IO.Path]::GetTempPath()) "profile-test-$([guid]::NewGuid())"
    $ProfilePath = Join-Path $Work 'profile.ps1'
    $Updater = "$Root/scripts/update-powershell-profile.ps1"
    $Start = '# >>> abco20 dotfiles >>>'
    $End = '# <<< abco20 dotfiles <<<'
    New-Item -ItemType Directory -Path $Work | Out-Null
    try {
        $ValidCases = @(
            '',
            "user content`r`n",
            "before`r`n$Start`r`nstale`r`n$End`r`nafter`r`n"
        )
        foreach ($Content in $ValidCases) {
            Set-Content -Path $ProfilePath -Value $Content -Encoding utf8NoBOM
            & $Updater -ProfilePath $ProfilePath
            $Updated = Get-Content $ProfilePath -Raw
            if ([regex]::Matches($Updated, [regex]::Escape($Start)).Count -ne 1 -or
                [regex]::Matches($Updated, [regex]::Escape($End)).Count -ne 1) {
                throw 'Profile updater did not produce exactly one managed block.'
            }
            if ($Content.Contains('user content') -and
                -not $Updated.Contains('user content')) {
                throw 'Profile updater removed unmanaged content.'
            }
            if ($Content.Contains('stale') -and $Updated.Contains('stale')) {
                throw 'Profile updater retained stale managed content.'
            }
        }

        $MalformedCases = @(
            "$Start`r`nstart only",
            "end only`r`n$End",
            "$Start`r`n$Start`r`n$End",
            "$Start`r`n$End`r`n$End",
            "$End`r`n$Start"
        )
        foreach ($Content in $MalformedCases) {
            Set-Content -Path $ProfilePath -Value $Content -Encoding utf8NoBOM
            $Before = (Get-FileHash $ProfilePath -Algorithm SHA256).Hash
            $Failed = $false
            try {
                & $Updater -ProfilePath $ProfilePath
            }
            catch {
                $Failed = $true
            }
            if (-not $Failed) {
                throw 'Profile updater accepted malformed markers.'
            }
            $After = (Get-FileHash $ProfilePath -Algorithm SHA256).Hash
            if ($Before -ne $After) {
                throw 'Profile updater changed a malformed profile.'
            }
        }
    }
    finally {
        Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
    }
}

function Test-MiseLockMigrationFailure {
    $Work = Join-Path ([System.IO.Path]::GetTempPath()) "mise-test-$([guid]::NewGuid())"
    $ConfigRoot = Join-Path $Work 'mise'
    $FakeBin = Join-Path $Work 'bin'
    New-Item -ItemType Directory -Path $ConfigRoot, $FakeBin | Out-Null
    try {
        Set-Content -Path (Join-Path $ConfigRoot 'config.toml') `
            -Value @('[tools]', 'deno = "latest"') -Encoding utf8NoBOM
        Set-Content -Path (Join-Path $ConfigRoot 'mise.lock') `
            -Value @(
                '# existing machine-local lock content',
                'aqua:starship/starship',
                'aqua:rossmacarthur/sheldon'
            ) -Encoding utf8NoBOM
        Set-Content -Path (Join-Path $FakeBin 'mise.cmd') `
            -Value '@exit /b 1' -Encoding ascii
        $Lock = Join-Path $ConfigRoot 'mise.lock'
        $Before = (Get-FileHash $Lock -Algorithm SHA256).Hash
        $PreviousPath = $env:PATH
        $PreviousConfigRoot = $env:DOTFILES_MISE_CONFIG_ROOT
        $env:PATH = "$FakeBin;$PreviousPath"
        $env:DOTFILES_MISE_CONFIG_ROOT = $ConfigRoot
        $Failed = $false
        try {
            & "$Root/home/run_once_after_10-migrate-mise-lock.ps1"
        }
        catch {
            $Failed = $true
        }
        finally {
            $env:PATH = $PreviousPath
            $env:DOTFILES_MISE_CONFIG_ROOT = $PreviousConfigRoot
        }
        if (-not $Failed) {
            throw 'mise lock migration unexpectedly succeeded.'
        }
        $After = (Get-FileHash $Lock -Algorithm SHA256).Hash
        if ($Before -ne $After) {
            throw 'mise lock migration changed the lockfile after failure.'
        }
    }
    finally {
        Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
    }
}

Test-PowerShellProfileUpdate
Test-MiseLockMigrationFailure
$global:LASTEXITCODE = 0
Write-Host 'windows tests passed'

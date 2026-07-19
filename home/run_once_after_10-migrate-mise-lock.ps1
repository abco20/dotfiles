$ErrorActionPreference = 'Stop'

$ConfigRoot = if ($env:DOTFILES_MISE_CONFIG_ROOT) {
    $env:DOTFILES_MISE_CONFIG_ROOT
} else {
    Join-Path $HOME '.config/mise'
}
$Config = Join-Path $ConfigRoot 'config.toml'
$Lock = Join-Path $ConfigRoot 'mise.lock'
$LegacyConfDir = Join-Path $ConfigRoot 'conf.d'

@(
    '00-settings.toml',
    '10-common.toml',
    '20-dev-cli.toml',
    '30-host-languages.toml'
) | ForEach-Object {
    Remove-Item (Join-Path $LegacyConfDir $_) -Force -ErrorAction SilentlyContinue
}
if (Test-Path $LegacyConfDir) {
    Remove-Item $LegacyConfDir -ErrorAction SilentlyContinue
}

if (-not (Test-Path $Config) -or -not (Test-Path $Lock)) {
    return
}

$LockContent = Get-Content $Lock -Raw
$ConfigContent = Get-Content $Config -Raw
if (-not $LockContent.Contains('aqua:starship/starship') -or
    -not $LockContent.Contains('aqua:rossmacarthur/sheldon')) {
    return
}
if ($ConfigContent.Contains('aqua:starship/starship') -and
    $ConfigContent.Contains('aqua:rossmacarthur/sheldon')) {
    return
}

if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
    throw 'mise is required to migrate the machine-local lockfile.'
}

$TempRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    "mise-migration-$([guid]::NewGuid())"
$TempConfigRoot = Join-Path $TempRoot 'mise'
$EmptySystemConfig = Join-Path $TempRoot 'system'
$TempLock = Join-Path $TempConfigRoot 'mise.lock'
$PreviousSystemConfig = $env:MISE_SYSTEM_CONFIG_DIR
$PreviousGlobalConfig = $env:MISE_GLOBAL_CONFIG_FILE

New-Item -ItemType Directory -Path $TempConfigRoot | Out-Null
New-Item -ItemType Directory -Path $EmptySystemConfig | Out-Null
try {
    Copy-Item $Config (Join-Path $TempConfigRoot 'config.toml')
    Set-Content `
        -Path $TempLock `
        -Value '# Machine-local mise lockfile.' `
        -Encoding utf8NoBOM

    $env:MISE_SYSTEM_CONFIG_DIR = $EmptySystemConfig
    $env:MISE_GLOBAL_CONFIG_FILE = Join-Path $TempConfigRoot 'config.toml'
    mise -C $TempRoot lock --global --platform windows-x64 --yes
    if ($LASTEXITCODE -ne 0) {
        throw "mise lock failed with exit code $LASTEXITCODE."
    }

    Move-Item -Force $TempLock $Lock
}
finally {
    $env:MISE_SYSTEM_CONFIG_DIR = $PreviousSystemConfig
    $env:MISE_GLOBAL_CONFIG_FILE = $PreviousGlobalConfig
    Remove-Item -Recurse -Force $TempRoot -ErrorAction SilentlyContinue
}

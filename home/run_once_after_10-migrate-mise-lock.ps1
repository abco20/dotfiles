$ErrorActionPreference = 'Stop'

$ConfigRoot = Join-Path $HOME '.config/mise'
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

Set-Content -Path $Lock -Value '# Machine-local mise lockfile.' -Encoding utf8NoBOM
$EmptySystemConfig = Join-Path ([System.IO.Path]::GetTempPath()) "mise-system-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $EmptySystemConfig | Out-Null
try {
    $PreviousSystemConfig = $env:MISE_SYSTEM_CONFIG_DIR
    $PreviousConfigDir = $env:MISE_CONFIG_DIR
    $env:MISE_SYSTEM_CONFIG_DIR = $EmptySystemConfig
    $env:MISE_CONFIG_DIR = $ConfigRoot
    mise lock --global --platform windows-x64 --yes
    if ($LASTEXITCODE -ne 0) {
        throw "mise lock failed with exit code $LASTEXITCODE."
    }
}
finally {
    $env:MISE_SYSTEM_CONFIG_DIR = $PreviousSystemConfig
    $env:MISE_CONFIG_DIR = $PreviousConfigDir
    Remove-Item -Recurse -Force $EmptySystemConfig
}

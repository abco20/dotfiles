$env:MISE_LOCKFILE = 'false'

if (Get-Command mise -ErrorAction SilentlyContinue) {
    (& mise activate pwsh) | Out-String | Invoke-Expression
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
    (& starship init powershell) | Out-String | Invoke-Expression
}

if (Get-Command lsd -ErrorAction SilentlyContinue) {
    Set-Alias ls lsd
}
if (Get-Command bat -ErrorAction SilentlyContinue) {
    Set-Alias cat bat
}
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Set-Alias vi nvim
}

# dotfiles

## 使い方

```bash
# Ubuntu
./scripts/bootstrap-linux.sh --profile host

# Ubuntu Dev Container
./scripts/bootstrap-linux.sh --profile container

# Ubuntu + desktop
./scripts/bootstrap-linux.sh --profile host --desktop

# macOS（Homebrewが必要）
./scripts/bootstrap-macos.sh --profile host --desktop
```

```powershell
# Windows 11 + PowerShell 7
./scripts/bootstrap-windows.ps1 -Profile Host -Desktop
```

`--dry-run` / `-DryRun`は、OSパッケージのインストールコマンドを表示します。
chezmoiとmiseの完全な適用プレビューではありません。

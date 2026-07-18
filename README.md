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

適用内容だけ確認する場合は、Unixでは`--dry-run`、Windowsでは`-DryRun`を付けます。

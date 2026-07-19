# dotfiles

## 使い方

```bash
# Ubuntu
./scripts/bootstrap-linux.sh --profile host

# Ubuntu Dev Container
./scripts/bootstrap-linux.sh --profile container

# Ubuntu + desktop
./scripts/bootstrap-linux.sh --profile host --desktop

# Ubuntu + desktop + personal apps
./scripts/bootstrap-linux.sh --profile host --desktop --personal-apps

# macOS（Homebrewが必要。miseはstandalone版を導入）
./scripts/bootstrap-macos.sh --profile host --desktop

# macOS + personal apps
./scripts/bootstrap-macos.sh --profile host --desktop --personal-apps
```

```powershell
# Windows 11 + PowerShell 7
./scripts/bootstrap-windows.ps1 -Profile Host -Desktop
```

`--dry-run` / `-DryRun`は、OSパッケージのインストールコマンドを表示します。
chezmoiとmiseの完全な適用プレビューではありません。

### Ubuntu desktop

```bash
./scripts/bootstrap-linux.sh --profile host --desktop
```

開発用desktop coreとして以下を導入します。

* WezTerm
* Docker Engine
* HackGen Nerd Font
* Visual Studio Code

Docker groupへの追加は、再ログイン後に反映されます。

### Personal apps

```bash
./scripts/bootstrap-linux.sh \
  --profile host \
  --desktop \
  --personal-apps
```

desktop coreに加えて以下を導入します。

* Bitwarden
* Discord
* Slack
* Vivaldi
* Nextcloud Desktop
* Antigravity

personal appsはPR必須のfull bootstrapでは実インストールせず、manifestの静的検証を行います。

macOSでも`--personal-apps`を指定すると同じpersonal appsを追加できます。
macOSの通常のdesktop bootstrapでは、`Brewfile.desktop-manual`から
Docker DesktopとHackGen Nerd Fontも導入します。
miseはHomebrewではなく、bootstrapがstandalone版のv2026.7.7を導入します。

GitHub-hosted CIでは`--skip-manual-desktop`を指定し、
これらの実機向けパッケージを除外します。

### Windows desktop

Windows desktop bootstrapはWindows 11を対象としています。Windows Serverは対象外です。
`packages/windows/desktop.json`はdesktop core、`packages/windows/personal.json`はpersonal appsを管理します。
HackGen Nerd Fontはdesktop bootstrapから`install-hackgen-font.ps1`を実行して導入します。
今回のWindows bootstrapはpersonal appsのinstall switchを持たず、personal manifestは静的検証のみ行います。

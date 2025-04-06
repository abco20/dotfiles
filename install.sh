#!/bin/bash -e

echo "Install dotfile dependencies."

sudo apt update
sudo apt install -y zsh zsh-autosuggestions zsh-syntax-highlighting bat trash-cli neovim

wget https://github.com/lsd-rs/lsd/releases/download/v1.1.5/lsd-musl_1.1.5_amd64.deb
sudo dpkg -i lsd-musl_1.1.5_amd64.deb
rm lsd-musl_1.1.5_amd64.deb

wget https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_amd64.deb
sudo dpkg -i git-delta_0.18.2_amd64.deb
rm git-delta_0.18.2_amd64.deb

LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit -D -t /usr/local/bin/
rm lazygit.tar.gz
rm lazygit


curl -sS https://starship.rs/install.sh | sh -s -- --yes

echo "Create dotfile links."
ln -snfv "$(pwd)/.zshrc" "$HOME/.zshrc"

# .config下の各ファイルに対してリンク
for f in $(ls .config); do
  ln -snfv "$(pwd)/.config/$f" "$HOME/.config/$f"
done

# ~/.gitconfigから~/.config/git/.gitconfigをincludeするようにする
if [ ! -e "$HOME/.gitconfig" ]; then
  # .gitconfigが存在しない場合は作成
  echo -e "[include]\n\tpath = ~/.config/git/.gitconfig" > "$HOME/.gitconfig"
  echo "Added include directive to ~/.gitconfig"
else
  # .gitconfigが存在する場合、すでにincludeが書かれているかチェック
  if ! grep -q "path = ~/.config/git/.gitconfig" "$HOME/.gitconfig"; then
    # includeセクションがあるかチェック
    if grep -q "\[include\]" "$HOME/.gitconfig"; then
      # includeセクションがある場合はセクション内に追記
      sed -i '/\[include\]/a\\tpath = ~/.config/git/.gitconfig' "$HOME/.gitconfig"
    else
      # includeセクションがない場合は追加
      echo -e "\n[include]\n\tpath = ~/.config/git/.gitconfig" >> "$HOME/.gitconfig"
    fi
    echo "Updated ~/.gitconfig to include ~/.config/git/.gitconfig"
  else
    echo "~/.gitconfig already includes ~/.config/git/.gitconfig"
  fi
fi

# .zshrc.localが存在しない場合は作成
if [ ! -e "$HOME/.zshrc.local" ]; then
  cp "$(pwd)/.zshrc.local" "$HOME/.zshrc.local"
fi

chsh -s $(which zsh)
echo "Success"

zsh
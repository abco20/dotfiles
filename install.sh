#!/bin/bash -e

IGNORE_PATTERN="^\.(git|travis)"

echo "Install dotfile dependencies."

sudo apt update
sudo apt install -y zsh zsh-autosuggestions zsh-syntax-highlighting bat trash-cli neovim
wget https://github.com/lsd-rs/lsd/releases/download/v1.1.5/lsd-musl_1.1.5_amd64.deb
sudo dpkg -i lsd-musl_1.1.5_amd64.deb
rm lsd-musl_1.1.5_amd64.deb
curl -sS https://starship.rs/install.sh | sh -s -- --yes

echo "Create dotfile links."
for dotfile in .??*; do
    [[ $dotfile =~ $IGNORE_PATTERN ]] && continue
    ln -snfv "$(pwd)/$dotfile" "$HOME/$dotfile"
done

sudo chsh -s $(which zsh)
echo "Success"

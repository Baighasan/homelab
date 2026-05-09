#!/bin/bash
set -e

# Base packages
sudo apt update && sudo apt install -y git stow zsh curl eza zoxide tmux

# Switch default shell to zsh
chsh -s $(which zsh)

# Install Oh MY Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
rm -f ~/.zshrc

# Install PowerLevel10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
  ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

# Install neovim
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
rm nvim-linux-x86_64.tar.gz

# Install TPM (tmux plugin manager)
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# Stow dotfiles
cd ~/dotfiles
stow zsh p10k git nvim

# Install tmux plugins headlessly
tmux new-session -d -s bootstrap
tmux run-shell ~/.tmux/plugins/tpm/bin/install_plugins
tmux kill-session -t bootstrap

echo "Done. Log out and back in to start using zsh."

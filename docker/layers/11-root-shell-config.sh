#!/bin/bash
# Configure root-oriented shell defaults shared by buntoolbox image variants.

set -euo pipefail

mkdir -p /var/run/sshd
perl -0pi -e 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
perl -0pi -e 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'root:root' | chpasswd

cat > /etc/profile.d/01-direnv.sh <<'PROFILE'
eval "$(direnv hook bash)"
PROFILE
cat > /etc/profile.d/02-starship.sh <<'PROFILE'
eval "$(starship init bash)"
PROFILE
cat > /etc/profile.d/03-zoxide.sh <<'PROFILE'
eval "$(zoxide init bash)"
PROFILE
cat > /etc/profile.d/04-aliases.sh <<'PROFILE'
alias ls="eza"
alias ll="eza -l"
alias la="eza -la"
alias cat="bat --paging=never"
PROFILE

RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions \
    /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions

cat > /root/.zshrc <<'ZSHRC'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git zsh-autosuggestions)
source $ZSH/oh-my-zsh.sh

# Tool integrations (same as bash profile.d)
eval "$(direnv hook zsh)"
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
alias ls="eza"
alias ll="eza -l"
alias la="eza -la"
alias cat="bat --paging=never"
ZSHRC

git lfs install
rm -rf /usr/share/doc/* /usr/share/man/* /root/.launchpadlib

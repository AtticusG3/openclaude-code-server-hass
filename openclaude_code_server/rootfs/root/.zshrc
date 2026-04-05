# shellcheck disable=SC1090,SC2034,SC2086
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="robbyrussell"

DISABLE_AUTO_UPDATE="true"
COMPLETION_WAITING_DOTS="true"

plugins=(
  extract
  git
  nmap
  pip
  python
  rsync
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# shellcheck disable=SC1091
source $ZSH/oh-my-zsh.sh

alias reset-settings="cp /root/.code-server/settings.json /data/vscode/User/settings.json && echo 'Setting restored!'"

# Home Assistant CLI
source <(ha completion zsh) && compdef _ha ha

# OpenClaude / tool env (generated at container start)
if [[ -r /etc/profile.d/99-openclaude-hass.sh ]]; then
  # shellcheck disable=SC1091
  source /etc/profile.d/99-openclaude-hass.sh
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# Show motd on start
cat /etc/motd

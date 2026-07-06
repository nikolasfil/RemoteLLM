export PATH="$HOME/.local/bin:/opt/python-tools/bin:/usr/local/bin:$PATH"
export EDITOR="${EDITOR:-vim}"
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LC_CTYPE=C.UTF-8

export ZSH="${ZSH:-/opt/oh-my-zsh}"
export ZSH_THEME="${ZSH_THEME:-remotellm-agnoster}"

plugins=(
  git
  aliases
  colored-man-pages
  python
  ssh
  zsh-autosuggestions
  zsh-syntax-highlighting
)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

# fzf shell integration — handles both new (>=0.48, --zsh) and old Debian packages
if command -v fzf &>/dev/null; then
  if fzf --zsh &>/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]]   && source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

alias ll='ls -la'
alias npm-install='safe-npm-install'
alias pip-install='safe-pip-install'
alias pkg-check='safe-package-check'

# Uncomment to enable direnv. Run 'direnv allow' in each project directory manually.
# eval "$(direnv hook zsh)"

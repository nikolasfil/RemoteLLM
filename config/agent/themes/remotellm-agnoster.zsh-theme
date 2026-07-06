# RemoteLLM agnoster variant.
#
# Keep upstream agnoster segment rendering and git behavior, but use the
# RemoteLLM color defaults and a two-line prompt.

# Current working directory
: ${AGNOSTER_DIR_FG:=${CURRENT_FG}}
: ${AGNOSTER_DIR_BG:=cyan}

# user@host
: ${AGNOSTER_CONTEXT_FG:=cyan}
: ${AGNOSTER_CONTEXT_BG:=black}

source "${ZSH}/themes/agnoster.zsh-theme"

build_prompt() {
  RETVAL=$?
  prompt_context
  prompt_dir
  prompt_git
  prompt_end
}

PROMPT=$'%{%f%b%k%}$(build_prompt)\n%K{cyan}%F{black} > %k%f '

# ─── PATH ──────────────────────────────────────────────────────────────────────
export PATH="$HOME/bin:$HOME/.local/bin:$HOME/go/bin:/usr/local/bin:$PATH"

# ─── Oh My Zsh ─────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""

# Additional completions fpath (MUST be before compinit / OMZ source)
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src

plugins=(
    # Core
    git
    zsh-autosuggestions
    fast-syntax-highlighting
    zsh-history-substring-search
    zsh-autopair
    zsh-you-should-use
    zsh-completions
    zoxide

    # Productivity
    colored-man-pages
    copypath
    copyfile
    extract
    command-not-found
    sudo
    dirhistory

    # Development
    docker
    docker-compose
    npm
    pip
    rust

    # System
    systemd
    aliases

    # Git
    gitignore
)

source $ZSH/oh-my-zsh.sh

# ─── Oh My Posh (cached init, guarded for interactive shells) ────────────────
if [[ -o interactive ]] && [[ -o zle ]]; then
    _omp_cache=~/.cache/oh-my-posh-init.zsh
    _omp_theme=~/.config/oh-my-posh/theme.omp.json
    if [[ ! -f "$_omp_cache" ]] || [[ "$_omp_theme" -nt "$_omp_cache" ]]; then
        oh-my-posh init zsh --config "$_omp_theme" > "$_omp_cache"
    fi
    source "$_omp_cache"
    unset _omp_cache _omp_theme
fi

# ─── Completion System (cached, rebuilds once per day) ────────────────────────
autoload -Uz compinit
if [[ -n ~/.cache/zcompdump(#qN.mh+24) ]]; then
    compinit -d ~/.cache/zcompdump
else
    compinit -C -d ~/.cache/zcompdump
fi

zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' rehash true
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# fzf-tab styles
if command -v eza > /dev/null; then
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath'
    zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always --icons $realpath'
else
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color=always $realpath'
    zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color=always $realpath'
fi
zstyle ':fzf-tab:*' switch-group '<' '>'

# ─── fzf-tab (must be after compinit) ─────────────────────────────────────────
source ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab/fzf-tab.plugin.zsh

# ─── fzf Configuration ────────────────────────────────────────────────────────
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# Catppuccin Mocha colors for fzf
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#000000,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--multi --height=50% --layout=reverse --border=rounded \
--preview 'bat --color=always --style=numbers --line-range=:500 {} 2>/dev/null || eza -1 --color=always --icons {} 2>/dev/null || ls --color=always {} 2>/dev/null || echo {}' \
--preview-window=right:50%:wrap"

export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {} 2>/dev/null || echo {}'"
export FZF_ALT_C_OPTS="--preview 'eza -1 --color=always --icons {} 2>/dev/null || ls --color=always {}'"

# ─── Zoxide ────────────────────────────────────────────────────────────────────
# Initialized by the oh-my-zsh zoxide plugin above; no manual eval needed

# ─── Aliases ───────────────────────────────────────────────────────────────────
# Clear screen + scrollback buffer
alias clear='clear && printf "\033[3J"'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# File operations (safe)
alias cp='cp -v'
alias rm='rm -I'
alias mv='mv -iv'
alias ln='ln -sriv'
alias xclip='xclip -selection c'

# Editor
if command -v nvim > /dev/null; then
    alias vi='nvim'
    alias vim='nvim'
elif command -v vim > /dev/null; then
    alias vi='vim'
else
    alias vi='nano'
fi

# eza (replaces ls)
if command -v eza > /dev/null; then
    alias ls='eza --color=always --icons --group-directories-first'
    alias ll='eza -la --color=always --icons --group-directories-first'
    alias la='eza -a --color=always --icons --group-directories-first'
    alias l='eza -F --color=always --icons --group-directories-first'
    alias tree='eza --tree --color=always --icons'
    alias lt='eza -la --sort=modified --color=always --icons'
fi

# bat (better cat, without shadowing)
export BAT_THEME="Catppuccin Mocha"
export PAGER='bat --paging=always'
alias bat='bat --paging=never'
alias bathelp='bat --plain --language=help'

# glow (terminal markdown viewer)
alias md='glow'

# ripgrep (without shadowing grep)
alias rg='rg --color=auto'

# btop (replaces top/htop)
alias top='btop'

# Disk usage
alias dus='dust'

# Git
alias lg='lazygit'
alias ddiff='delta'

# Misc
alias ip='ip --color=auto'

# yazi (cd into directory on exit)
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# apt (sudo expands aliases when alias sudo='sudo ' is set)
alias sudo='sudo '
if command -v apt > /dev/null; then
    alias apt='apt -o=Dpkg::Progress-Fancy="1"'
    alias update='sudo apt update && sudo apt upgrade'
fi

# ─── GPU Monitoring ──────────────────────────────────────────────────────────
alias nv='watch -n 1 nvidia-smi'
alias nvtop='nvitop'

# ─── Shell Options ─────────────────────────────────────────────────────────────
setopt AUTO_CD
setopt NO_BEEP
setopt NO_HIST_BEEP
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_SAVE_NO_DUPS
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt INTERACTIVE_COMMENTS
setopt MAGIC_EQUAL_SUBST
setopt NO_NO_MATCH
setopt NOTIFY
setopt NUMERIC_GLOB_SORT
setopt PROMPT_SUBST

# ─── History ───────────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HIST_STAMPS=mm/dd/yyyy
HISTSIZE=100000
SAVEHIST=100000
ZLE_RPROMPT_INDENT=0
WORDCHARS=${WORDCHARS//\/}
PROMPT_EOL_MARK=
TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'

# ─── Key Bindings ──────────────────────────────────────────────────────────────
bindkey -e
bindkey '^U' backward-kill-line
bindkey '^[[2~' overwrite-mode
bindkey '^[[3~' delete-char
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[[3;5~' kill-word
bindkey '^[[5~' beginning-of-buffer-or-history
bindkey '^[[6~' end-of-buffer-or-history
bindkey '^[[Z' undo
bindkey ' ' magic-space

# history-substring-search keybindings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# ─── Misc Settings ────────────────────────────────────────────────────────────
export VISUAL=nvim
export EDITOR=$VISUAL
setterm -linewrap on 2> /dev/null

# Colorize man pages (Catppuccin Mocha)
export LESS_TERMCAP_mb=$'\e[1;38;2;249;226;175m'
export LESS_TERMCAP_md=$'\e[1;38;2;203;166;247m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[38;2;30;30;46;48;2;137;180;250m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[4;38;2;166;227;161m'
export LESSHISTFILE=-

# Colorize ls output
[ -x /usr/bin/dircolors ] && eval "$(dircolors -b)"

# ─── Conda (lazy-loaded) ──────────────────────────────────────────────────────
if [ -d "$HOME/miniconda3" ]; then
    conda() {
        unfunction conda
        __conda_setup="$("$HOME/miniconda3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
        if [ $? -eq 0 ]; then
            eval "$__conda_setup"
        else
            if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
                . "$HOME/miniconda3/etc/profile.d/conda.sh"
            else
                export PATH="$HOME/miniconda3/bin:$PATH"
            fi
        fi
        unset __conda_setup
        conda "$@"
    }
fi

# ─── CUDA (auto-detect) ──────────────────────────────────────────────────────
if [ -d "/usr/local/cuda" ]; then
    export CUDA_HOME=/usr/local/cuda
    export CUDA_ROOT=$CUDA_HOME
    export PATH=$CUDA_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$CUDA_HOME/lib64:${LD_LIBRARY_PATH:-}
fi

# ─── direnv (per-project environments) ────────────────────────────────────────
if command -v direnv > /dev/null; then
    eval "$(direnv hook zsh)"
fi

# ─── Atuin (better shell history) ─────────────────────────────────────────────
[ -f "$HOME/.atuin/bin/env" ] && . "$HOME/.atuin/bin/env"
if command -v atuin > /dev/null; then
    eval "$(atuin init zsh --disable-up-arrow)"
fi

# ─── Deduplicate PATH and LD_LIBRARY_PATH ─────────────────────────────────────
typeset -U PATH path
typeset -U LD_LIBRARY_PATH

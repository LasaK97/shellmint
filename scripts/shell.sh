#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# =============================================================================
# shell.sh — Shell environment installer (Zsh, Oh My Zsh, plugins, tools)
# =============================================================================

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# -----------------------------------------------------------------------------
# Helper: clone or update an OMZ plugin
# -----------------------------------------------------------------------------
_install_omz_plugin() {
    local name="$1"
    local repo="$2"
    local dest="$ZSH_CUSTOM/plugins/$name"

    if [[ -d "$dest" ]]; then
        print_info "$name already installed — skipping"
        return 0
    fi

    git clone --depth=1 "https://github.com/$repo.git" "$dest" &>/dev/null &
    if ! spinner $! "Cloning $name"; then
        register_failure "$name" "git clone https://github.com/$repo.git $dest"
        return 1
    fi
}

# =============================================================================
# Main installer
# =============================================================================
install_shell() {
    print_header "Shell Environment Setup"
    timer_start

    local installed=0
    local skipped=0
    local failed=0

    # ── Zsh ──────────────────────────────────────────────────────────────────
    print_step "Installing Zsh"
    if command_exists zsh; then
        print_info "Zsh is already installed ($(zsh --version))"
        (( skipped++ ))
    else
        sudo apt install -y zsh &>/dev/null &
        if spinner $! "Installing zsh via apt"; then
            print_success "Zsh installed"
            (( installed++ ))
        else
            print_error "Failed to install zsh"
            register_failure "zsh" "sudo apt install zsh"
            (( failed++ ))
        fi
    fi

    # ── Set zsh as default shell ─────────────────────────────────────────────
    print_step "Setting Zsh as default shell"
    local current_shell
    current_shell="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$current_shell" == *"zsh"* ]]; then
        print_info "Zsh is already the default shell"
    else
        if sudo chsh -s "$(which zsh)" "$USER" 2>/dev/null; then
            print_success "Default shell changed to zsh"
        else
            print_warning "Could not change default shell — you may need to run: sudo chsh -s \$(which zsh) \$USER"
        fi
    fi

    # ── Oh My Zsh ────────────────────────────────────────────────────────────
    print_step "Installing Oh My Zsh"
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        print_info "Oh My Zsh is already installed"
        (( skipped++ ))
    else
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended &>/dev/null &
        if spinner $! "Installing Oh My Zsh"; then
            print_success "Oh My Zsh installed"
            (( installed++ ))
        else
            print_error "Failed to install Oh My Zsh"
            register_failure "Oh My Zsh" "sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
            (( failed++ ))
        fi
    fi

    # ── Oh My Zsh Plugins ────────────────────────────────────────────────────
    print_step "Installing Oh My Zsh plugins"

    _install_omz_plugin "zsh-autosuggestions"           "zsh-users/zsh-autosuggestions"           && (( installed++ )) || (( failed++ ))
    _install_omz_plugin "fast-syntax-highlighting"      "zdharma-continuum/fast-syntax-highlighting" && (( installed++ )) || (( failed++ ))
    _install_omz_plugin "zsh-history-substring-search"  "zsh-users/zsh-history-substring-search"  && (( installed++ )) || (( failed++ ))
    _install_omz_plugin "zsh-autopair"                  "hlissner/zsh-autopair"                   && (( installed++ )) || (( failed++ ))
    _install_omz_plugin "zsh-you-should-use"            "MichaelAquilina/zsh-you-should-use"      && (( installed++ )) || (( failed++ ))
    _install_omz_plugin "zsh-completions"               "zsh-users/zsh-completions"               && (( installed++ )) || (( failed++ ))
    _install_omz_plugin "fzf-tab"                       "Aloxaf/fzf-tab"                          && (( installed++ )) || (( failed++ ))

    # ── Oh My Posh ───────────────────────────────────────────────────────────
    print_step "Installing Oh My Posh"
    if command_exists oh-my-posh; then
        print_info "Oh My Posh is already installed"
        (( skipped++ ))
    else
        curl -s https://ohmyposh.dev/install.sh | bash -s &>/dev/null &
        if spinner $! "Installing Oh My Posh"; then
            print_success "Oh My Posh installed"
            (( installed++ ))
        else
            print_error "Failed to install Oh My Posh"
            register_failure "Oh My Posh" "curl -s https://ohmyposh.dev/install.sh | bash -s"
            (( failed++ ))
        fi
    fi

    # ── Atuin ────────────────────────────────────────────────────────────────
    print_step "Installing Atuin"
    if command_exists atuin; then
        print_info "Atuin is already installed"
        (( skipped++ ))
    else
        (
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            local arch
            arch="$(get_arch)"
            local version
            version="$(get_github_version "atuinsh/atuin" "${ATUIN_VERSION:-18.4.0}")"
            local filename="atuin-${arch}-unknown-linux-musl.tar.gz"
            download_github_release "atuinsh/atuin" "$version" "$filename" "$tmp_dir/atuin.tar.gz"
            tar -xzf "$tmp_dir/atuin.tar.gz" -C "$tmp_dir"
            sudo install "$tmp_dir"/atuin-${arch}-unknown-linux-musl/atuin /usr/local/bin/atuin 2>/dev/null || \
                sudo install "$tmp_dir/atuin" /usr/local/bin/atuin 2>/dev/null
            rm -rf "$tmp_dir"
        ) &>/dev/null &
        if spinner $! "Installing Atuin"; then
            print_success "Atuin installed"
            (( installed++ ))
        else
            print_error "Failed to install Atuin"
            register_failure "Atuin" "https://github.com/atuinsh/atuin/releases"
            (( failed++ ))
        fi
    fi

    # ── Copy config files ────────────────────────────────────────────────────
    print_step "Copying configuration files"

    # .zshrc
    local src_zshrc="$SCRIPT_DIR/../configs/.zshrc"
    if [[ -f "$src_zshrc" ]]; then
        [[ -f "$HOME/.zshrc" ]] && backup_file "$HOME/.zshrc"
        cp "$src_zshrc" "$HOME/.zshrc"
        print_success "Copied .zshrc"
        (( installed++ ))
    else
        print_warning "Source .zshrc not found at $src_zshrc — skipping"
        (( skipped++ ))
    fi

    # .zshenv
    local src_zshenv="$SCRIPT_DIR/../configs/.zshenv"
    if [[ -f "$src_zshenv" ]]; then
        [[ -f "$HOME/.zshenv" ]] && backup_file "$HOME/.zshenv"
        cp "$src_zshenv" "$HOME/.zshenv"
        print_success "Copied .zshenv"
        (( installed++ ))
    else
        print_warning "Source .zshenv not found at $src_zshenv — skipping"
        (( skipped++ ))
    fi

    # Oh My Posh theme
    local src_theme="$SCRIPT_DIR/../configs/oh-my-posh/theme.omp.json"
    local dest_theme="$HOME/.config/oh-my-posh/theme.omp.json"
    if [[ -f "$src_theme" ]]; then
        mkdir -p "$(dirname "$dest_theme")"
        [[ -f "$dest_theme" ]] && backup_file "$dest_theme"
        cp "$src_theme" "$dest_theme"
        print_success "Copied Oh My Posh theme"
        (( installed++ ))
    else
        print_warning "Source theme not found at $src_theme — skipping"
        (( skipped++ ))
    fi

    # ── Summary ──────────────────────────────────────────────────────────────
    local duration
    duration="$(timer_elapsed)"

    echo ""
    echo "${BOLD}${CYAN} ── Shell Setup Summary ────────────────────────────────${RESET}"
    echo "${GREEN}   ${CHECKMARK} Installed/configured: ${installed}${RESET}"
    echo "${YELLOW}   ${ARROW} Skipped (already present): ${skipped}${RESET}"
    [[ $failed -gt 0 ]] && echo "${RED}   ${CROSSMARK} Failed: ${failed}${RESET}"
    echo "${DIM}   Total time: ${duration}${RESET}"
    echo ""
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    ensure_sudo
    install_shell
fi

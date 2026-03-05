#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# =============================================================================
# editor.sh — Neovim installer with config deployment
# =============================================================================

install_editor() {
    print_header "Editor Setup (Neovim)"
    timer_start

    local installed=0
    local skipped=0
    local failed=0

    # ── Neovim ───────────────────────────────────────────────────────────────
    print_step "Installing Neovim (latest stable)"
    if command_exists nvim; then
        local nvim_ver
        nvim_ver="$(nvim --version 2>/dev/null | head -1)"
        print_info "Neovim is already installed ($nvim_ver)"
        (( skipped++ ))
    else
        (
            mkdir -p "$HOME/.local/bin"
            curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage" \
                -o "$HOME/.local/bin/nvim"
            chmod +x "$HOME/.local/bin/nvim"

            # Create symlink in /usr/local/bin for system-wide access
            sudo ln -sf "$HOME/.local/bin/nvim" /usr/local/bin/nvim 2>/dev/null || true
        ) &>/dev/null &
        if spinner $! "Downloading Neovim AppImage"; then
            print_success "Neovim installed to ~/.local/bin/nvim"
            (( installed++ ))
        else
            print_error "Failed to install Neovim"
            (( failed++ ))
        fi
    fi

    # ── Neovim config ────────────────────────────────────────────────────────
    print_step "Deploying Neovim configuration"
    local src_nvim="$SCRIPT_DIR/../configs/nvim"
    local dest_nvim="$HOME/.config/nvim"

    if [[ -d "$src_nvim" ]]; then
        # Backup existing config
        if [[ -d "$dest_nvim" ]]; then
            local timestamp
            timestamp="$(date +%Y%m%d_%H%M%S)"
            local backup_dir="${dest_nvim}.backup.${timestamp}"
            print_info "Backing up existing nvim config to ${backup_dir}"
            mv "$dest_nvim" "$backup_dir"
        fi

        mkdir -p "$(dirname "$dest_nvim")"
        cp -r "$src_nvim" "$dest_nvim"
        print_success "Neovim config copied to $dest_nvim"
        (( installed++ ))
    else
        print_warning "Source nvim config not found at $src_nvim — skipping"
        (( skipped++ ))
    fi

    # ── Notes ────────────────────────────────────────────────────────────────
    echo ""
    print_info "Note: LazyVim will automatically install plugins on first launch."
    print_info "Run 'nvim' to complete the setup — initial launch may take a moment."

    # ── Summary ──────────────────────────────────────────────────────────────
    local duration
    duration="$(timer_elapsed)"

    echo ""
    echo "${BOLD}${CYAN} ── Editor Setup Summary ───────────────────────────────${RESET}"
    echo "${GREEN}   ${CHECKMARK} Installed/configured: ${installed}${RESET}"
    echo "${YELLOW}   ${ARROW} Skipped (already present): ${skipped}${RESET}"
    [[ $failed -gt 0 ]] && echo "${RED}   ${CROSSMARK} Failed: ${failed}${RESET}"
    echo "${DIM}   Total time: ${duration}${RESET}"
    echo ""
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    ensure_sudo
    install_editor
fi

#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# =============================================================================
# terminal.sh — Terminal emulator and font installer (Kitty, Hack Nerd Font)
# =============================================================================

install_terminal() {
    print_header "Terminal Emulator Setup"
    timer_start

    local installed=0
    local skipped=0
    local failed=0

    # ── Kitty Terminal ───────────────────────────────────────────────────────
    print_step "Installing Kitty terminal"
    if command_exists kitty; then
        print_info "Kitty is already installed ($(kitty --version 2>/dev/null))"
        (( skipped++ ))
    else
        curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n &>/dev/null &
        if spinner $! "Downloading and installing Kitty"; then
            # Create symlinks
            sudo ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/kitty.app/bin/kitten" /usr/local/bin/ 2>/dev/null

            # Desktop integration
            mkdir -p "$HOME/.local/share/applications"
            if [[ -f "$HOME/.local/kitty.app/share/applications/kitty.desktop" ]]; then
                cp "$HOME/.local/kitty.app/share/applications/kitty.desktop" "$HOME/.local/share/applications/"
                # Update icon path in desktop file
                sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" \
                    "$HOME/.local/share/applications/kitty.desktop" 2>/dev/null
            fi

            print_success "Kitty installed and desktop entry configured"
            (( installed++ ))
        else
            print_error "Failed to install Kitty"
            (( failed++ ))
        fi
    fi

    # ── Hack Nerd Font ───────────────────────────────────────────────────────
    print_step "Installing Hack Nerd Font"
    local font_dir="$HOME/.local/share/fonts"

    if fc-list 2>/dev/null | grep -qi "Hack.*Nerd"; then
        print_info "Hack Nerd Font is already installed"
        (( skipped++ ))
    else
        (
            mkdir -p "$font_dir"
            local tmp_dir
            tmp_dir="$(mktemp -d)"

            # Get latest release URL
            local download_url
            download_url="$(curl -sL "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest" \
                | grep -oP '"browser_download_url":\s*"\K[^"]*Hack\.zip')"

            if [[ -z "$download_url" ]]; then
                # Fallback to a known pattern
                download_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip"
            fi

            curl -fsSL "$download_url" -o "$tmp_dir/Hack.zip" && \
            unzip -qo "$tmp_dir/Hack.zip" -d "$font_dir/" && \
            rm -rf "$tmp_dir"
        ) &>/dev/null &

        if spinner $! "Downloading and installing Hack Nerd Font"; then
            fc-cache -fv &>/dev/null
            print_success "Hack Nerd Font installed"
            (( installed++ ))
        else
            print_error "Failed to install Hack Nerd Font"
            (( failed++ ))
        fi
    fi

    # ── Copy Kitty config ────────────────────────────────────────────────────
    print_step "Copying Kitty configuration"
    local src_kitty="$SCRIPT_DIR/../configs/kitty/kitty.conf"
    local dest_kitty="$HOME/.config/kitty/kitty.conf"

    if [[ -f "$src_kitty" ]]; then
        mkdir -p "$(dirname "$dest_kitty")"
        [[ -f "$dest_kitty" ]] && backup_file "$dest_kitty"
        cp "$src_kitty" "$dest_kitty"
        print_success "Copied kitty.conf"
        (( installed++ ))
    else
        print_warning "Source kitty.conf not found at $src_kitty — skipping"
        (( skipped++ ))
    fi

    # ── Summary ──────────────────────────────────────────────────────────────
    local duration
    duration="$(timer_elapsed)"

    echo ""
    echo "${BOLD}${CYAN} ── Terminal Setup Summary ─────────────────────────────${RESET}"
    echo "${GREEN}   ${CHECKMARK} Installed/configured: ${installed}${RESET}"
    echo "${YELLOW}   ${ARROW} Skipped (already present): ${skipped}${RESET}"
    [[ $failed -gt 0 ]] && echo "${RED}   ${CROSSMARK} Failed: ${failed}${RESET}"
    echo "${DIM}   Total time: ${duration}${RESET}"
    echo ""
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    ensure_sudo
    install_terminal
fi

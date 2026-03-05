#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# =============================================================================
# cli-tools.sh — Modern CLI tools installer
# =============================================================================

# Total number of tools for progress tracking
_CLI_TOOLS_TOTAL=15
_CLI_TOOLS_CURRENT=0

_cli_progress() {
    local label="$1"
    (( _CLI_TOOLS_CURRENT++ ))
    progress_bar "$_CLI_TOOLS_CURRENT" "$_CLI_TOOLS_TOTAL" "$label"
}

install_cli_tools() {
    print_header "Modern CLI Tools"
    timer_start

    local installed=0
    local skipped=0
    local failed=0
    _CLI_TOOLS_CURRENT=0

    # ── eza ──────────────────────────────────────────────────────────────────
    print_step "Installing eza (modern ls)"
    if command_exists eza; then
        print_info "eza is already installed"
        (( skipped++ ))
    else
        (
            local ubuntu_ver
            ubuntu_ver="$(get_ubuntu_version)"
            if [[ "$ubuntu_ver" != "unknown" ]] && dpkg --compare-versions "$ubuntu_ver" "ge" "24.04" 2>/dev/null; then
                sudo apt install -y eza
            elif command_exists cargo; then
                cargo install eza
            else
                # Try apt anyway (some repos have it)
                sudo mkdir -p /etc/apt/keyrings
                wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg 2>/dev/null
                echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list >/dev/null
                sudo apt update && sudo apt install -y eza
            fi
        ) &>/dev/null &
        if spinner $! "Installing eza"; then
            print_success "eza installed"
            (( installed++ ))
        else
            print_error "Failed to install eza"
            (( failed++ ))
        fi
    fi
    _cli_progress "eza"

    # ── bat ──────────────────────────────────────────────────────────────────
    print_step "Installing bat (modern cat)"
    if command_exists bat || command_exists batcat; then
        print_info "bat is already installed"
        (( skipped++ ))
    else
        (
            sudo apt install -y bat
            # On Ubuntu/Debian the binary is 'batcat' — create a symlink
            if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
                sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
            fi
        ) &>/dev/null &
        if spinner $! "Installing bat"; then
            # Double-check symlink after spinner (subprocess may not persist)
            if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
                sudo ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null
            fi
            print_success "bat installed"
            (( installed++ ))
        else
            print_error "Failed to install bat"
            (( failed++ ))
        fi
    fi
    _cli_progress "bat"

    # ── fd-find ──────────────────────────────────────────────────────────────
    print_step "Installing fd (modern find)"
    if command_exists fd || command_exists fdfind; then
        print_info "fd is already installed"
        (( skipped++ ))
    else
        (
            sudo apt install -y fd-find
            if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
                sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
            fi
        ) &>/dev/null &
        if spinner $! "Installing fd-find"; then
            if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
                sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd 2>/dev/null
            fi
            print_success "fd installed"
            (( installed++ ))
        else
            print_error "Failed to install fd"
            (( failed++ ))
        fi
    fi
    _cli_progress "fd"

    # ── ripgrep ──────────────────────────────────────────────────────────────
    print_step "Installing ripgrep (modern grep)"
    if command_exists rg; then
        print_info "ripgrep is already installed"
        (( skipped++ ))
    else
        sudo apt install -y ripgrep &>/dev/null &
        if spinner $! "Installing ripgrep"; then
            print_success "ripgrep installed"
            (( installed++ ))
        else
            print_error "Failed to install ripgrep"
            (( failed++ ))
        fi
    fi
    _cli_progress "ripgrep"

    # ── fzf ──────────────────────────────────────────────────────────────────
    print_step "Installing fzf (fuzzy finder)"
    if command_exists fzf; then
        print_info "fzf is already installed"
        (( skipped++ ))
    else
        (
            git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
            "$HOME/.fzf/install" --all --no-update-rc
        ) &>/dev/null &
        if spinner $! "Installing fzf"; then
            print_success "fzf installed"
            (( installed++ ))
        else
            print_error "Failed to install fzf"
            (( failed++ ))
        fi
    fi
    _cli_progress "fzf"

    # ── zoxide ───────────────────────────────────────────────────────────────
    print_step "Installing zoxide (modern cd)"
    if command_exists zoxide; then
        print_info "zoxide is already installed"
        (( skipped++ ))
    else
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh &>/dev/null &
        if spinner $! "Installing zoxide"; then
            print_success "zoxide installed"
            (( installed++ ))
        else
            print_error "Failed to install zoxide"
            (( failed++ ))
        fi
    fi
    _cli_progress "zoxide"

    # ── jq ───────────────────────────────────────────────────────────────────
    print_step "Installing jq (JSON processor)"
    if command_exists jq; then
        print_info "jq is already installed"
        (( skipped++ ))
    else
        sudo apt install -y jq &>/dev/null &
        if spinner $! "Installing jq"; then
            print_success "jq installed"
            (( installed++ ))
        else
            print_error "Failed to install jq"
            (( failed++ ))
        fi
    fi
    _cli_progress "jq"

    # ── btop ─────────────────────────────────────────────────────────────────
    print_step "Installing btop (system monitor)"
    if command_exists btop; then
        print_info "btop is already installed"
        (( skipped++ ))
    else
        sudo apt install -y btop &>/dev/null &
        if spinner $! "Installing btop"; then
            print_success "btop installed"
            (( installed++ ))
        else
            print_error "Failed to install btop"
            (( failed++ ))
        fi
    fi
    _cli_progress "btop"

    # ── lazygit ──────────────────────────────────────────────────────────────
    print_step "Installing lazygit (git TUI)"
    if command_exists lazygit; then
        print_info "lazygit is already installed"
        (( skipped++ ))
    else
        (
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            local lazygit_version
            lazygit_version="$(curl -sL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -oP '"tag_name":\s*"v\K[^"]*')"
            if [[ -n "$lazygit_version" ]]; then
                curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${lazygit_version}/lazygit_${lazygit_version}_Linux_x86_64.tar.gz" \
                    -o "$tmp_dir/lazygit.tar.gz"
                tar -xzf "$tmp_dir/lazygit.tar.gz" -C "$tmp_dir"
                sudo install "$tmp_dir/lazygit" /usr/local/bin/lazygit
            fi
            rm -rf "$tmp_dir"
        ) &>/dev/null &
        if spinner $! "Installing lazygit"; then
            print_success "lazygit installed"
            (( installed++ ))
        else
            print_error "Failed to install lazygit"
            (( failed++ ))
        fi
    fi
    _cli_progress "lazygit"

    # ── delta ────────────────────────────────────────────────────────────────
    print_step "Installing delta (git diff pager)"
    if command_exists delta; then
        print_info "delta is already installed"
        (( skipped++ ))
    else
        (
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            local delta_version
            delta_version="$(curl -sL "https://api.github.com/repos/dandavison/delta/releases/latest" | grep -oP '"tag_name":\s*"\K[^"]*')"
            if [[ -n "$delta_version" ]]; then
                curl -fsSL "https://github.com/dandavison/delta/releases/download/${delta_version}/git-delta_${delta_version}_amd64.deb" \
                    -o "$tmp_dir/delta.deb"
                sudo dpkg -i "$tmp_dir/delta.deb"
            fi
            rm -rf "$tmp_dir"
        ) &>/dev/null &
        if spinner $! "Installing delta"; then
            print_success "delta installed"
            (( installed++ ))
        else
            print_error "Failed to install delta"
            (( failed++ ))
        fi
    fi
    _cli_progress "delta"

    # ── dust ─────────────────────────────────────────────────────────────────
    print_step "Installing dust (modern du)"
    if command_exists dust; then
        print_info "dust is already installed"
        (( skipped++ ))
    else
        if command_exists cargo; then
            cargo install du-dust &>/dev/null &
            if spinner $! "Installing dust via cargo"; then
                print_success "dust installed"
                (( installed++ ))
            else
                print_error "Failed to install dust"
                (( failed++ ))
            fi
        else
            (
                local tmp_dir
                tmp_dir="$(mktemp -d)"
                local dust_version
                dust_version="$(curl -sL "https://api.github.com/repos/bootandy/dust/releases/latest" | grep -oP '"tag_name":\s*"v\K[^"]*')"
                if [[ -n "$dust_version" ]]; then
                    curl -fsSL "https://github.com/bootandy/dust/releases/download/v${dust_version}/dust-v${dust_version}-x86_64-unknown-linux-gnu.tar.gz" \
                        -o "$tmp_dir/dust.tar.gz"
                    tar -xzf "$tmp_dir/dust.tar.gz" -C "$tmp_dir"
                    sudo install "$tmp_dir"/dust-*/dust /usr/local/bin/dust
                fi
                rm -rf "$tmp_dir"
            ) &>/dev/null &
            if spinner $! "Installing dust from github release"; then
                print_success "dust installed"
                (( installed++ ))
            else
                print_error "Failed to install dust"
                (( failed++ ))
            fi
        fi
    fi
    _cli_progress "dust"

    # ── glow ─────────────────────────────────────────────────────────────────
    print_step "Installing glow (markdown renderer)"
    if command_exists glow; then
        print_info "glow is already installed"
        (( skipped++ ))
    else
        if command_exists go; then
            go install github.com/charmbracelet/glow@latest &>/dev/null &
            if spinner $! "Installing glow via go"; then
                print_success "glow installed"
                (( installed++ ))
            else
                print_error "Failed to install glow"
                (( failed++ ))
            fi
        else
            print_warning "Go not found — skipping glow (install Go first)"
            (( skipped++ ))
        fi
    fi
    _cli_progress "glow"

    # ── yazi ─────────────────────────────────────────────────────────────────
    print_step "Installing yazi (file manager)"
    if command_exists yazi; then
        print_info "yazi is already installed"
        (( skipped++ ))
    else
        if command_exists cargo; then
            cargo install --locked yazi-fm yazi-cli &>/dev/null &
            if spinner $! "Installing yazi via cargo (this may take a while)"; then
                print_success "yazi installed"
                (( installed++ ))
            else
                print_error "Failed to install yazi"
                (( failed++ ))
            fi
        else
            print_warning "Cargo not found — skipping yazi (install Rust first)"
            (( skipped++ ))
        fi
    fi
    _cli_progress "yazi"

    # ── direnv ───────────────────────────────────────────────────────────────
    print_step "Installing direnv"
    if command_exists direnv; then
        print_info "direnv is already installed"
        (( skipped++ ))
    else
        sudo apt install -y direnv &>/dev/null &
        if spinner $! "Installing direnv"; then
            print_success "direnv installed"
            (( installed++ ))
        else
            print_error "Failed to install direnv"
            (( failed++ ))
        fi
    fi
    _cli_progress "direnv"

    # ── zellij ───────────────────────────────────────────────────────────────
    print_step "Installing zellij (terminal multiplexer)"
    if command_exists zellij; then
        print_info "zellij is already installed"
        (( skipped++ ))
    else
        if command_exists cargo; then
            cargo install --locked zellij &>/dev/null &
            if spinner $! "Installing zellij via cargo (this may take a while)"; then
                print_success "zellij installed"
                (( installed++ ))
            else
                print_error "Failed to install zellij"
                (( failed++ ))
            fi
        else
            print_warning "Cargo not found — skipping zellij (install Rust first)"
            (( skipped++ ))
        fi
    fi
    _cli_progress "zellij"

    # ── Summary ──────────────────────────────────────────────────────────────
    local duration
    duration="$(timer_elapsed)"

    echo ""
    echo "${BOLD}${CYAN} ── CLI Tools Summary ──────────────────────────────────${RESET}"
    echo "${GREEN}   ${CHECKMARK} Installed: ${installed}${RESET}"
    echo "${YELLOW}   ${ARROW} Skipped (already present or missing dependency): ${skipped}${RESET}"
    [[ $failed -gt 0 ]] && echo "${RED}   ${CROSSMARK} Failed: ${failed}${RESET}"
    echo "${DIM}   Total tools: ${_CLI_TOOLS_TOTAL} | Total time: ${duration}${RESET}"
    echo ""
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    ensure_sudo
    install_cli_tools
fi

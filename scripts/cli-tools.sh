#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# =============================================================================
# cli-tools.sh — Modern CLI tools installer
# Uses pre-built binaries with architecture-aware downloads.
# Falls back gracefully and registers failures for manual install.
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

    # Detect system architecture once
    local arch deb_arch
    arch="$(get_arch)"
    deb_arch="$(get_deb_arch)"

    # Map uname -m to common GitHub release naming conventions
    local gh_arch="$arch"              # x86_64 or aarch64
    local rust_target=""
    case "$arch" in
        x86_64)  rust_target="x86_64-unknown-linux"  ;;
        aarch64) rust_target="aarch64-unknown-linux" ; gh_arch="arm64" ;;
        *)
            print_warning "Unsupported architecture: $arch — some tools may fail"
            rust_target="$arch-unknown-linux"
            ;;
    esac

    print_info "Detected: arch=$arch deb_arch=$deb_arch"

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
            else
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
            register_failure "eza" "sudo apt install eza  OR  cargo install eza"
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
            if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
                sudo ln -sf /usr/bin/batcat /usr/local/bin/bat
            fi
        ) &>/dev/null &
        if spinner $! "Installing bat"; then
            if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
                sudo ln -sf /usr/bin/batcat /usr/local/bin/bat 2>/dev/null
            fi
            print_success "bat installed"
            (( installed++ ))
        else
            print_error "Failed to install bat"
            register_failure "bat" "sudo apt install bat"
            (( failed++ ))
        fi
    fi

    # Install Catppuccin Mocha theme for bat
    local bat_themes_dir
    bat_themes_dir="$(bat --config-dir 2>/dev/null || echo "$HOME/.config/bat")/themes"
    if [[ ! -f "$bat_themes_dir/Catppuccin Mocha.tmTheme" ]]; then
        (
            mkdir -p "$bat_themes_dir"
            curl -fsSL "https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme" \
                -o "$bat_themes_dir/Catppuccin Mocha.tmTheme"
            bat cache --build > /dev/null 2>&1 || batcat cache --build > /dev/null 2>&1
        ) &>/dev/null &
        if spinner $! "Installing bat Catppuccin theme"; then
            print_success "bat Catppuccin Mocha theme installed"
        else
            print_warning "bat theme install failed — bat will use default theme"
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
            register_failure "fd" "sudo apt install fd-find"
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
            register_failure "ripgrep" "sudo apt install ripgrep"
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
            register_failure "fzf" "git clone https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install"
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
            register_failure "zoxide" "curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh"
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
            register_failure "jq" "sudo apt install jq"
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
            register_failure "btop" "sudo apt install btop"
            (( failed++ ))
        fi
    fi
    _cli_progress "btop"

    # ── lazygit ──────────────────────────────────────────────────────────────
    print_step "Installing lazygit (git TUI)"
    if ! should_install lazygit; then
        print_info "lazygit is already installed"
        (( skipped++ ))
    else
        (
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            local version
            version="$(get_github_version "jesseduffield/lazygit" "${LAZYGIT_VERSION:-0.44.1}")"
            local filename="lazygit_${version}_Linux_${arch}.tar.gz"
            download_github_release "jesseduffield/lazygit" "$version" "$filename" "$tmp_dir/lazygit.tar.gz"
            tar -xzf "$tmp_dir/lazygit.tar.gz" -C "$tmp_dir"
            sudo install "$tmp_dir/lazygit" /usr/local/bin/lazygit
            rm -rf "$tmp_dir"
        ) &>/dev/null &
        if spinner $! "Installing lazygit (verified)"; then
            print_success "lazygit installed"
            (( installed++ ))
        else
            print_error "Failed to install lazygit"
            register_failure "lazygit" "https://github.com/jesseduffield/lazygit/releases"
            (( failed++ ))
        fi
    fi
    _cli_progress "lazygit"

    # ── delta ────────────────────────────────────────────────────────────────
    print_step "Installing delta (git diff pager)"
    if ! should_install delta; then
        print_info "delta is already installed"
        (( skipped++ ))
    else
        (
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            local version
            version="$(get_github_version "dandavison/delta" "${DELTA_VERSION:-0.18.2}")"
            local filename="git-delta_${version}_${deb_arch}.deb"
            download_github_release "dandavison/delta" "$version" "$filename" "$tmp_dir/delta.deb"
            sudo dpkg -i "$tmp_dir/delta.deb"
            rm -rf "$tmp_dir"
        ) &>/dev/null &
        if spinner $! "Installing delta"; then
            print_success "delta installed"
            (( installed++ ))
        else
            print_error "Failed to install delta"
            register_failure "delta" "https://github.com/dandavison/delta/releases"
            (( failed++ ))
        fi
    fi
    _cli_progress "delta"

    # ── dust ─────────────────────────────────────────────────────────────────
    print_step "Installing dust (modern du)"
    if ! should_install dust; then
        print_info "dust is already installed"
        (( skipped++ ))
    else
        (
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            local version
            version="$(get_github_version "bootandy/dust" "${DUST_VERSION:-1.1.1}")"
            local filename="dust-v${version}-${rust_target}-gnu.tar.gz"
            download_github_release "bootandy/dust" "$version" "$filename" "$tmp_dir/dust.tar.gz"
            tar -xzf "$tmp_dir/dust.tar.gz" -C "$tmp_dir"
            sudo install "$tmp_dir"/dust-*/dust /usr/local/bin/dust
            rm -rf "$tmp_dir"
        ) &>/dev/null &
        if spinner $! "Installing dust"; then
            print_success "dust installed"
            (( installed++ ))
        else
            print_error "Failed to install dust"
            register_failure "dust" "https://github.com/bootandy/dust/releases"
            (( failed++ ))
        fi
    fi
    _cli_progress "dust"

    # ── glow ─────────────────────────────────────────────────────────────────
    print_step "Installing glow (markdown renderer)"
    if ! should_install glow; then
        print_info "glow is already installed"
        (( skipped++ ))
    else
        (
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            local version
            version="$(get_github_version "charmbracelet/glow" "${GLOW_VERSION:-2.0.0}")"
            local filename="glow_${version}_${deb_arch}.deb"
            download_github_release "charmbracelet/glow" "$version" "$filename" "$tmp_dir/glow.deb"
            sudo dpkg -i "$tmp_dir/glow.deb"
            rm -rf "$tmp_dir"
        ) &>/dev/null &
        if spinner $! "Installing glow"; then
            print_success "glow installed"
            (( installed++ ))
        else
            print_error "Failed to install glow"
            register_failure "glow" "https://github.com/charmbracelet/glow/releases"
            (( failed++ ))
        fi
    fi
    _cli_progress "glow"

    # ── yazi ─────────────────────────────────────────────────────────────────
    print_step "Installing yazi (file manager)"
    if ! should_install yazi; then
        print_info "yazi is already installed"
        (( skipped++ ))
    else
        (
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            local version
            version="$(get_github_version "sxyazi/yazi" "${YAZI_VERSION:-25.4.8}")"
            local filename="yazi-${rust_target}-gnu.zip"
            download_github_release "sxyazi/yazi" "$version" "$filename" "$tmp_dir/yazi.zip"
            unzip -qo "$tmp_dir/yazi.zip" -d "$tmp_dir"
            sudo install "$tmp_dir"/yazi-${rust_target}*/yazi /usr/local/bin/yazi
            sudo install "$tmp_dir"/yazi-${rust_target}*/ya /usr/local/bin/ya 2>/dev/null || true
            rm -rf "$tmp_dir"
        ) &>/dev/null &
        if spinner $! "Installing yazi"; then
            print_success "yazi installed"
            (( installed++ ))
        else
            print_error "Failed to install yazi"
            register_failure "yazi" "https://github.com/sxyazi/yazi/releases"
            (( failed++ ))
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
            register_failure "direnv" "sudo apt install direnv"
            (( failed++ ))
        fi
    fi
    _cli_progress "direnv"

    # ── zellij ───────────────────────────────────────────────────────────────
    print_step "Installing zellij (terminal multiplexer)"
    if ! should_install zellij; then
        print_info "zellij is already installed"
        (( skipped++ ))
    else
        (
            local tmp_dir
            tmp_dir="$(mktemp -d)"
            local version
            version="$(get_github_version "zellij-org/zellij" "${ZELLIJ_VERSION:-0.41.2}")"
            local filename="zellij-${rust_target}-musl.tar.gz"
            download_github_release "zellij-org/zellij" "$version" "$filename" "$tmp_dir/zellij.tar.gz"
            tar -xzf "$tmp_dir/zellij.tar.gz" -C "$tmp_dir"
            sudo install "$tmp_dir/zellij" /usr/local/bin/zellij
            rm -rf "$tmp_dir"
        ) &>/dev/null &
        if spinner $! "Installing zellij"; then
            print_success "zellij installed"
            (( installed++ ))
        else
            print_error "Failed to install zellij"
            register_failure "zellij" "https://github.com/zellij-org/zellij/releases"
            (( failed++ ))
        fi
    fi
    _cli_progress "zellij"

    # ── Summary ──────────────────────────────────────────────────────────────
    local duration
    duration="$(timer_elapsed)"

    echo ""
    echo "${BOLD}${CYAN} ── CLI Tools Summary ──────────────────────────────────${RESET}"
    echo "${GREEN}   ${CHECKMARK} Installed: ${installed}${RESET}"
    echo "${YELLOW}   ${ARROW} Skipped (already present): ${skipped}${RESET}"
    [[ $failed -gt 0 ]] && echo "${RED}   ${CROSSMARK} Failed: ${failed}${RESET}"
    echo "${DIM}   Total tools: ${_CLI_TOOLS_TOTAL} | Total time: ${duration}${RESET}"
    echo ""
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    ensure_sudo
    install_cli_tools
    show_failed_tools
fi

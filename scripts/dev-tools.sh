#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# =============================================================================
# dev-tools.sh — Developer tools installer (Docker, Rust, Go, Node, Java, etc.)
# =============================================================================

install_dev_tools() {
    print_header "Developer Tools"
    timer_start

    local installed=0
    local skipped=0
    local failed=0

    # ── Docker ───────────────────────────────────────────────────────────────
    print_step "Installing Docker"
    if command_exists docker; then
        print_info "Docker is already installed ($(docker --version 2>/dev/null))"
        (( skipped++ ))
    else
        (
            # Remove old packages
            for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
                sudo apt-get remove -y "$pkg" 2>/dev/null || true
            done

            # Add Docker official GPG key
            sudo apt-get update
            sudo apt-get install -y ca-certificates curl
            sudo install -m 0755 -d /etc/apt/keyrings
            sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            sudo chmod a+r /etc/apt/keyrings/docker.asc

            # Add Docker apt repository
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
                sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

            sudo apt-get update
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ) &>/dev/null &
        if spinner $! "Installing Docker (this may take a minute)"; then
            # Add user to docker group
            sudo usermod -aG docker "$USER" 2>/dev/null
            print_success "Docker installed (log out and back in for group changes)"
            (( installed++ ))
        else
            print_error "Failed to install Docker"
            (( failed++ ))
        fi
    fi

    # ── Rust ─────────────────────────────────────────────────────────────────
    print_step "Installing Rust"
    if command_exists rustc; then
        print_info "Rust is already installed ($(rustc --version 2>/dev/null))"
        (( skipped++ ))
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &>/dev/null &
        if spinner $! "Installing Rust via rustup"; then
            # Source cargo env for current session
            # shellcheck disable=SC1091
            [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
            print_success "Rust installed"
            (( installed++ ))
        else
            print_error "Failed to install Rust"
            (( failed++ ))
        fi
    fi

    # ── Go ───────────────────────────────────────────────────────────────────
    print_step "Installing Go"
    if command_exists go; then
        print_info "Go is already installed ($(go version 2>/dev/null))"
        (( skipped++ ))
    else
        (
            local go_version
            go_version="$(curl -sL 'https://go.dev/VERSION?m=text' | head -1)"
            if [[ -n "$go_version" ]]; then
                curl -fsSL "https://go.dev/dl/${go_version}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
                sudo rm -rf /usr/local/go
                sudo tar -C /usr/local -xzf /tmp/go.tar.gz
                rm -f /tmp/go.tar.gz
            fi
        ) &>/dev/null &
        if spinner $! "Installing Go"; then
            export PATH="$PATH:/usr/local/go/bin"
            print_success "Go installed — add /usr/local/go/bin to PATH"
            (( installed++ ))
        else
            print_error "Failed to install Go"
            (( failed++ ))
        fi
    fi

    # ── Node.js (via nvm) ────────────────────────────────────────────────────
    print_step "Installing Node.js (via nvm)"
    if command_exists node; then
        print_info "Node.js is already installed ($(node --version 2>/dev/null))"
        (( skipped++ ))
    else
        (
            # Install nvm
            export NVM_DIR="$HOME/.nvm"
            curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash

            # Load nvm and install LTS
            # shellcheck disable=SC1091
            [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
            nvm install --lts
        ) &>/dev/null &
        if spinner $! "Installing Node.js LTS via nvm"; then
            print_success "Node.js installed"
            (( installed++ ))
        else
            print_error "Failed to install Node.js"
            (( failed++ ))
        fi
    fi

    # ── Java ─────────────────────────────────────────────────────────────────
    print_step "Installing Java (OpenJDK 17)"
    if command_exists java && java -version 2>&1 | grep -q "17"; then
        print_info "OpenJDK 17 is already installed"
        (( skipped++ ))
    else
        sudo apt install -y openjdk-17-jdk &>/dev/null &
        if spinner $! "Installing OpenJDK 17"; then
            print_success "OpenJDK 17 installed"
            (( installed++ ))
        else
            print_error "Failed to install OpenJDK 17"
            (( failed++ ))
        fi
    fi

    # ── CMake ────────────────────────────────────────────────────────────────
    print_step "Installing CMake"
    if command_exists cmake; then
        print_info "CMake is already installed ($(cmake --version 2>/dev/null | head -1))"
        (( skipped++ ))
    else
        sudo apt install -y cmake &>/dev/null &
        if spinner $! "Installing CMake"; then
            print_success "CMake installed"
            (( installed++ ))
        else
            print_error "Failed to install CMake"
            (( failed++ ))
        fi
    fi

    # ── Git delta config ─────────────────────────────────────────────────────
    print_step "Configuring Git with delta integration"
    local src_delta_config="$SCRIPT_DIR/../configs/git/.gitconfig-delta"
    if [[ -f "$src_delta_config" ]]; then
        # Copy delta config snippet
        mkdir -p "$HOME/.config/git"
        cp "$src_delta_config" "$HOME/.gitconfig-delta"

        # Include it from main gitconfig without overwriting user.name/user.email
        git config --global core.pager "delta"
        git config --global interactive.diffFilter "delta --color-only"
        git config --global delta.navigate true
        git config --global delta.dark true
        git config --global delta.line-numbers true
        git config --global delta.side-by-side true
        git config --global merge.conflictstyle "diff3"
        git config --global diff.colorMoved "default"
        git config --global include.path "$HOME/.gitconfig-delta"

        print_success "Git configured with delta as pager"
        (( installed++ ))
    else
        # Configure delta settings inline even without the config file
        if command_exists delta; then
            git config --global core.pager "delta"
            git config --global interactive.diffFilter "delta --color-only"
            git config --global delta.navigate true
            git config --global delta.dark true
            git config --global delta.line-numbers true
            git config --global delta.side-by-side true
            git config --global merge.conflictstyle "diff3"
            git config --global diff.colorMoved "default"
            print_success "Git configured with delta (inline settings)"
            (( installed++ ))
        else
            print_warning "Delta config file not found and delta not installed — skipping git config"
            (( skipped++ ))
        fi
    fi

    # ── pipx ─────────────────────────────────────────────────────────────────
    print_step "Installing pipx"
    if command_exists pipx; then
        print_info "pipx is already installed"
        (( skipped++ ))
    else
        sudo apt install -y pipx &>/dev/null &
        if spinner $! "Installing pipx"; then
            pipx ensurepath &>/dev/null 2>&1
            print_success "pipx installed"
            (( installed++ ))
        else
            print_error "Failed to install pipx"
            (( failed++ ))
        fi
    fi

    # ── uv ───────────────────────────────────────────────────────────────────
    print_step "Installing uv (Python package manager)"
    if command_exists uv; then
        print_info "uv is already installed ($(uv --version 2>/dev/null))"
        (( skipped++ ))
    else
        curl -LsSf https://astral.sh/uv/install.sh | sh &>/dev/null &
        if spinner $! "Installing uv"; then
            print_success "uv installed"
            (( installed++ ))
        else
            print_error "Failed to install uv"
            (( failed++ ))
        fi
    fi

    # ── Summary ──────────────────────────────────────────────────────────────
    local duration
    duration="$(timer_elapsed)"

    echo ""
    echo "${BOLD}${CYAN} ── Dev Tools Summary ──────────────────────────────────${RESET}"
    echo "${GREEN}   ${CHECKMARK} Installed/configured: ${installed}${RESET}"
    echo "${YELLOW}   ${ARROW} Skipped (already present): ${skipped}${RESET}"
    [[ $failed -gt 0 ]] && echo "${RED}   ${CROSSMARK} Failed: ${failed}${RESET}"
    echo "${DIM}   Total time: ${duration}${RESET}"
    echo ""
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    ensure_sudo
    install_dev_tools
fi

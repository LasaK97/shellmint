#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# =============================================================================
# ml-tools.sh — Machine Learning tools installer
# =============================================================================

# _detect_cuda_version
# Detects installed CUDA version and returns the PyTorch index URL
_detect_cuda_version() {
    local cuda_version=""

    if command_exists nvcc; then
        cuda_version="$(nvcc --version 2>/dev/null | grep -oP 'release \K[0-9]+\.[0-9]+')"
    elif [[ -f /usr/local/cuda/version.txt ]]; then
        cuda_version="$(grep -oP '[0-9]+\.[0-9]+' /usr/local/cuda/version.txt | head -1)"
    elif command_exists nvidia-smi; then
        cuda_version="$(nvidia-smi 2>/dev/null | grep -oP 'CUDA Version: \K[0-9]+\.[0-9]+')"
    fi

    if [[ -z "$cuda_version" ]]; then
        echo "cpu"
        return
    fi

    local major
    major="$(echo "$cuda_version" | cut -d. -f1)"
    local minor
    minor="$(echo "$cuda_version" | cut -d. -f2)"

    print_info "Detected CUDA version: ${cuda_version}"

    # Map to PyTorch CUDA index
    if [[ "$major" -ge 12 ]] && [[ "$minor" -ge 4 ]]; then
        echo "cu124"
    elif [[ "$major" -ge 12 ]] && [[ "$minor" -ge 1 ]]; then
        echo "cu121"
    elif [[ "$major" -ge 11 ]] && [[ "$minor" -ge 8 ]]; then
        echo "cu118"
    else
        print_warning "CUDA $cuda_version may not be supported by latest PyTorch — defaulting to cu121"
        echo "cu121"
    fi
}

install_ml_tools() {
    print_header "Machine Learning Tools"
    timer_start

    local installed=0
    local skipped=0
    local failed=0

    # ── CUDA detection ───────────────────────────────────────────────────────
    print_step "Detecting CUDA installation"
    local cuda_tag
    cuda_tag="$(_detect_cuda_version)"

    if [[ "$cuda_tag" == "cpu" ]]; then
        print_warning "No CUDA installation detected — PyTorch will be CPU-only"
        print_info "If you have a GPU, install CUDA toolkit first for GPU acceleration"
    else
        print_success "Will use PyTorch index: ${cuda_tag}"
    fi

    # ── Miniconda ────────────────────────────────────────────────────────────
    print_step "Installing Miniconda"
    if [[ -d "$HOME/miniconda3" ]] && command_exists conda; then
        print_info "Miniconda is already installed"
        (( skipped++ ))
    else
        (
            local tmp_installer
            tmp_installer="$(mktemp /tmp/miniconda_XXXXXX.sh)"
            curl -fsSL "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(get_arch).sh" -o "$tmp_installer"
            bash "$tmp_installer" -b -p "$HOME/miniconda3"
            rm -f "$tmp_installer"
        ) &>/dev/null &
        if spinner $! "Downloading and installing Miniconda" 300; then
            print_success "Miniconda installed to ~/miniconda3"
            (( installed++ ))
        else
            print_error "Failed to install Miniconda"
            register_failure "Miniconda" "https://docs.anaconda.com/miniconda/install/"
            (( failed++ ))
        fi
    fi

    # Ensure conda is available for the rest of this script
    if [[ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]]; then
        # shellcheck disable=SC1091
        source "$HOME/miniconda3/etc/profile.d/conda.sh"
    elif [[ -f "$HOME/miniconda3/bin/conda" ]]; then
        export PATH="$HOME/miniconda3/bin:$PATH"
    fi

    if ! command_exists conda; then
        print_error "Conda not available — skipping conda environment setup"
        register_failure "Conda ML env" "conda create -n ml python=3.10"
        (( failed++ ))
    else
        # Accept Anaconda channel TOS (required since conda 26.x)
        "$HOME/miniconda3/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main &>/dev/null || true
        "$HOME/miniconda3/bin/conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r &>/dev/null || true

        # ── Create ml conda environment ──────────────────────────────────────
        print_step "Creating 'ml' conda environment (Python 3.10)"
        if conda env list 2>/dev/null | grep -qw "ml"; then
            print_info "Conda 'ml' environment already exists"
            (( skipped++ ))
        else
            "$HOME/miniconda3/bin/conda" create -n ml python=3.10 -y &>/dev/null &
            if spinner $! "Creating conda env 'ml' with Python 3.10"; then
                print_success "Conda 'ml' environment created"
                (( installed++ ))
            else
                print_error "Failed to create conda 'ml' environment"
                register_failure "Conda ML env" "conda create -n ml python=3.10 -y"
                (( failed++ ))
            fi
        fi

        # ── Install PyTorch ──────────────────────────────────────────────────
        print_step "Installing PyTorch"
        local ml_pip="$HOME/miniconda3/envs/ml/bin/pip"
        (
            if [[ "$cuda_tag" == "cpu" ]]; then
                "$ml_pip" install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
            else
                "$ml_pip" install torch torchvision torchaudio --index-url "https://download.pytorch.org/whl/${cuda_tag}"
            fi
        ) &>/dev/null &
        if spinner $! "Installing PyTorch (${cuda_tag})" 600; then
            print_success "PyTorch installed"
            (( installed++ ))
        else
            print_error "Failed to install PyTorch"
            register_failure "PyTorch" "pip install torch torchvision torchaudio"
            (( failed++ ))
        fi

        # ── Install JupyterLab ───────────────────────────────────────────────
        print_step "Installing JupyterLab"
        (
            "$ml_pip" install jupyterlab
        ) &>/dev/null &
        if spinner $! "Installing JupyterLab"; then
            print_success "JupyterLab installed"
            (( installed++ ))
        else
            print_error "Failed to install JupyterLab"
            register_failure "JupyterLab" "pip install jupyterlab"
            (( failed++ ))
        fi
    fi

    # ── Ollama ───────────────────────────────────────────────────────────────
    print_step "Installing Ollama"
    if command_exists ollama; then
        print_info "Ollama is already installed"
        (( skipped++ ))
    else
        # The ollama install script may exit non-zero if systemd is unavailable
        # (e.g. Docker), but the binary still gets installed successfully.
        (curl -fsSL https://ollama.com/install.sh | sh) &>/dev/null &
        spinner $! "Installing Ollama"
        if command_exists ollama || [[ -f /usr/local/bin/ollama ]]; then
            print_success "Ollama installed"
            (( installed++ ))
            # Note: without systemd, ollama won't auto-start as a service
            if ! pidof systemd &>/dev/null; then
                print_info "No systemd detected — run 'ollama serve' manually to start"
            fi
        else
            print_error "Failed to install Ollama"
            register_failure "Ollama" "curl -fsSL https://ollama.com/install.sh | sh"
            (( failed++ ))
        fi
    fi

    # ── nvitop standalone ────────────────────────────────────────────────────
    print_step "Installing nvitop (standalone)"
    if command_exists nvitop; then
        print_info "nvitop standalone is already available"
        (( skipped++ ))
    else
        if command_exists uv; then
            uv tool install nvitop &>/dev/null &
            if spinner $! "Installing nvitop via uv"; then
                print_success "nvitop installed (standalone via uv)"
                (( installed++ ))
            else
                print_error "Failed to install nvitop via uv"
                register_failure "nvitop (standalone)" "uv tool install nvitop  OR  pipx install nvitop"
                (( failed++ ))
            fi
        elif command_exists pipx; then
            pipx install nvitop &>/dev/null &
            if spinner $! "Installing nvitop via pipx"; then
                print_success "nvitop installed (standalone via pipx)"
                (( installed++ ))
            else
                print_error "Failed to install nvitop via pipx"
                register_failure "nvitop (standalone)" "pipx install nvitop"
                (( failed++ ))
            fi
        else
            print_warning "Neither uv nor pipx available — skipping standalone nvitop"
            (( skipped++ ))
        fi
    fi

    # ── Summary ──────────────────────────────────────────────────────────────
    local duration
    duration="$(timer_elapsed)"

    echo ""
    echo "${BOLD}${CYAN} ── ML Tools Summary ──────────────────────────────────${RESET}"
    echo "${GREEN}   ${CHECKMARK} Installed: ${installed}${RESET}"
    echo "${YELLOW}   ${ARROW} Skipped (already present): ${skipped}${RESET}"
    [[ $failed -gt 0 ]] && echo "${RED}   ${CROSSMARK} Failed: ${failed}${RESET}"
    echo "${DIM}   CUDA: ${cuda_tag}${RESET}"
    echo "${DIM}   Total time: ${duration}${RESET}"
    echo ""
    print_info "Activate the ML environment with: conda activate ml"
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    ensure_sudo
    install_ml_tools
fi

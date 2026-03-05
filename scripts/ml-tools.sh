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
            curl -fsSL "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" -o "$tmp_installer"
            bash "$tmp_installer" -b -p "$HOME/miniconda3"
            rm -f "$tmp_installer"
        ) &>/dev/null &
        if spinner $! "Downloading and installing Miniconda"; then
            print_success "Miniconda installed to ~/miniconda3"
            (( installed++ ))
        else
            print_error "Failed to install Miniconda"
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
        (( failed++ ))
    else
        # ── Create ml conda environment ──────────────────────────────────────
        print_step "Creating 'ml' conda environment (Python 3.10)"
        if conda env list 2>/dev/null | grep -qw "ml"; then
            print_info "Conda 'ml' environment already exists"
            (( skipped++ ))
        else
            conda create -n ml python=3.10 -y &>/dev/null &
            if spinner $! "Creating conda env 'ml' with Python 3.10"; then
                print_success "Conda 'ml' environment created"
                (( installed++ ))
            else
                print_error "Failed to create conda 'ml' environment"
                (( failed++ ))
            fi
        fi

        # ── Install PyTorch ──────────────────────────────────────────────────
        print_step "Installing PyTorch"
        (
            conda activate ml 2>/dev/null || source activate ml 2>/dev/null
            if [[ "$cuda_tag" == "cpu" ]]; then
                pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
            else
                pip install torch torchvision torchaudio --index-url "https://download.pytorch.org/whl/${cuda_tag}"
            fi
        ) &>/dev/null &
        if spinner $! "Installing PyTorch (${cuda_tag})"; then
            print_success "PyTorch installed"
            (( installed++ ))
        else
            print_error "Failed to install PyTorch"
            (( failed++ ))
        fi

        # ── Install HuggingFace stack ────────────────────────────────────────
        print_step "Installing HuggingFace ecosystem"
        (
            conda activate ml 2>/dev/null || source activate ml 2>/dev/null
            pip install transformers tokenizers datasets safetensors accelerate
        ) &>/dev/null &
        if spinner $! "Installing transformers, tokenizers, datasets, safetensors, accelerate"; then
            print_success "HuggingFace stack installed"
            (( installed++ ))
        else
            print_error "Failed to install HuggingFace stack"
            (( failed++ ))
        fi

        # ── Install fine-tuning tools ────────────────────────────────────────
        print_step "Installing fine-tuning tools"
        (
            conda activate ml 2>/dev/null || source activate ml 2>/dev/null
            pip install bitsandbytes peft trl
        ) &>/dev/null &
        if spinner $! "Installing bitsandbytes, peft, trl"; then
            print_success "Fine-tuning tools installed"
            (( installed++ ))
        else
            print_error "Failed to install fine-tuning tools"
            (( failed++ ))
        fi

        # ── Install flash-attn ───────────────────────────────────────────────
        print_step "Installing flash-attn"
        if [[ "$cuda_tag" == "cpu" ]]; then
            print_warning "Skipping flash-attn — requires CUDA"
            (( skipped++ ))
        else
            (
                conda activate ml 2>/dev/null || source activate ml 2>/dev/null
                pip install flash-attn --no-build-isolation
            ) &>/dev/null &
            if spinner $! "Installing flash-attn (compilation may take several minutes)"; then
                print_success "flash-attn installed"
                (( installed++ ))
            else
                print_error "Failed to install flash-attn (may need matching CUDA toolkit)"
                (( failed++ ))
            fi
        fi

        # ── Install data science packages ────────────────────────────────────
        print_step "Installing data science packages"
        (
            conda activate ml 2>/dev/null || source activate ml 2>/dev/null
            pip install scikit-learn pandas numpy matplotlib
        ) &>/dev/null &
        if spinner $! "Installing scikit-learn, pandas, numpy, matplotlib"; then
            print_success "Data science packages installed"
            (( installed++ ))
        else
            print_error "Failed to install data science packages"
            (( failed++ ))
        fi

        # ── Install JupyterLab ───────────────────────────────────────────────
        print_step "Installing JupyterLab"
        (
            conda activate ml 2>/dev/null || source activate ml 2>/dev/null
            pip install jupyterlab
        ) &>/dev/null &
        if spinner $! "Installing JupyterLab"; then
            print_success "JupyterLab installed"
            (( installed++ ))
        else
            print_error "Failed to install JupyterLab"
            (( failed++ ))
        fi

        # ── Install TensorBoard ──────────────────────────────────────────────
        print_step "Installing TensorBoard"
        (
            conda activate ml 2>/dev/null || source activate ml 2>/dev/null
            pip install tensorboard
        ) &>/dev/null &
        if spinner $! "Installing TensorBoard"; then
            print_success "TensorBoard installed"
            (( installed++ ))
        else
            print_error "Failed to install TensorBoard"
            (( failed++ ))
        fi

        # ── Install nvitop (in conda env) ────────────────────────────────────
        print_step "Installing nvitop"
        (
            conda activate ml 2>/dev/null || source activate ml 2>/dev/null
            pip install nvitop
        ) &>/dev/null &
        if spinner $! "Installing nvitop"; then
            print_success "nvitop installed"
            (( installed++ ))
        else
            print_error "Failed to install nvitop"
            (( failed++ ))
        fi

        # ── Install ONNX ────────────────────────────────────────────────────
        print_step "Installing ONNX Runtime"
        (
            conda activate ml 2>/dev/null || source activate ml 2>/dev/null
            pip install onnx onnxruntime-gpu
        ) &>/dev/null &
        if spinner $! "Installing onnx, onnxruntime-gpu"; then
            print_success "ONNX Runtime installed"
            (( installed++ ))
        else
            print_error "Failed to install ONNX Runtime"
            (( failed++ ))
        fi

        # ── Install sentence-transformers ────────────────────────────────────
        print_step "Installing sentence-transformers"
        (
            conda activate ml 2>/dev/null || source activate ml 2>/dev/null
            pip install sentence-transformers
        ) &>/dev/null &
        if spinner $! "Installing sentence-transformers"; then
            print_success "sentence-transformers installed"
            (( installed++ ))
        else
            print_error "Failed to install sentence-transformers"
            (( failed++ ))
        fi
    fi

    # ── Ollama ───────────────────────────────────────────────────────────────
    print_step "Installing Ollama"
    if command_exists ollama; then
        print_info "Ollama is already installed"
        (( skipped++ ))
    else
        curl -fsSL https://ollama.com/install.sh | sh &>/dev/null &
        if spinner $! "Installing Ollama"; then
            print_success "Ollama installed"
            (( installed++ ))
        else
            print_error "Failed to install Ollama"
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
                (( failed++ ))
            fi
        elif command_exists pipx; then
            pipx install nvitop &>/dev/null &
            if spinner $! "Installing nvitop via pipx"; then
                print_success "nvitop installed (standalone via pipx)"
                (( installed++ ))
            else
                print_error "Failed to install nvitop via pipx"
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

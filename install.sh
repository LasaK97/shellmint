#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# ShellMint — Modern Terminal Setup for Developers & ML Engineers
# A beautiful interactive terminal setup installer for Ubuntu/Debian
# by Lasantha Kulasooriya
# ============================================================================

# --- Resolve installer directory and source utilities -----------------------
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELLMINT_VERSION="$(cat "$INSTALLER_DIR/VERSION" 2>/dev/null || echo "dev")"
source "$INSTALLER_DIR/scripts/utils.sh"

# --- Global flags (set by CLI argument parsing, exported for child scripts) --
export DRY_RUN=0
export NON_INTERACTIVE=0
export VERBOSE=0
PRE_SELECTED_CATEGORIES=""
SKIP_CATEGORIES=""
export CONFIGS_ONLY=0
export UPDATE_MODE=0

# --- Usage / Help -----------------------------------------------------------
show_help() {
    cat <<EOF
ShellMint v${SHELLMINT_VERSION} — Modern Terminal Setup for Developers & ML Engineers

Usage: ./install.sh [OPTIONS]

Options:
  --help                Show this help message and exit
  --version             Print version and exit
  --dry-run             Show what would be installed without making changes
  --yes                 Non-interactive mode, install all components
  --categories 1,3,5    Pre-select specific categories (comma-separated)
  --skip 2,6            Keep all categories selected except the specified ones
  --configs-only        Only apply configuration files (skip tool installation)
  --update              Re-run to update tools to their latest versions
  --verbose             Show detailed output during installation

Categories:
  1  Shell Setup        Zsh, Oh My Zsh, plugins, Oh My Posh, Atuin
  2  Terminal Emulator  Kitty terminal, Hack Nerd Font, config
  3  Modern CLI Tools   eza, bat, fd, ripgrep, fzf, zoxide, lazygit, etc.
  4  Development Tools  Docker, Rust, Go, Node.js, Java, Git config
  5  Editor             Neovim + LazyVim with Catppuccin theme
  6  ML/AI Stack        Miniconda, PyTorch+CUDA, JupyterLab, Ollama, nvitop

Examples:
  ./install.sh                      Interactive installer (default)
  ./install.sh --yes                Install everything non-interactively
  ./install.sh --categories 1,3,5  Install only Shell, CLI Tools, and Editor
  ./install.sh --skip 6             Install everything except ML/AI Stack
  ./install.sh --dry-run            Preview what would be installed
  ./install.sh --update             Update all tools to latest versions
  ./install.sh --configs-only       Re-apply config files only

For more info: https://github.com/LasaK97/shellmint
EOF
    exit 0
}

show_version() {
    echo "ShellMint v${SHELLMINT_VERSION}"
    exit 0
}

# --- Parse CLI arguments ----------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                ;;
            --version|-v)
                show_version
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --yes|-y)
                NON_INTERACTIVE=1
                shift
                ;;
            --categories)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --categories requires a value (e.g., --categories 1,3,5)"
                    exit 1
                fi
                PRE_SELECTED_CATEGORIES="$2"
                shift 2
                ;;
            --skip)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --skip requires a value (e.g., --skip 2,6)"
                    exit 1
                fi
                SKIP_CATEGORIES="$2"
                shift 2
                ;;
            --configs-only)
                CONFIGS_ONLY=1
                shift
                ;;
            --update)
                UPDATE_MODE=1
                shift
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Run './install.sh --help' for usage."
                exit 1
                ;;
        esac
    done
}

# --- Log file setup ---------------------------------------------------------
LOG_FILE="$HOME/.shellmint-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo ""
echo "=== ShellMint v${SHELLMINT_VERSION} installer started at $(date) ===" >> "$LOG_FILE"

# --- Signal handlers --------------------------------------------------------
handle_interrupt() {
    echo ""
    # Kill any background process the spinner is tracking (and its children)
    if [[ -n "${_SPINNER_BG_PID:-}" ]]; then
        # Kill the process tree: first try process group, then direct kill
        pkill -P "$_SPINNER_BG_PID" 2>/dev/null || true
        kill "$_SPINNER_BG_PID" 2>/dev/null || true
        wait "$_SPINNER_BG_PID" 2>/dev/null || true
        _SPINNER_BG_PID=""
    fi
    # Restore terminal state
    tput cnorm 2>/dev/null || true    # Show cursor
    reset_scroll_region 2>/dev/null   # Reset scroll region
    echo ""
    print_colored "$YELLOW" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$YELLOW" "  ║              Installation cancelled by user (Ctrl+C)         ║"
    print_colored "$YELLOW" "  ╠══════════════════════════════════════════════════════════════╣"
    print_colored "$YELLOW" "  ║                                                              ║"
    print_colored "$YELLOW" "  ║  Partial installation may have occurred.                     ║"
    print_colored "$YELLOW" "  ║  Run ./install.sh again to resume (safe — idempotent).       ║"
    print_colored "$YELLOW" "  ║  Run ./uninstall.sh to revert changes.                       ║"
    print_colored "$YELLOW" "  ║                                                              ║"
    _box_line "$YELLOW" "  Log: ${LOG_FILE}"
    print_colored "$YELLOW" "  ║                                                              ║"
    print_colored "$YELLOW" "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
    exit 130
}
trap handle_interrupt SIGINT SIGTERM

# --- Error trap --------------------------------------------------------------
trap_error() {
    local exit_code=$?
    local line_number=$1
    reset_scroll_region 2>/dev/null
    tput cnorm 2>/dev/null || true
    echo ""
    print_colored "$RED" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$RED" "  ║                      ERROR OCCURRED                          ║"
    print_colored "$RED" "  ╠══════════════════════════════════════════════════════════════╣"
    print_colored "$RED" "  ║                                                              ║"
    _box_line "$RED" "  An error occurred on line ${line_number} (exit code ${exit_code})"
    _box_line "$RED" ""
    _box_line "$RED" "  Check the log file for details:"
    _box_line "$RED" "  ${LOG_FILE}"
    print_colored "$RED" "  ║                                                              ║"
    print_colored "$RED" "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
}
trap 'trap_error ${LINENO}' ERR

# === CATEGORY DEFINITIONS ====================================================
# Category IDs, names, descriptions, scripts, install functions, and est times

CATEGORY_IDS=(1 2 3 4 5 6)

CATEGORY_NAMES=(
    "Shell Setup"
    "Terminal Emulator"
    "Modern CLI Tools"
    "Development Tools"
    "Editor"
    "ML/AI Stack"
)

CATEGORY_ICONS=(
    "🐚"
    "🖥️ "
    "🛠️ "
    "💻"
    "✏️ "
    "🧠"
)

CATEGORY_DESCRIPTIONS=(
    "Zsh, Oh My Zsh, plugins, Oh My Posh, Atuin"
    "Kitty terminal, Hack Nerd Font, config"
    "eza, bat, fd, ripgrep, fzf, zoxide, lazygit, btop, yazi, glow, dust, delta, zellij, direnv"
    "Docker, Rust, Go, Node.js, Java, Git config"
    "Neovim + LazyVim with Catppuccin theme"
    "Miniconda, PyTorch+CUDA, JupyterLab, Ollama, nvitop"
)

CATEGORY_SCRIPTS=(
    "shell.sh"
    "terminal.sh"
    "cli-tools.sh"
    "dev-tools.sh"
    "editor.sh"
    "ml-tools.sh"
)

CATEGORY_INSTALL_FNS=(
    "install_shell"
    "install_terminal"
    "install_cli_tools"
    "install_dev_tools"
    "install_editor"
    "install_ml_tools"
)

CATEGORY_EST_TIMES=(
    "1-2 min"
    "1 min"
    "2-3 min"
    "3-5 min"
    "1 min"
    "5-10 min"
)

CATEGORY_EST_SECONDS=(45 30 135 180 12 300)

# Selection state: 1 = selected, 0 = not selected (default: all selected)
CATEGORY_SELECTED=(1 1 1 1 1 1)

# Installation result tracking
declare -A INSTALL_RESULTS
declare -A INSTALL_TIMES

# === PREREQUISITE CHECKS =====================================================

check_prerequisites() {
    local failed=0

    # Must not be root
    if [[ $EUID -eq 0 ]]; then
        print_colored "$RED" "  ✗ Do not run this script as root. It will use sudo when needed."
        failed=1
    fi

    # Must be Ubuntu/Debian
    if ! is_ubuntu_debian; then
        print_colored "$RED" "  ✗ This installer requires Ubuntu or Debian."
        failed=1
    fi

    if [[ $failed -eq 1 ]]; then
        echo ""
        print_colored "$RED" "  Prerequisites check failed. Exiting."
        exit 1
    fi

    # Install curl and git first if missing (needed for connectivity check and downloads)
    local bootstrap_pkgs=()
    command -v curl &>/dev/null || bootstrap_pkgs+=(curl)
    command -v git  &>/dev/null || bootstrap_pkgs+=(git)
    if [[ ${#bootstrap_pkgs[@]} -gt 0 ]]; then
        (
            sudo apt-get update -qq > /dev/null 2>&1
            sudo apt-get install -y -qq "${bootstrap_pkgs[@]}" > /dev/null 2>&1
        ) &
        spinner $! "Installing bootstrap packages (${bootstrap_pkgs[*]})"
    fi

    # Check internet connectivity
    if ! curl -sS --max-time 5 -o /dev/null https://github.com 2>/dev/null; then
        print_colored "$RED" "  ✗ No internet connection detected."
        print_colored "$RED" "    ShellMint requires internet to download packages and tools."
        print_colored "$RED" "    Check your connection and try again."
        echo ""
        exit 1
    fi
    print_colored "$GREEN" "  ✓ Internet connectivity OK"

    # Essential packages needed by various installer scripts
    local required_pkgs=(
        git curl wget unzip tar gzip
        ca-certificates gnupg lsb-release
        fontconfig          # fc-cache for font install
        build-essential     # compiling flash-attn, native extensions
        software-properties-common
        python3-pip
    )

    local missing_pkgs=()
    for pkg in "${required_pkgs[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            missing_pkgs+=("$pkg")
        fi
    done

    if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
        print_colored "$DIM" "  Packages: ${missing_pkgs[*]}"
        (
            sudo apt-get update -qq > /dev/null 2>&1
            sudo apt-get install -y -qq "${missing_pkgs[@]}" > /dev/null 2>&1
        ) &
        if spinner $! "Installing prerequisites (${#missing_pkgs[@]} packages)"; then
            print_success "Prerequisites installed"
        else
            print_error "Some prerequisites failed to install — continuing anyway"
        fi
    else
        print_colored "$GREEN" "  ✓ All prerequisites already present."
    fi
    echo ""
}

# === SYSTEM INFO PANEL =======================================================

show_system_info() {
    local os_version kernel cpu ram gpu disk

    os_version=$(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo "Unknown")
    kernel=$(uname -r)
    cpu=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d':' -f2 | xargs || echo "Unknown")
    ram=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo "Unknown")
    disk=$(df -h / 2>/dev/null | awk 'NR==2{printf "%s / %s (%s used)", $3, $2, $5}' || echo "Unknown")

    if command_exists nvidia-smi; then
        gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "N/A")
    else
        gpu=""
    fi

    echo ""
    print_colored "$CYAN" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$CYAN" "  ║                      System Information                      ║"
    print_colored "$CYAN" "  ╠══════════════════════════════════════════════════════════════╣"
    print_colored "$CYAN" "  ║                                                              ║"
    _box_line "$CYAN" "  ${BOLD}OS:${RESET}     ${os_version}"
    _box_line "$CYAN" "  ${BOLD}Kernel:${RESET} ${kernel}"
    _box_line "$CYAN" "  ${BOLD}Arch:${RESET}   $(get_arch) ($(get_deb_arch))"
    _box_line "$CYAN" "  ${BOLD}CPU:${RESET}    ${cpu:0:52}"
    _box_line "$CYAN" "  ${BOLD}RAM:${RESET}    ${ram}"
    if [[ -n "$gpu" ]]; then
        _box_line "$CYAN" "  ${BOLD}GPU:${RESET}    ${gpu:0:52}"
    fi
    _box_line "$CYAN" "  ${BOLD}Disk:${RESET}   ${disk}"
    print_colored "$CYAN" "  ║                                                              ║"
    print_colored "$CYAN" "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# === INTERACTIVE CATEGORY SELECTION MENU =====================================

draw_menu() {
    # Clear screen area for redraw
    echo ""
    print_colored "$MAGENTA" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$MAGENTA" "  ║                      Select Components                       ║"
    print_colored "$MAGENTA" "  ╠══════════════════════════════════════════════════════════════╣"

    for i in "${!CATEGORY_IDS[@]}"; do
        local id="${CATEGORY_IDS[$i]}"
        local name="${CATEGORY_NAMES[$i]}"
        local icon="${CATEGORY_ICONS[$i]}"
        local desc="${CATEGORY_DESCRIPTIONS[$i]}"
        local selected="${CATEGORY_SELECTED[$i]}"

        local checkbox
        if [[ $selected -eq 1 ]]; then
            checkbox="${GREEN}[✓]${RESET}"
        else
            checkbox="${DIM}[ ]${RESET}"
        fi

        _box_line "$MAGENTA" ""
        _box_line "$MAGENTA" "  ${checkbox} ${BOLD}[${id}]${RESET} ${icon}  ${BOLD}${name}${RESET}"

        # Handle multi-line descriptions (split on comma groups)
        local line_len=0
        local line=""
        local first=1
        IFS=',' read -ra desc_parts <<< "$desc"
        for part in "${desc_parts[@]}"; do
            part=$(echo "$part" | xargs) # trim
            if [[ $first -eq 1 ]]; then
                line="$part"
                line_len=${#part}
                first=0
            elif (( line_len + ${#part} + 2 > 52 )); then
                _box_line "$MAGENTA" "      ${DIM}${line},${RESET}"
                line="$part"
                line_len=${#part}
            else
                line="$line, $part"
                line_len=$(( line_len + ${#part} + 2 ))
            fi
        done
        if [[ -n "$line" ]]; then
            _box_line "$MAGENTA" "      ${DIM}${line}${RESET}"
        fi
    done

    _box_line "$MAGENTA" ""
    print_colored "$MAGENTA" "  ╠══════════════════════════════════════════════════════════════╣"
    _box_line "$MAGENTA" "  ${BOLD}[A]${RESET} Select All    ${BOLD}[N]${RESET} Select None    ${BOLD}[Enter]${RESET} Confirm"
    print_colored "$MAGENTA" "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

check_dependencies() {
    local warnings=()

    # CLI Tools (3, index 2) recommends Shell Setup (1, index 0)
    if [[ ${CATEGORY_SELECTED[2]} -eq 1 && ${CATEGORY_SELECTED[0]} -eq 0 ]]; then
        warnings+=("  ⚠  CLI Tools works best with Shell Setup (Zsh). Consider enabling it.")
    fi

    # Editor (5, index 4) recommends CLI Tools (3, index 2)
    if [[ ${CATEGORY_SELECTED[4]} -eq 1 && ${CATEGORY_SELECTED[2]} -eq 0 ]]; then
        warnings+=("  ⚠  Editor benefits from CLI Tools (ripgrep, fd, etc). Consider enabling them.")
    fi

    # ML Stack (6, index 5) recommends Dev Tools (4, index 3)
    if [[ ${CATEGORY_SELECTED[5]} -eq 1 && ${CATEGORY_SELECTED[3]} -eq 0 ]]; then
        warnings+=("  ⚠  ML/AI Stack works best with Development Tools. Consider enabling them.")
    fi

    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo ""
        for w in "${warnings[@]}"; do
            print_colored "$YELLOW" "$w"
        done
        echo ""
    fi
}

interactive_menu() {
    while true; do
        print_banner
        draw_menu

        printf "  ${BOLD}Toggle categories (e.g. 1 3 5 or 1,3,5), A=all, N=none, Enter=confirm:${RESET} "
        read -r input

        # Confirm on empty input
        if [[ -z "$input" ]]; then
            # Check if at least one selected
            local any_selected=0
            for sel in "${CATEGORY_SELECTED[@]}"; do
                if [[ $sel -eq 1 ]]; then
                    any_selected=1
                    break
                fi
            done

            if [[ $any_selected -eq 0 ]]; then
                print_colored "$YELLOW" "  Please select at least one component, or press Ctrl+C to exit."
                sleep 2
                continue
            fi

            # Check dependency warnings
            check_dependencies
            local has_warnings=0
            if [[ ${CATEGORY_SELECTED[2]} -eq 1 && ${CATEGORY_SELECTED[0]} -eq 0 ]] ||
               [[ ${CATEGORY_SELECTED[4]} -eq 1 && ${CATEGORY_SELECTED[2]} -eq 0 ]] ||
               [[ ${CATEGORY_SELECTED[5]} -eq 1 && ${CATEGORY_SELECTED[3]} -eq 0 ]]; then
                has_warnings=1
            fi

            if [[ $has_warnings -eq 1 ]]; then
                printf "  ${YELLOW}Continue anyway? [Y/n]:${RESET} "
                read -r confirm
                if [[ "$confirm" =~ ^[Nn] ]]; then
                    continue
                fi
            fi

            break
        fi

        # Select All
        if [[ "$input" =~ ^[Aa]$ ]]; then
            for i in "${!CATEGORY_SELECTED[@]}"; do
                CATEGORY_SELECTED[$i]=1
            done
            continue
        fi

        # Select None
        if [[ "$input" =~ ^[Nn]$ ]]; then
            for i in "${!CATEGORY_SELECTED[@]}"; do
                CATEGORY_SELECTED[$i]=0
            done
            continue
        fi

        # Parse numbers (space or comma separated)
        local nums
        nums=$(echo "$input" | tr ',' ' ')
        for num in $nums; do
            if [[ "$num" =~ ^[1-6]$ ]]; then
                local idx=$((num - 1))
                if [[ ${CATEGORY_SELECTED[$idx]} -eq 1 ]]; then
                    CATEGORY_SELECTED[$idx]=0
                else
                    CATEGORY_SELECTED[$idx]=1
                fi
            fi
        done
    done
}

# === CONFIRMATION SCREEN =====================================================

show_confirmation() {
    local total_est=0
    echo ""
    print_colored "$CYAN" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$CYAN" "  ║                   Installation Summary                       ║"
    print_colored "$CYAN" "  ╠══════════════════════════════════════════════════════════════╣"
    print_colored "$CYAN" "  ║                                                              ║"

    for i in "${!CATEGORY_IDS[@]}"; do
        local name="${CATEGORY_NAMES[$i]}"
        local est="${CATEGORY_EST_TIMES[$i]}"
        if [[ ${CATEGORY_SELECTED[$i]} -eq 1 ]]; then
            _box_line "$CYAN" "  ${GREEN}✓${RESET} ${name}$(printf '%*s' $((30 - ${#name})) '')${DIM}~${est}${RESET}"
            total_est=$((total_est + CATEGORY_EST_SECONDS[$i]))
        else
            _box_line "$CYAN" "  ${DIM}✗ ${name}$(printf '%*s' $((30 - ${#name})) '')skipped${RESET}"
        fi
    done

    local est_min=$((total_est / 60))
    local est_sec=$((total_est % 60))
    local est_str
    if [[ $est_min -gt 0 ]]; then
        est_str="${est_min}m ${est_sec}s"
    else
        est_str="${est_sec}s"
    fi

    _box_line "$CYAN" ""
    _box_line "$CYAN" "  ${BOLD}Estimated total time: ~${est_str}${RESET}"
    _box_line "$CYAN" "  ${DIM}(actual time depends on internet speed)${RESET}"
    print_colored "$CYAN" "  ║                                                              ║"
    print_colored "$CYAN" "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""

    printf "  ${BOLD}${YELLOW}Proceed with installation? [Y/n]:${RESET} "
    read -r confirm
    if [[ "$confirm" =~ ^[Nn] ]]; then
        print_colored "$YELLOW" "  Installation cancelled."
        exit 0
    fi
}

# === INSTALLATION PHASE ======================================================

format_time() {
    local seconds=$1
    local min=$((seconds / 60))
    local sec=$((seconds % 60))
    if [[ $min -gt 0 ]]; then
        echo "${min}m ${sec}s"
    else
        echo "${sec}s"
    fi
}

master_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local pct=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    local bar=""
    for ((j = 0; j < filled; j++)); do bar+="█"; done
    for ((j = 0; j < empty; j++)); do bar+="░"; done

    printf "\r  ${BOLD}Overall:${RESET} ${GREEN}%s${RESET} ${BOLD}%3d%%${RESET} [%d/%d]" "$bar" "$pct" "$current" "$total"
}

run_installations() {
    local total_selected=0
    local completed=0

    # Count selected categories
    for sel in "${CATEGORY_SELECTED[@]}"; do
        if [[ $sel -eq 1 ]]; then
            total_selected=$((total_selected + 1))
        fi
    done

    local overall_start=$SECONDS

    echo ""
    print_colored "$BOLD" "  ══════════════════════════════════════════════════════════════"
    print_colored "$BOLD" "                      Starting Installation"
    print_colored "$BOLD" "  ══════════════════════════════════════════════════════════════"
    echo ""

    for i in "${!CATEGORY_IDS[@]}"; do
        local name="${CATEGORY_NAMES[$i]}"
        local icon="${CATEGORY_ICONS[$i]}"
        local script="${CATEGORY_SCRIPTS[$i]}"
        local install_fn="${CATEGORY_INSTALL_FNS[$i]}"

        if [[ ${CATEGORY_SELECTED[$i]} -eq 0 ]]; then
            INSTALL_RESULTS[$i]="skipped"
            INSTALL_TIMES[$i]=0
            continue
        fi

        echo ""
        print_colored "$CYAN" "  ┌──────────────────────────────────────────────────────────────┐"
        printf "  ${CYAN}│${RESET} %s ${BOLD}Installing: %s${RESET}%-*s${CYAN} │${RESET}\n" \
            "$icon" "$name" $((45 - ${#name})) ""
        print_colored "$CYAN" "  └──────────────────────────────────────────────────────────────┘"
        echo ""

        local cat_start=$SECONDS
        local script_path="$INSTALLER_DIR/scripts/$script"

        if [[ ! -f "$script_path" ]]; then
            print_colored "$RED" "  ✗ Script not found: $script_path"
            INSTALL_RESULTS[$i]="failed"
            INSTALL_TIMES[$i]=0
            completed=$((completed + 1))
            master_progress_bar "$completed" "$total_selected"
            continue
        fi

        # Source the script and run install function, catching errors
        if (
            source "$script_path"
            if declare -f "$install_fn" > /dev/null 2>&1; then
                "$install_fn"
            else
                echo "  ✗ Function $install_fn not found in $script"
                exit 1
            fi
        ); then
            local cat_elapsed=$((SECONDS - cat_start))
            INSTALL_RESULTS[$i]="success"
            INSTALL_TIMES[$i]=$cat_elapsed
            print_colored "$GREEN" "  ✓ $name completed in $(format_time $cat_elapsed)"
        else
            local cat_elapsed=$((SECONDS - cat_start))
            INSTALL_RESULTS[$i]="failed"
            INSTALL_TIMES[$i]=$cat_elapsed
            print_colored "$RED" "  ✗ $name failed after $(format_time $cat_elapsed)"
            print_colored "$YELLOW" "  Continuing with remaining components..."
        fi

        completed=$((completed + 1))
        echo ""
        master_progress_bar "$completed" "$total_selected"
        echo ""
    done

    local overall_elapsed=$((SECONDS - overall_start))

    # Reset scroll region so summary shows full screen
    reset_scroll_region
    clear
    echo ""

    # === SUMMARY SCREEN ======================================================
    show_summary "$overall_elapsed"
}

# === SUMMARY SCREEN ==========================================================

show_summary() {
    local total_time=$1

    echo ""
    print_colored "$GREEN" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$GREEN" "  ║                   Installation Complete! 🎉                  ║"
    print_colored "$GREEN" "  ╠══════════════════════════════════════════════════════════════╣"
    print_colored "$GREEN" "  ║                                                              ║"

    for i in "${!CATEGORY_IDS[@]}"; do
        local name="${CATEGORY_NAMES[$i]}"
        local result="${INSTALL_RESULTS[$i]:-skipped}"
        local elapsed="${INSTALL_TIMES[$i]:-0}"

        if [[ "$result" == "success" ]]; then
            local time_str
            time_str="installed in $(format_time $elapsed)"
            _box_line "$GREEN" "  ${GREEN}✓${RESET} ${name}$(printf '%*s' $((24 - ${#name})) '')${DIM}${time_str}${RESET}"
        elif [[ "$result" == "failed" ]]; then
            _box_line "$GREEN" "  ${RED}✗${RESET} ${name}$(printf '%*s' $((24 - ${#name})) '')${RED}failed${RESET}"
        else
            _box_line "$GREEN" "  ${DIM}✗ ${name}$(printf '%*s' $((24 - ${#name})) '')skipped${RESET}"
        fi
    done

    _box_line "$GREEN" ""
    _box_line "$GREEN" "  ${BOLD}Total time: $(format_time $total_time)${RESET}"
    _box_line "$GREEN" ""

    # Show restart notice if shell was installed
    if [[ "${INSTALL_RESULTS[0]:-skipped}" == "success" ]]; then
        _box_line "$GREEN" "  ${YELLOW}⚠ Please restart your terminal or run: exec zsh${RESET}"
        _box_line "$GREEN" ""
    fi

    _box_line "$GREEN" "  To change your prompt theme later, run:"
    _box_line "$GREEN" "  ${BOLD}./scripts/theme.sh${RESET}"
    _box_line "$GREEN" ""
    print_colored "$GREEN" "  ╠══════════════════════════════════════════════════════════════╣"
    _box_line "$GREEN" "  ${BOLD}by Lasantha Kulasooriya${RESET}"
    _box_line "$GREEN" "  🔗 linkedin.com/in/lasantha-kulasooriya"
    _box_line "$GREEN" "  ☕ buymeacoffee.com/lasak97"
    print_colored "$GREEN" "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""

    # Show keybinding cheatsheet
    show_keybindings
}

# === KEYBINDING CHEATSHEET ====================================================

show_keybindings() {
    echo ""
    print_colored "$CYAN" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$CYAN" "  ║                     Keybinding Cheatsheet                    ║"
    print_colored "$CYAN" "  ╠══════════════════════════════════════════════════════════════╣"

    # Kitty keybindings (if terminal was installed)
    if [[ "${INSTALL_RESULTS[1]:-skipped}" != "skipped" ]]; then
        _box_line "$CYAN" ""
        _box_line "$CYAN" "  ${BOLD}${MAGENTA}Kitty Terminal${RESET}"
        _box_line "$CYAN" "  ${DIM}Ctrl+Shift+T         New tab${RESET}"
        _box_line "$CYAN" "  ${DIM}Ctrl+Shift+Enter     New window (split)${RESET}"
        _box_line "$CYAN" "  ${DIM}Ctrl+Shift+[ / ]     Previous / Next window${RESET}"
        _box_line "$CYAN" "  ${DIM}Ctrl+Shift+Alt+T     Set tab title${RESET}"
        _box_line "$CYAN" "  ${DIM}Ctrl+Shift+W         Close window${RESET}"
        _box_line "$CYAN" "  ${DIM}Ctrl+Shift+F         Search scrollback${RESET}"
        _box_line "$CYAN" "  ${DIM}Ctrl+Shift+C / V     Copy / Paste${RESET}"
        _box_line "$CYAN" "  ${DIM}Ctrl+Shift+Up/Down   Scroll up / down${RESET}"
        _box_line "$CYAN" "  ${DIM}Ctrl+Shift+Equal/Minus  Font size +/-${RESET}"
    fi

    # Zsh keybindings (if shell was installed)
    if [[ "${INSTALL_RESULTS[0]:-skipped}" != "skipped" ]]; then
        _box_line "$CYAN" ""
        _box_line "$CYAN" "  ${BOLD}${MAGENTA}Zsh Shell${RESET}"
        _box_line "$CYAN" "  ${DIM}Ctrl+R               Search history (Atuin)${RESET}"
        _box_line "$CYAN" "  ${DIM}Ctrl+T               Fuzzy file finder (fzf)${RESET}"
        _box_line "$CYAN" "  ${DIM}Alt+C                Fuzzy cd (fzf)${RESET}"
        _box_line "$CYAN" "  ${DIM}Ctrl+U               Clear line before cursor${RESET}"
        _box_line "$CYAN" "  ${DIM}Ctrl+[5C / Ctrl+[5D  Forward / backward word${RESET}"
        _box_line "$CYAN" "  ${DIM}Up/Down              History substring search${RESET}"
        _box_line "$CYAN" "  ${DIM}Tab                  Completion with fzf-tab${RESET}"
        _box_line "$CYAN" "  ${DIM}ESC ESC              Prefix sudo (plugin)${RESET}"
    fi

    # CLI tool shortcuts (if cli tools were installed)
    if [[ "${INSTALL_RESULTS[2]:-skipped}" != "skipped" ]]; then
        _box_line "$CYAN" ""
        _box_line "$CYAN" "  ${BOLD}${MAGENTA}CLI Tool Aliases${RESET}"
        _box_line "$CYAN" "  ${DIM}ls/ll/la/l           eza (modern ls)${RESET}"
        _box_line "$CYAN" "  ${DIM}tree                 eza --tree${RESET}"
        _box_line "$CYAN" "  ${DIM}z <dir>              zoxide (smart cd)${RESET}"
        _box_line "$CYAN" "  ${DIM}lg                   lazygit${RESET}"
        _box_line "$CYAN" "  ${DIM}top                  btop${RESET}"
        _box_line "$CYAN" "  ${DIM}y                    yazi (file manager, cd on exit)${RESET}"
        _box_line "$CYAN" "  ${DIM}md <file>            glow (markdown preview)${RESET}"
    fi

    # Editor keybindings (if editor was installed)
    if [[ "${INSTALL_RESULTS[4]:-skipped}" != "skipped" ]]; then
        _box_line "$CYAN" ""
        _box_line "$CYAN" "  ${BOLD}${MAGENTA}Neovim (LazyVim)${RESET}"
        _box_line "$CYAN" "  ${DIM}Space                Leader key${RESET}"
        _box_line "$CYAN" "  ${DIM}<leader>ff           Find files${RESET}"
        _box_line "$CYAN" "  ${DIM}<leader>fg           Live grep${RESET}"
        _box_line "$CYAN" "  ${DIM}<leader>e            File explorer${RESET}"
        _box_line "$CYAN" "  ${DIM}<leader>gg           Lazygit${RESET}"
        _box_line "$CYAN" "  ${DIM}<leader>l            Lazy plugin manager${RESET}"
    fi

    _box_line "$CYAN" ""
    print_colored "$CYAN" "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# === POST-INSTALL HEALTH CHECK ================================================

run_health_check() {
    echo ""
    print_colored "$CYAN" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$CYAN" "  ║                   Post-Install Health Check                  ║"
    print_colored "$CYAN" "  ╠══════════════════════════════════════════════════════════════╣"
    print_colored "$CYAN" "  ║                                                              ║"

    local passed=0
    local failed=0

    # Build extended PATH covering all install locations (avoids slow zsh -ic)
    local _hc_path="$HOME/.local/bin:/usr/local/bin:/usr/local/go/bin:$HOME/go/bin:$HOME/.cargo/bin:$HOME/.fzf/bin:$PATH"
    # Add nvm node path
    if [[ -d "$HOME/.nvm/versions/node" ]]; then
        local _nvm_dir
        _nvm_dir=$(ls -d "$HOME/.nvm/versions/node"/v* 2>/dev/null | sort -V | tail -1)
        [[ -n "$_nvm_dir" ]] && _hc_path="$_nvm_dir/bin:$_hc_path"
    fi
    # Add conda path
    [[ -d "$HOME/miniconda3/bin" ]] && _hc_path="$HOME/miniconda3/bin:$_hc_path"

    _check_tool() {
        local name="$1"
        local cmd="$2"
        if (export PATH="$_hc_path"; eval "$cmd") &>/dev/null 2>&1; then
            _box_line "$CYAN" "  ${GREEN}✓${RESET} ${name}"
            passed=$((passed + 1))
        else
            _box_line "$CYAN" "  ${RED}✗${RESET} ${name}"
            failed=$((failed + 1))
        fi
    }

    # Shell tools
    if [[ "${INSTALL_RESULTS[0]:-}" == "success" ]]; then
        _check_tool "zsh" "zsh --version"
        _check_tool "oh-my-zsh" "test -d $HOME/.oh-my-zsh"
        _check_tool "oh-my-posh" "oh-my-posh --version"
        _check_tool "atuin" "atuin --version"
    fi

    # Terminal
    if [[ "${INSTALL_RESULTS[1]:-}" == "success" ]]; then
        _check_tool "kitty" "kitty --version"
        _check_tool "Hack Nerd Font" "fc-list | grep -qi hack"
    fi

    # CLI Tools
    if [[ "${INSTALL_RESULTS[2]:-}" == "success" ]]; then
        _check_tool "eza" "eza --version"
        _check_tool "bat" "bat --version || batcat --version"
        _check_tool "fd" "fd --version || fdfind --version"
        _check_tool "ripgrep (rg)" "rg --version"
        _check_tool "fzf" "fzf --version"
        _check_tool "zoxide" "zoxide --version"
        _check_tool "lazygit" "lazygit --version"
        _check_tool "btop" "btop --version"
        _check_tool "yazi" "yazi --version"
        _check_tool "glow" "glow --version"
        _check_tool "dust" "dust --version"
        _check_tool "delta" "delta --version"
        _check_tool "zellij" "zellij --version"
        _check_tool "direnv" "direnv --version"
        _check_tool "jq" "jq --version"
    fi

    # Dev Tools
    if [[ "${INSTALL_RESULTS[3]:-}" == "success" ]]; then
        _check_tool "docker" "docker --version"
        _check_tool "rustc" "rustc --version"
        _check_tool "go" "go version"
        _check_tool "node" "node --version"
        _check_tool "java" "java --version"
        _check_tool "cmake" "cmake --version"
        _check_tool "uv" "uv --version"
    fi

    # Editor
    if [[ "${INSTALL_RESULTS[4]:-}" == "success" ]]; then
        _check_tool "nvim" "nvim --version"
        _check_tool "LazyVim config" "test -f $HOME/.config/nvim/init.lua"
    fi

    # ML Tools
    if [[ "${INSTALL_RESULTS[5]:-}" == "success" ]]; then
        _check_tool "conda" "conda --version || $HOME/miniconda3/bin/conda --version"
        _check_tool "ollama" "ollama --version"
    fi

    _box_line "$CYAN" ""
    local result_text="  ${BOLD}Results: ${GREEN}${passed} passed${RESET}"
    if [[ $failed -gt 0 ]]; then
        result_text+=", ${RED}${failed} failed${RESET}"
    fi
    _box_line "$CYAN" "$result_text"
    _box_line "$CYAN" ""
    print_colored "$CYAN" "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# === UPDATE CHECKER ===========================================================

check_for_updates() {
    local remote_version
    remote_version="$(curl -sL --max-time 5 "https://api.github.com/repos/LasaK97/shellmint/releases/latest" 2>/dev/null \
        | grep -oP '"tag_name":\s*"v?\K[^"]*' || echo "")"

    if [[ -n "$remote_version" && "$remote_version" != "$SHELLMINT_VERSION" ]]; then
        echo ""
        print_colored "$YELLOW" "  ╔══════════════════════════════════════════════════════════════╗"
        _box_line "$YELLOW" "  A newer version of ShellMint is available: ${BOLD}v${remote_version}${RESET}"
        _box_line "$YELLOW" "  You are running: ${BOLD}v${SHELLMINT_VERSION}${RESET}"
        _box_line "$YELLOW" "  Update: git pull && ./install.sh --update"
        print_colored "$YELLOW" "  ╚══════════════════════════════════════════════════════════════╝"
        echo ""
    fi
}

# === MAIN EXECUTION ==========================================================

main() {
    # Parse CLI arguments first (before any UI)
    parse_args "$@"

    # Ensure scroll region is reset on exit (normal or error)
    trap 'rc=$?; reset_scroll_region 2>/dev/null || true; tput cnorm 2>/dev/null || true; exit $rc' EXIT

    # Apply pre-selected categories if provided via --categories
    if [[ -n "$PRE_SELECTED_CATEGORIES" ]]; then
        # Deselect all first, then select specified ones
        for i in "${!CATEGORY_SELECTED[@]}"; do
            CATEGORY_SELECTED[$i]=0
        done
        local nums
        nums=$(echo "$PRE_SELECTED_CATEGORIES" | tr ',' ' ')
        for num in $nums; do
            if [[ "$num" =~ ^[1-6]$ ]]; then
                CATEGORY_SELECTED[$((num - 1))]=1
            fi
        done
    fi

    # Apply --skip flag
    if [[ -n "$SKIP_CATEGORIES" ]]; then
        local nums
        nums=$(echo "$SKIP_CATEGORIES" | tr ',' ' ')
        for num in $nums; do
            if [[ "$num" =~ ^[1-6]$ ]]; then
                CATEGORY_SELECTED[$((num - 1))]=0
            fi
        done
    fi

    # Configs-only mode: only run categories that have config files
    if [[ $CONFIGS_ONLY -eq 1 ]]; then
        # Shell (1), Terminal (2), Editor (5) have config files
        CATEGORY_SELECTED=(1 1 0 0 1 0)
        echo ""
        print_colored "$CYAN" "  ShellMint v${SHELLMINT_VERSION} — Configs Only Mode"
        print_colored "$DIM" "  Only applying configuration files (Shell, Terminal, Editor)."
        echo ""
    fi

    # Update mode info
    if [[ $UPDATE_MODE -eq 1 ]]; then
        echo ""
        print_colored "$CYAN" "  ShellMint v${SHELLMINT_VERSION} — Update Mode"
        print_colored "$DIM" "  Tools will be reinstalled even if already present."
        echo ""
    fi

    # Dry-run mode: show what would be installed and exit
    if [[ $DRY_RUN -eq 1 ]]; then
        echo ""
        echo "  ShellMint v${SHELLMINT_VERSION} — Dry Run"
        echo ""
        print_colored "$CYAN" "  The following components would be installed:"
        echo ""
        for i in "${!CATEGORY_IDS[@]}"; do
            local name="${CATEGORY_NAMES[$i]}"
            local desc="${CATEGORY_DESCRIPTIONS[$i]}"
            if [[ ${CATEGORY_SELECTED[$i]} -eq 1 ]]; then
                printf "  ${GREEN}  [✓]${RESET} ${BOLD}%s${RESET}\n" "$name"
                printf "  ${DIM}      %s${RESET}\n" "$desc"
            else
                printf "  ${DIM}  [ ] %s (skipped)${RESET}\n" "$name"
            fi
        done
        echo ""
        print_colored "$YELLOW" "  No changes were made. Remove --dry-run to install."
        echo ""
        exit 0
    fi

    # Show banner (clears screen, prints banner, sets scroll region)
    print_banner

    # Check prerequisites
    print_colored "$BOLD" "  Checking prerequisites..."
    echo ""
    check_prerequisites

    # Obtain sudo credentials early and keep them alive
    ensure_sudo

    # Show system info
    show_system_info

    if [[ $NON_INTERACTIVE -eq 0 ]]; then
        printf "  ${DIM}Press Enter to continue to component selection...${RESET}"
        read -r

        # Reset scroll region before interactive menu (menu uses clear internally)
        reset_scroll_region

        # Interactive menu
        interactive_menu

        # Confirmation (banner stays from menu's last clear)
        reset_scroll_region
        clear
        show_confirmation
    else
        # Non-interactive: skip menu and confirmation
        echo ""
        print_colored "$BOLD" "  Non-interactive mode: installing selected components..."
        echo ""
    fi

    # Re-pin banner for installation phase
    print_banner

    # Run installations (includes summary at the end)
    run_installations

    # Reset scroll region for final output
    reset_scroll_region

    # Post-install health check
    run_health_check

    # Show failed tools that need manual installation (if any)
    show_failed_tools

    # Check if a newer ShellMint version is available
    check_for_updates

    echo ""
    print_colored "$GREEN" "  Log saved to: $LOG_FILE"
    echo ""
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# ShellMint — Modern Terminal Setup for Developers & ML Engineers
# A beautiful interactive terminal setup installer for Ubuntu/Debian
# by Lasantha Kulasooriya
# ============================================================================

# --- Resolve installer directory and source utilities -----------------------
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INSTALLER_DIR/scripts/utils.sh"

# --- Log file setup ---------------------------------------------------------
LOG_FILE="$HOME/.terminal-setup-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo ""
echo "=== ShellMint installer started at $(date) ===" >> "$LOG_FILE"

# --- Error trap --------------------------------------------------------------
trap_error() {
    local exit_code=$?
    local line_number=$1
    reset_scroll_region 2>/dev/null
    echo ""
    print_colored "$RED" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$RED" "  ║                      ERROR OCCURRED                          ║"
    print_colored "$RED" "  ╠══════════════════════════════════════════════════════════════╣"
    print_colored "$RED" "  ║                                                              ║"
    print_colored "$RED" "  ║  An error occurred on line $line_number (exit code $exit_code)$(printf '%*s' $((24 - ${#line_number} - ${#exit_code})) '')║"
    print_colored "$RED" "  ║                                                              ║"
    print_colored "$RED" "  ║  Check the log file for details:                             ║"
    print_colored "$RED" "  ║  $LOG_FILE$(printf '%*s' $((46 - ${#LOG_FILE})) '')║"
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
    "Miniconda, PyTorch+CUDA, Transformers, JupyterLab"
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

    # Check for curl and git, install if missing
    local missing_pkgs=()
    if ! command_exists curl; then
        missing_pkgs+=(curl)
    fi
    if ! command_exists git; then
        missing_pkgs+=(git)
    fi

    if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
        print_colored "$YELLOW" "  Installing missing prerequisites: ${missing_pkgs[*]}..."
        sudo apt-get update -qq > /dev/null 2>&1
        sudo apt-get install -y -qq "${missing_pkgs[@]}" > /dev/null 2>&1
        print_colored "$GREEN" "  ✓ Prerequisites installed."
    fi

    print_colored "$GREEN" "  ✓ All prerequisites met."
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
    printf "  ${CYAN}║${RESET}  ${BOLD}OS:${RESET}     %-52s${CYAN}║${RESET}\n" "$os_version"
    printf "  ${CYAN}║${RESET}  ${BOLD}Kernel:${RESET} %-52s${CYAN}║${RESET}\n" "$kernel"
    printf "  ${CYAN}║${RESET}  ${BOLD}CPU:${RESET}    %-52s${CYAN}║${RESET}\n" "${cpu:0:52}"
    printf "  ${CYAN}║${RESET}  ${BOLD}RAM:${RESET}    %-52s${CYAN}║${RESET}\n" "$ram"
    if [[ -n "$gpu" ]]; then
        printf "  ${CYAN}║${RESET}  ${BOLD}GPU:${RESET}    %-52s${CYAN}║${RESET}\n" "${gpu:0:52}"
    fi
    printf "  ${CYAN}║${RESET}  ${BOLD}Disk:${RESET}   %-52s${CYAN}║${RESET}\n" "$disk"
    print_colored "$CYAN" "  ║                                                              ║"
    print_colored "$CYAN" "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# === INTERACTIVE CATEGORY SELECTION MENU =====================================

draw_menu() {
    # Clear screen area for redraw
    echo ""
    print_colored "$MAGENTA" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$MAGENTA" "  ║                      Select Components                      ║"
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

        print_colored "$MAGENTA" "  ║                                                              ║"
        printf "  ${MAGENTA}║${RESET}  ${checkbox} ${BOLD}[%s]${RESET} %s ${BOLD}%s${RESET}%-*s${MAGENTA}║${RESET}\n" \
            "$id" "$icon" "$name" $((42 - ${#name})) ""

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
                printf "  ${MAGENTA}║${RESET}      ${DIM}%-54s${RESET}${MAGENTA}║${RESET}\n" "$line,"
                line="$part"
                line_len=${#part}
            else
                line="$line, $part"
                line_len=$(( line_len + ${#part} + 2 ))
            fi
        done
        if [[ -n "$line" ]]; then
            printf "  ${MAGENTA}║${RESET}      ${DIM}%-54s${RESET}${MAGENTA}║${RESET}\n" "$line"
        fi
    done

    print_colored "$MAGENTA" "  ║                                                              ║"
    print_colored "$MAGENTA" "  ╠══════════════════════════════════════════════════════════════╣"
    printf "  ${MAGENTA}║${RESET}  ${BOLD}[A]${RESET} Select All    ${BOLD}[N]${RESET} Select None    ${BOLD}[Enter]${RESET} Confirm       ${MAGENTA}║${RESET}\n"
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
    print_colored "$CYAN" "  ║                   Installation Summary                      ║"
    print_colored "$CYAN" "  ╠══════════════════════════════════════════════════════════════╣"
    print_colored "$CYAN" "  ║                                                              ║"

    for i in "${!CATEGORY_IDS[@]}"; do
        local name="${CATEGORY_NAMES[$i]}"
        local est="${CATEGORY_EST_TIMES[$i]}"
        if [[ ${CATEGORY_SELECTED[$i]} -eq 1 ]]; then
            printf "  ${CYAN}║${RESET}  ${GREEN}✓${RESET} %-30s ${DIM}~%-18s${RESET}${CYAN}║${RESET}\n" "$name" "$est"
            total_est=$((total_est + CATEGORY_EST_SECONDS[$i]))
        else
            printf "  ${CYAN}║${RESET}  ${DIM}✗ %-30s skipped${RESET}%19s${CYAN}║${RESET}\n" "$name" ""
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

    print_colored "$CYAN" "  ║                                                              ║"
    printf "  ${CYAN}║${RESET}  ${BOLD}Estimated total time: ~%-36s${RESET}${CYAN}║${RESET}\n" "$est_str"
    printf "  ${CYAN}║${RESET}  ${DIM}(actual time depends on internet speed)${RESET}                     ${CYAN}║${RESET}\n"
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
        printf "  ${CYAN}│${RESET} %s ${BOLD}Installing: %s${RESET}%-*s${CYAN}│${RESET}\n" \
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
            local time_str="installed in $(format_time $elapsed)"
            printf "  ${GREEN}║${RESET}  ${GREEN}✓${RESET} %-24s ${DIM}%-30s${RESET}${GREEN}║${RESET}\n" "$name" "$time_str"
        elif [[ "$result" == "failed" ]]; then
            printf "  ${GREEN}║${RESET}  ${RED}✗${RESET} %-24s ${RED}%-30s${RESET}${GREEN}║${RESET}\n" "$name" "failed"
        else
            printf "  ${GREEN}║${RESET}  ${DIM}✗ %-24s %-30s${RESET}${GREEN}║${RESET}\n" "$name" "skipped"
        fi
    done

    print_colored "$GREEN" "  ║                                                              ║"
    printf "  ${GREEN}║${RESET}  ${BOLD}Total time: %-48s${RESET}${GREEN}║${RESET}\n" "$(format_time $total_time)"
    print_colored "$GREEN" "  ║                                                              ║"

    # Show restart notice if shell was installed
    if [[ "${INSTALL_RESULTS[0]:-skipped}" == "success" ]]; then
        printf "  ${GREEN}║${RESET}  ${YELLOW}⚠ Please restart your terminal or run: exec zsh${RESET}             ${GREEN}║${RESET}\n"
        print_colored "$GREEN" "  ║                                                              ║"
    fi

    printf "  ${GREEN}║${RESET}  To change your prompt theme later, run:                      ${GREEN}║${RESET}\n"
    printf "  ${GREEN}║${RESET}  ${BOLD}./scripts/theme.sh${RESET}                                            ${GREEN}║${RESET}\n"
    print_colored "$GREEN" "  ║                                                              ║"
    print_colored "$GREEN" "  ╠══════════════════════════════════════════════════════════════╣"
    printf "  ${GREEN}║${RESET}  ${BOLD}by Lasantha Kulasooriya${RESET}                                       ${GREEN}║${RESET}\n"
    printf "  ${GREEN}║${RESET}  🔗 linkedin.com/in/lasantha-kulasooriya                        ${GREEN}║${RESET}\n"
    printf "  ${GREEN}║${RESET}  ☕ buymeacoffee.com/lasak97                                   ${GREEN}║${RESET}\n"
    print_colored "$GREEN" "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

# === MAIN EXECUTION ==========================================================

main() {
    # Ensure scroll region is reset on exit (normal or error)
    trap 'reset_scroll_region' EXIT

    # Show banner (clears screen, prints banner, sets scroll region)
    print_banner

    # Check prerequisites
    print_colored "$BOLD" "  Checking prerequisites..."
    echo ""
    check_prerequisites

    # Show system info
    show_system_info

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

    # Re-pin banner for installation phase
    print_banner

    # Run installations (includes summary at the end)
    run_installations

    # Reset scroll region for final output
    reset_scroll_region

    echo ""
    print_colored "$GREEN" "  Log saved to: $LOG_FILE"
    echo ""
}

main "$@"

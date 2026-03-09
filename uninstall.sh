#!/usr/bin/env bash

# ============================================================================
# ShellMint — Selective Uninstaller
# Removes installed components and/or restores backed-up configurations
# by Lasantha Kulasooriya
# ============================================================================

# --- Resolve script directory and source utilities --------------------------
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INSTALLER_DIR/scripts/utils.sh"

# --- Log file setup ---------------------------------------------------------
LOG_FILE="$HOME/.shellmint-uninstall.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo ""
echo "=== ShellMint uninstaller started at $(date) ===" >>"$LOG_FILE"

# === CATEGORY DEFINITIONS ====================================================

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
    "Zsh, Oh My Zsh, Oh My Posh, Atuin"
    "Kitty terminal, Hack Nerd Font"
    "eza, bat, fd, ripgrep, fzf, zoxide, lazygit, btop, yazi, glow, dust, delta, zellij, direnv"
    "Docker, Rust, Go, Node.js, Java, Git delta config"
    "Neovim + LazyVim config"
    "Miniconda, Ollama, nvitop"
)

# Selection state: 1 = selected, 0 = not selected (default: none selected)
CATEGORY_SELECTED=(0 0 0 0 0 0)

# Removal result tracking
declare -A REMOVE_RESULTS
REMOVED_ITEMS=()
RESTORED_ITEMS=()
SKIPPED_ITEMS=()
FAILED_ITEMS=()

# Flags
FLAG_ALL=0
FLAG_CONFIGS_ONLY=0
FLAG_YES=0

# === HELPER FUNCTIONS ========================================================

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

# Find backup files matching a pattern and display them
# Returns 0 if backups found, 1 if none
find_backups() {
    local file="$1"
    local found=0

    if [[ -d "$(dirname "$file")" ]]; then
        local pattern
        pattern="$(basename "$file").backup.*"
        local dir
        dir="$(dirname "$file")"

        while IFS= read -r -d '' backup; do
            local timestamp
            timestamp="$(stat -c '%y' "$backup" 2>/dev/null | cut -d'.' -f1)"
            printf "    ${DIM}%-50s %s${RESET}\n" "$(basename "$backup")" "$timestamp"
            found=1
        done < <(find "$dir" -maxdepth 1 -name "$pattern" -print0 2>/dev/null | sort -z)
    fi

    [[ $found -eq 1 ]]
}

# Restore the most recent backup of a file
# Returns 0 on success, 1 if no backup found
restore_backup() {
    local file="$1"
    local dir
    dir="$(dirname "$file")"
    local base
    base="$(basename "$file")"

    local latest_backup
    latest_backup="$(find "$dir" -maxdepth 1 -name "${base}.backup.*" -print0 2>/dev/null \
        | sort -z -r | head -z -n1 | tr -d '\0')"

    if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
        cp "$latest_backup" "$file" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            print_success "Restored $(basename "$file") from $(basename "$latest_backup")"
            RESTORED_ITEMS+=("$file")
            return 0
        else
            print_error "Failed to restore $file"
            FAILED_ITEMS+=("restore: $file")
            return 1
        fi
    else
        print_warning "No backup found for $file"
        return 1
    fi
}

# Safe removal helper — logs what it does
safe_rm() {
    local target="$1"
    local desc="${2:-$target}"

    if [[ -e "$target" || -L "$target" ]]; then
        rm -rf "$target" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            print_success "Removed $desc"
            REMOVED_ITEMS+=("$desc")
        else
            print_error "Failed to remove $desc"
            FAILED_ITEMS+=("remove: $desc")
        fi
    else
        print_warning "Not found: $desc (already removed?)"
    fi
}

safe_sudo_rm() {
    local target="$1"
    local desc="${2:-$target}"

    if [[ -e "$target" || -L "$target" ]]; then
        sudo rm -rf "$target" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            print_success "Removed $desc"
            REMOVED_ITEMS+=("$desc")
        else
            print_error "Failed to remove $desc"
            FAILED_ITEMS+=("remove: $desc")
        fi
    else
        print_warning "Not found: $desc (already removed?)"
    fi
}

# Ask user for removal mode: full or configs-only
# Returns: "full", "configs", or "skip"
ask_removal_mode() {
    local category_name="$1"

    if [[ $FLAG_YES -eq 1 ]]; then
        if [[ $FLAG_CONFIGS_ONLY -eq 1 ]]; then
            echo "configs"
        else
            echo "full"
        fi
        return
    fi

    echo ""
    print_colored "$YELLOW" "  How would you like to handle ${BOLD}${category_name}${RESET}${YELLOW}?"
    echo ""
    printf "    ${BOLD}[1]${RESET} Remove tools + restore configs (full removal)\n"
    printf "    ${BOLD}[2]${RESET} Restore configs only (keep tools installed)\n"
    printf "    ${BOLD}[3]${RESET} Skip this category\n"
    echo ""
    printf "  ${BOLD}Choose [1/2/3]:${RESET} "
    read -r choice

    case "$choice" in
        1) echo "full" ;;
        2) echo "configs" ;;
        *) echo "skip" ;;
    esac
}

# === UNINSTALL FUNCTIONS PER CATEGORY ========================================

uninstall_shell() {
    local mode
    mode="$(ask_removal_mode "Shell Setup")"

    if [[ "$mode" == "skip" ]]; then
        REMOVE_RESULTS[0]="skipped"
        SKIPPED_ITEMS+=("Shell Setup")
        return
    fi

    echo ""
    print_colored "$CYAN" "  ┌──────────────────────────────────────────────────────────────┐"
    printf "  ${CYAN}│${RESET} 🐚 ${BOLD}Uninstalling: Shell Setup${RESET}%-33s${CYAN} │${RESET}\n" ""
    print_colored "$CYAN" "  └──────────────────────────────────────────────────────────────┘"
    echo ""

    # Show available backups
    print_step "Checking for backups..."
    local has_backups=0
    for f in "$HOME/.zshrc" "$HOME/.zshenv" "$HOME/.config/oh-my-posh/theme.omp.json"; do
        if find_backups "$f"; then
            has_backups=1
        fi
    done
    [[ $has_backups -eq 0 ]] && print_warning "No backup files found for shell configs"
    echo ""

    # Restore configs
    print_step "Restoring shell configurations..."
    restore_backup "$HOME/.zshrc"
    restore_backup "$HOME/.zshenv"
    restore_backup "$HOME/.config/oh-my-posh/theme.omp.json"

    if [[ "$mode" == "full" ]]; then
        # Remove Oh My Zsh
        print_step "Removing Oh My Zsh..."
        safe_rm "$HOME/.oh-my-zsh" "Oh My Zsh (~/.oh-my-zsh)"

        # Remove Oh My Posh
        print_step "Removing Oh My Posh..."
        safe_sudo_rm "/usr/local/bin/oh-my-posh" "Oh My Posh (/usr/local/bin/oh-my-posh)"

        # Remove Atuin
        print_step "Removing Atuin..."
        safe_rm "$HOME/.atuin" "Atuin (~/.atuin)"

        # Optionally revert shell
        if [[ $FLAG_YES -eq 0 ]]; then
            echo ""
            if confirm "Revert default shell back to /bin/bash?"; then
                sudo chsh -s /bin/bash "$USER" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    print_success "Default shell reverted to /bin/bash"
                    REMOVED_ITEMS+=("default shell -> bash")
                else
                    print_error "Failed to revert default shell"
                    FAILED_ITEMS+=("revert shell to bash")
                fi
            fi
        fi
    fi

    REMOVE_RESULTS[0]="$mode"
}

uninstall_terminal() {
    local mode
    mode="$(ask_removal_mode "Terminal Emulator")"

    if [[ "$mode" == "skip" ]]; then
        REMOVE_RESULTS[1]="skipped"
        SKIPPED_ITEMS+=("Terminal Emulator")
        return
    fi

    echo ""
    print_colored "$CYAN" "  ┌──────────────────────────────────────────────────────────────┐"
    printf "  ${CYAN}│${RESET} 🖥️  ${BOLD}Un Terminal Emulator${RESET}%-27s${CYAN}│${RESET}\n" ""
    print_colored "$CYAN" "  └──────────────────────────────────────────────────────────────┘"
    echo ""

    # Show available backups
    print_step "Checking for backups..."
    find_backups "$HOME/.config/kitty/kitty.conf" || print_warning "No backup found for kitty.conf"
    echo ""

    # Restore configs
    print_step "Restoring Kitty configuration..."
    restore_backup "$HOME/.config/kitty/kitty.conf"

    if [[ "$mode" == "full" ]]; then
        # Remove Kitty
        print_step "Removing Kitty..."
        safe_rm "$HOME/.local/kitty.app" "Kitty application (~/.local/kitty.app)"
        safe_sudo_rm "/usr/local/bin/kitty" "Kitty symlink (/usr/local/bin/kitty)"

        # Remove Hack Nerd Font
        print_step "Removing Hack Nerd Font..."
        local font_count=0
        font_count=$(find "$HOME/.local/share/fonts/" -name 'Hack*' 2>/dev/null | wc -l)
        if [[ $font_count -gt 0 ]]; then
            rm -f "$HOME/.local/share/fonts/Hack"* 2>/dev/null
            fc-cache -fv > /dev/null 2>&1
            print_success "Removed $font_count Hack Nerd Font files and rebuilt font cache"
            REMOVED_ITEMS+=("Hack Nerd Font ($font_count files)")
        else
            print_warning "No Hack Nerd Font files found"
        fi
    fi

    REMOVE_RESULTS[1]="$mode"
}

uninstall_cli_tools() {
    local mode
    mode="$(ask_removal_mode "Modern CLI Tools")"

    if [[ "$mode" == "skip" ]]; then
        REMOVE_RESULTS[2]="skipped"
        SKIPPED_ITEMS+=("Modern CLI Tools")
        return
    fi

    echo ""
    print_colored "$CYAN" "  ┌──────────────────────────────────────────────────────────────┐"
    printf "  ${CYAN}│${RESET} 🛠️  ${BOLD}Uninstalling: Modern CLI Tools${RESET}%-28s${CYAN}│${RESET}\n" ""
    print_colored "$CYAN" "  └──────────────────────────────────────────────────────────────┘"
    echo ""

    if [[ "$mode" == "configs" ]]; then
        print_info "Configs-only mode: CLI tools have no standalone config backups to restore."
        REMOVE_RESULTS[2]="$mode"
        return
    fi

    # Remove binaries from /usr/local/bin
    print_step "Removing standalone binaries..."
    local standalone_bins=(lazygit delta dust yazi ya zellij glow)
    for bin in "${standalone_bins[@]}"; do
        safe_sudo_rm "/usr/local/bin/$bin" "$bin"
    done

    # Remove apt packages
    print_step "Removing apt packages..."
    local apt_pkgs=(bat fd-find ripgrep jq btop direnv eza)
    local to_remove=()
    for pkg in "${apt_pkgs[@]}"; do
        if dpkg -s "$pkg" &>/dev/null 2>&1; then
            to_remove+=("$pkg")
        fi
    done

    if [[ ${#to_remove[@]} -gt 0 ]]; then
        sudo apt-get remove -y "${to_remove[@]}" > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            print_success "Removed apt packages: ${to_remove[*]}"
            REMOVED_ITEMS+=("apt: ${to_remove[*]}")
        else
            print_error "Failed to remove some apt packages"
            FAILED_ITEMS+=("apt remove: ${to_remove[*]}")
        fi
    else
        print_warning "No apt packages to remove"
    fi

    # Remove fzf
    print_step "Removing fzf..."
    if [[ -d "$HOME/.fzf" ]]; then
        # Run uninstall script if available
        if [[ -f "$HOME/.fzf/uninstall" ]]; then
            "$HOME/.fzf/uninstall" --all > /dev/null 2>&1
        fi
        safe_rm "$HOME/.fzf" "fzf (~/.fzf)"
    else
        print_warning "fzf directory not found"
    fi

    # Remove zoxide
    print_step "Removing zoxide..."
    if command_exists zoxide; then
        safe_sudo_rm "$(command -v zoxide)" "zoxide"
    else
        print_warning "zoxide not found"
    fi

    REMOVE_RESULTS[2]="$mode"
}

uninstall_dev_tools() {
    local mode
    mode="$(ask_removal_mode "Development Tools")"

    if [[ "$mode" == "skip" ]]; then
        REMOVE_RESULTS[3]="skipped"
        SKIPPED_ITEMS+=("Development Tools")
        return
    fi

    echo ""
    print_colored "$CYAN" "  ┌──────────────────────────────────────────────────────────────┐"
    printf "  ${CYAN}│${RESET} 💻 ${BOLD}Uninstalling: Development Tools${RESET}%-27s${CYAN}│${RESET}\n" ""
    print_colored "$CYAN" "  └──────────────────────────────────────────────────────────────┘"
    echo ""

    # Restore git config (remove delta settings)
    print_step "Restoring git configuration (removing delta settings)..."
    if command_exists git; then
        git config --global --unset core.pager 2>/dev/null
        git config --global --unset interactive.diffFilter 2>/dev/null
        git config --global --remove-section delta 2>/dev/null
        git config --global --remove-section merge 2>/dev/null
        git config --global --remove-section diff 2>/dev/null
        print_success "Removed delta settings from git config"
        RESTORED_ITEMS+=("git config (delta settings removed)")
    fi

    if [[ "$mode" == "configs" ]]; then
        REMOVE_RESULTS[3]="$mode"
        return
    fi

    # Remove Docker
    print_step "Removing Docker..."
    local docker_pkgs=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
    local docker_to_remove=()
    for pkg in "${docker_pkgs[@]}"; do
        if dpkg -s "$pkg" &>/dev/null 2>&1; then
            docker_to_remove+=("$pkg")
        fi
    done

    if [[ ${#docker_to_remove[@]} -gt 0 ]]; then
        sudo apt-get remove -y "${docker_to_remove[@]}" > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            print_success "Removed Docker packages: ${docker_to_remove[*]}"
            REMOVED_ITEMS+=("Docker")
        else
            print_error "Failed to remove Docker packages"
            FAILED_ITEMS+=("Docker removal")
        fi
    else
        print_warning "Docker packages not found"
    fi

    # Remove Rust
    print_step "Removing Rust..."
    if [[ -d "$HOME/.rustup" ]] || [[ -d "$HOME/.cargo" ]]; then
        safe_rm "$HOME/.rustup" "Rust toolchain (~/.rustup)"
        safe_rm "$HOME/.cargo" "Cargo (~/.cargo)"
    else
        print_warning "Rust not found"
    fi

    # Remove Go
    print_step "Removing Go..."
    safe_sudo_rm "/usr/local/go" "Go (/usr/local/go)"

    # Remove nvm
    print_step "Removing nvm..."
    safe_rm "$HOME/.nvm" "nvm (~/.nvm)"

    # Remove Java
    print_step "Removing Java (OpenJDK 17)..."
    if dpkg -s openjdk-17-jdk &>/dev/null 2>&1; then
        sudo apt-get remove -y openjdk-17-jdk > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            print_success "Removed openjdk-17-jdk"
            REMOVED_ITEMS+=("OpenJDK 17")
        else
            print_error "Failed to remove openjdk-17-jdk"
            FAILED_ITEMS+=("openjdk-17-jdk removal")
        fi
    else
        print_warning "openjdk-17-jdk not found"
    fi

    # Remove cmake
    print_step "Removing cmake..."
    if dpkg -s cmake &>/dev/null 2>&1; then
        sudo apt-get remove -y cmake > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            print_success "Removed cmake"
            REMOVED_ITEMS+=("cmake")
        else
            print_error "Failed to remove cmake"
            FAILED_ITEMS+=("cmake removal")
        fi
    else
        print_warning "cmake not found"
    fi

    # Remove pipx
    print_step "Removing pipx..."
    if command_exists pipx; then
        sudo apt-get remove -y pipx > /dev/null 2>&1 || pip uninstall -y pipx > /dev/null 2>&1
        print_success "Removed pipx"
        REMOVED_ITEMS+=("pipx")
    else
        print_warning "pipx not found"
    fi

    # Remove uv
    print_step "Removing uv..."
    if command_exists uv; then
        safe_rm "$HOME/.cargo/bin/uv" "uv"
        safe_rm "$HOME/.local/bin/uv" "uv (local bin)"
    else
        print_warning "uv not found"
    fi

    REMOVE_RESULTS[3]="$mode"
}

uninstall_editor() {
    local mode
    mode="$(ask_removal_mode "Editor")"

    if [[ "$mode" == "skip" ]]; then
        REMOVE_RESULTS[4]="skipped"
        SKIPPED_ITEMS+=("Editor")
        return
    fi

    echo ""
    print_colored "$CYAN" "  ┌──────────────────────────────────────────────────────────────┐"
    printf "  ${CYAN}│${RESET} ✏️  ${BOLD}Uninstalling: Editor${RESET}%-38s${CYAN}│${RESET}\n" ""
    print_colored "$CYAN" "  └──────────────────────────────────────────────────────────────┘"
    echo ""

    # Show available backups
    print_step "Checking for Neovim config backups..."
    find_backups "$HOME/.config/nvim" || print_warning "No backup found for nvim config"
    echo ""

    # Restore nvim config
    print_step "Restoring Neovim configuration..."
    restore_backup "$HOME/.config/nvim"

    if [[ "$mode" == "full" ]]; then
        # Remove Neovim binary
        print_step "Removing Neovim..."
        safe_rm "$HOME/.local/bin/nvim" "Neovim binary (~/.local/bin/nvim)"
        safe_sudo_rm "/usr/local/bin/nvim" "Neovim symlink (/usr/local/bin/nvim)"
    fi

    REMOVE_RESULTS[4]="$mode"
}

uninstall_ml_tools() {
    local mode
    mode="$(ask_removal_mode "ML/AI Stack")"

    if [[ "$mode" == "skip" ]]; then
        REMOVE_RESULTS[5]="skipped"
        SKIPPED_ITEMS+=("ML/AI Stack")
        return
    fi

    echo ""
    print_colored "$CYAN" "  ┌──────────────────────────────────────────────────────────────┐"
    printf "  ${CYAN}│${RESET} 🧠 ${BOLD}Uninstalling: ML/AI Stack${RESET}%-32s${CYAN}│${RESET}\n" ""
    print_colored "$CYAN" "  └──────────────────────────────────────────────────────────────┘"
    echo ""

    if [[ "$mode" == "configs" ]]; then
        print_info "Configs-only mode: ML/AI stack has no standalone config backups to restore."
        REMOVE_RESULTS[5]="$mode"
        return
    fi

    # Remove Miniconda
    print_step "Removing Miniconda..."
    safe_rm "$HOME/miniconda3" "Miniconda (~/miniconda3)"

    # Remove Ollama
    print_step "Removing Ollama..."
    safe_sudo_rm "/usr/local/bin/ollama" "Ollama (/usr/local/bin/ollama)"

    # Remove nvitop
    print_step "Removing nvitop..."
    if command_exists uv; then
        uv tool uninstall nvitop > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            print_success "Removed nvitop (via uv)"
            REMOVED_ITEMS+=("nvitop")
        else
            print_warning "nvitop not found via uv"
        fi
    elif command_exists pipx; then
        pipx uninstall nvitop > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            print_success "Removed nvitop (via pipx)"
            REMOVED_ITEMS+=("nvitop")
        else
            print_warning "nvitop not found via pipx"
        fi
    else
        print_warning "Neither uv nor pipx available to remove nvitop"
    fi

    REMOVE_RESULTS[5]="$mode"
}

# === INTERACTIVE CATEGORY SELECTION MENU =====================================

draw_menu() {
    echo ""
    print_colored "$RED" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$RED" "  ║                   Select Components to Remove                ║"
    print_colored "$RED" "  ╠══════════════════════════════════════════════════════════════╣"

    for i in "${!CATEGORY_IDS[@]}"; do
        local id="${CATEGORY_IDS[$i]}"
        local name="${CATEGORY_NAMES[$i]}"
        local icon="${CATEGORY_ICONS[$i]}"
        local desc="${CATEGORY_DESCRIPTIONS[$i]}"
        local selected="${CATEGORY_SELECTED[$i]}"

        local checkbox
        if [[ $selected -eq 1 ]]; then
            checkbox="${RED}[x]${RESET}"
        else
            checkbox="${DIM}[ ]${RESET}"
        fi

        _box_line "$RED" ""
        _box_line "$RED" "  ${checkbox} ${BOLD}[${id}]${RESET} ${icon}  ${BOLD}${name}${RESET}"

        # Handle multi-line descriptions
        local line_len=0
        local line=""
        local first=1
        IFS=',' read -ra desc_parts <<< "$desc"
        for part in "${desc_parts[@]}"; do
            part=$(echo "$part" | xargs)
            if [[ $first -eq 1 ]]; then
                line="$part"
                line_len=${#part}
                first=0
            elif (( line_len + ${#part} + 2 > 52 )); then
                _box_line "$RED" "      ${DIM}${line},${RESET}"
                line="$part"
                line_len=${#part}
            else
                line="$line, $part"
                line_len=$(( line_len + ${#part} + 2 ))
            fi
        done
        if [[ -n "$line" ]]; then
            _box_line "$RED" "      ${DIM}${line}${RESET}"
        fi
    done

    _box_line "$RED" ""
    print_colored "$RED" "  ╠══════════════════════════════════════════════════════════════╣"
    _box_line "$RED" "  ${BOLD}[A]${RESET} Select All    ${BOLD}[N]${RESET} Select None    ${BOLD}[Enter]${RESET} Confirm"
    print_colored "$RED" "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

interactive_menu() {
    while true; do
        clear
        _print_banner_content 0
        draw_menu

        printf "  ${BOLD}Toggle categories (e.g. 1 3 5 or 1,3,5), A=all, N=none, Enter=confirm:${RESET} "
        read -r input

        # Confirm on empty input
        if [[ -z "$input" ]]; then
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

        # Parse numbers
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
    echo ""
    print_colored "$RED" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$RED" "  ║                     Uninstall Summary                        ║"
    print_colored "$RED" "  ╠══════════════════════════════════════════════════════════════╣"
    print_colored "$RED" "  ║                                                              ║"

    for i in "${!CATEGORY_IDS[@]}"; do
        local name="${CATEGORY_NAMES[$i]}"
        if [[ ${CATEGORY_SELECTED[$i]} -eq 1 ]]; then
            _box_line "$RED" "  ${RED}x${RESET} ${name}"
        else
            _box_line "$RED" "  ${DIM}  ${name} — kept${RESET}"
        fi
    done

    _box_line "$RED" ""

    if [[ $FLAG_CONFIGS_ONLY -eq 1 ]]; then
        _box_line "$RED" "  ${YELLOW}Mode: Restore configs only (tools will be kept)${RESET}"
        _box_line "$RED" ""
    fi

    print_colored "$RED" "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""

    if [[ $FLAG_YES -eq 0 ]]; then
        printf "  ${BOLD}${RED}Proceed with uninstallation? [y/N]:${RESET} "
        read -r confirm
        if [[ ! "$confirm" =~ ^[Yy] ]]; then
            print_colored "$YELLOW" "  Uninstallation cancelled."
            exit 0
        fi
    fi
}

# === FINAL SUMMARY ===========================================================

show_final_summary() {
    local total_time=$1

    echo ""
    echo ""
    print_colored "$CYAN" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$CYAN" "  ║                   Uninstall Complete                         ║"
    print_colored "$CYAN" "  ╠══════════════════════════════════════════════════════════════╣"
    print_colored "$CYAN" "  ║                                                              ║"

    # Per-category results
    for i in "${!CATEGORY_IDS[@]}"; do
        local name="${CATEGORY_NAMES[$i]}"
        local result="${REMOVE_RESULTS[$i]:-skipped}"

        if [[ "$result" == "full" ]]; then
            _box_line "$CYAN" "  ${RED}x${RESET} ${name}$(printf '%*s' $((24 - ${#name})) '')${DIM}fully removed${RESET}"
        elif [[ "$result" == "configs" ]]; then
            _box_line "$CYAN" "  ${YELLOW}~${RESET} ${name}$(printf '%*s' $((24 - ${#name})) '')${DIM}configs restored${RESET}"
        else
            _box_line "$CYAN" "  ${GREEN}-${RESET} ${name}$(printf '%*s' $((24 - ${#name})) '')${DIM}kept${RESET}"
        fi
    done

    _box_line "$CYAN" ""

    # Counters
    local removed_count=${#REMOVED_ITEMS[@]}
    local restored_count=${#RESTORED_ITEMS[@]}
    local failed_count=${#FAILED_ITEMS[@]}

    _box_line "$CYAN" "  ${BOLD}Items removed:${RESET}    ${removed_count}"
    _box_line "$CYAN" "  ${BOLD}Configs restored:${RESET} ${restored_count}"

    if [[ $failed_count -gt 0 ]]; then
        _box_line "$CYAN" "  ${RED}${BOLD}Failed:${RESET}           ${failed_count}"
    fi

    _box_line "$CYAN" "  ${BOLD}Total time:${RESET}       $(format_time $total_time)"

    print_colored "$CYAN" "  ║                                                              ║"
    print_colored "$CYAN" "  ╚══════════════════════════════════════════════════════════════╝"

    # Show detailed removal list
    if [[ $removed_count -gt 0 ]]; then
        echo ""
        print_colored "$DIM" "  Removed items:"
        for item in "${REMOVED_ITEMS[@]}"; do
            printf "    ${DIM}- %s${RESET}\n" "$item"
        done
    fi

    # Show detailed restore list
    if [[ $restored_count -gt 0 ]]; then
        echo ""
        print_colored "$DIM" "  Restored configs:"
        for item in "${RESTORED_ITEMS[@]}"; do
            printf "    ${DIM}- %s${RESET}\n" "$item"
        done
    fi

    # Show failures
    if [[ $failed_count -gt 0 ]]; then
        echo ""
        print_colored "$RED" "  Failed operations:"
        for item in "${FAILED_ITEMS[@]}"; do
            printf "    ${RED}- %s${RESET}\n" "$item"
        done
    fi

    echo ""
}

# === USAGE / HELP ============================================================

show_help() {
    _print_banner_content 0
    echo ""
    print_colored "$BOLD" "  Usage: ./uninstall.sh [OPTIONS]"
    echo ""
    print_colored "$BOLD" "  Options:"
    printf "    ${BOLD}--help${RESET}          Show this help message\n"
    printf "    ${BOLD}--all${RESET}           Select all categories for removal\n"
    printf "    ${BOLD}--configs-only${RESET}  Only restore config files (keep tools installed)\n"
    printf "    ${BOLD}--yes${RESET}           Non-interactive mode (skip confirmation prompts)\n"
    echo ""
    print_colored "$BOLD" "  Examples:"
    printf "    ${DIM}./uninstall.sh${RESET}                   Interactive mode\n"
    printf "    ${DIM}./uninstall.sh --all${RESET}             Remove everything interactively\n"
    printf "    ${DIM}./uninstall.sh --all --yes${RESET}       Remove everything non-interactively\n"
    printf "    ${DIM}./uninstall.sh --configs-only${RESET}    Only restore backed-up configs\n"
    echo ""
    print_colored "$BOLD" "  Categories:"
    for i in "${!CATEGORY_IDS[@]}"; do
        printf "    ${BOLD}%s.${RESET} %s %s\n" "${CATEGORY_IDS[$i]}" "${CATEGORY_ICONS[$i]}" "${CATEGORY_NAMES[$i]}"
        printf "       ${DIM}%s${RESET}\n" "${CATEGORY_DESCRIPTIONS[$i]}"
    done
    echo ""
}

# === MAIN EXECUTION ==========================================================

main() {
    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --all)
                FLAG_ALL=1
                shift
                ;;
            --configs-only)
                FLAG_CONFIGS_ONLY=1
                shift
                ;;
            --yes|-y)
                FLAG_YES=1
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "  Run ./uninstall.sh --help for usage."
                exit 1
                ;;
        esac
    done

    # Show banner (no animation)
    clear
    _print_banner_content 0
    echo ""

    print_colored "$RED" "  ╔══════════════════════════════════════════════════════════════╗"
    print_colored "$RED" "  ║                    ShellMint Uninstaller                      ║"
    print_colored "$RED" "  ║       This will selectively remove installed components       ║"
    print_colored "$RED" "  ╚══════════════════════════════════════════════════════════════╝"
    echo ""

    # Select all if --all flag
    if [[ $FLAG_ALL -eq 1 ]]; then
        for i in "${!CATEGORY_SELECTED[@]}"; do
            CATEGORY_SELECTED[$i]=1
        done
    fi

    # Obtain sudo credentials early
    ensure_sudo

    # Interactive menu or skip if --all
    if [[ $FLAG_ALL -eq 0 ]]; then
        interactive_menu
    fi

    # Confirmation
    show_confirmation

    # Run uninstallations
    local overall_start=$SECONDS

    echo ""
    print_colored "$BOLD" "  ══════════════════════════════════════════════════════════════"
    print_colored "$BOLD" "                     Starting Uninstallation"
    print_colored "$BOLD" "  ══════════════════════════════════════════════════════════════"

    local uninstall_fns=(
        uninstall_shell
        uninstall_terminal
        uninstall_cli_tools
        uninstall_dev_tools
        uninstall_editor
        uninstall_ml_tools
    )

    for i in "${!CATEGORY_IDS[@]}"; do
        if [[ ${CATEGORY_SELECTED[$i]} -eq 1 ]]; then
            "${uninstall_fns[$i]}"
        else
            REMOVE_RESULTS[$i]="skipped"
            SKIPPED_ITEMS+=("${CATEGORY_NAMES[$i]}")
        fi
    done

    local overall_elapsed=$((SECONDS - overall_start))

    # Show final summary
    show_final_summary "$overall_elapsed"

    print_colored "$GREEN" "  Log saved to: $LOG_FILE"
    echo ""
}

main "$@"

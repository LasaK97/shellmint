#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# =============================================================================
# theme.sh — Oh My Posh theme browser and switcher
# =============================================================================

# Top 20 popular Oh My Posh themes with descriptions
declare -A THEMES
THEMES=(
    ["agnoster"]="Classic powerline-style theme with git info"
    ["amro"]="Clean and minimal with path and git status"
    ["atomic"]="Colorful with detailed segment information"
    ["blueish"]="Blue-toned theme with rounded segments"
    ["bubbles"]="Rounded bubble-style segments"
    ["bubblesextra"]="Extended bubbles with extra info segments"
    ["bubblesline"]="Bubbles theme with line separator"
    ["catppuccin"]="Warm pastel theme inspired by Catppuccin palette"
    ["catppuccin_mocha"]="Catppuccin Mocha variant - dark and cozy"
    ["clean-detailed"]="Detailed segments with a clean look"
    ["dracula"]="Based on the popular Dracula color scheme"
    ["gruvbox"]="Warm retro groove colors from Gruvbox"
    ["half-life"]="Inspired by Half-Life game aesthetics"
    ["hunk"]="Bold and chunky segments"
    ["jandedobbeleer"]="The Oh My Posh creator's personal theme"
    ["night-owl"]="Dark theme inspired by Night Owl VS Code theme"
    ["nordtron"]="Nord color palette with Tron styling"
    ["powerlevel10k_rainbow"]="Rainbow powerline inspired by p10k"
    ["spaceship"]="Minimalist theme inspired by Spaceship prompt"
    ["tokyo"]="Tokyo Night color scheme"
)

# Ordered list for display
THEME_NAMES=(
    "agnoster"
    "amro"
    "atomic"
    "blueish"
    "bubbles"
    "bubblesextra"
    "bubblesline"
    "catppuccin"
    "catppuccin_mocha"
    "clean-detailed"
    "dracula"
    "gruvbox"
    "half-life"
    "hunk"
    "jandedobbeleer"
    "night-owl"
    "nordtron"
    "powerlevel10k_rainbow"
    "spaceship"
    "tokyo"
)

_list_themes() {
    echo ""
    echo "${BOLD}${CYAN} Available Oh My Posh Themes${RESET}"
    echo "${DIM} $(printf '─%.0s' $(seq 1 50))${RESET}"
    echo ""

    local i=1
    for name in "${THEME_NAMES[@]}"; do
        printf " ${BOLD}${GREEN}%2d${RESET}) ${BOLD}%-25s${RESET} ${DIM}%s${RESET}\n" \
            "$i" "$name" "${THEMES[$name]}"
        (( i++ ))
    done

    echo ""
    echo "${DIM} Theme previews: https://ohmyposh.dev/docs/themes${RESET}"
    echo ""
}

_download_theme() {
    local theme_name="$1"
    local dest="$HOME/.config/oh-my-posh/theme.omp.json"
    local url="https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/${theme_name}.omp.json"

    mkdir -p "$(dirname "$dest")"

    # Backup current theme if it exists
    [[ -f "$dest" ]] && backup_file "$dest"

    curl -fsSL "$url" -o "$dest" &>/dev/null &
    if spinner $! "Downloading theme '${theme_name}'"; then
        print_success "Theme '${theme_name}' installed to ${dest}"
        return 0
    else
        print_error "Failed to download theme '${theme_name}'"
        return 1
    fi
}

_clear_cache() {
    local cache_file="$HOME/.cache/oh-my-posh-init.zsh"
    if [[ -f "$cache_file" ]]; then
        rm -f "$cache_file"
        print_info "Cleared oh-my-posh cache"
    fi

    # Also clear any other potential cache locations
    rm -f "$HOME/.cache/oh-my-posh"* 2>/dev/null
}

change_theme() {
    print_header "Oh My Posh Theme Switcher"

    if ! command_exists oh-my-posh; then
        print_error "Oh My Posh is not installed. Run the shell installer first."
        return 1
    fi

    _list_themes

    local selection
    while true; do
        printf "${BOLD}${YELLOW} ? ${RESET}${BOLD}Select a theme (1-%d) or 'q' to quit:${RESET} " "${#THEME_NAMES[@]}"
        read -r selection

        if [[ "$selection" == "q" || "$selection" == "Q" ]]; then
            print_info "No changes made."
            return 0
        fi

        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#THEME_NAMES[@]} )); then
            break
        fi

        print_warning "Invalid selection. Please enter a number between 1 and ${#THEME_NAMES[@]}."
    done

    local chosen_theme="${THEME_NAMES[$((selection - 1))]}"
    print_step "Applying theme: ${chosen_theme}"

    if _download_theme "$chosen_theme"; then
        _clear_cache
        echo ""
        print_success "Theme changed to '${chosen_theme}'"
        print_info "Restart your shell or run 'exec zsh' to see the new theme."
    else
        print_error "Theme change failed."
        return 1
    fi
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    change_theme
fi

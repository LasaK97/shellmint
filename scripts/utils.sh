#!/usr/bin/env bash
# =============================================================================
# utils.sh — Utility library for ShellMint installer
# Author: Lasantha Kulasooriya
# Description: Provides colors, logging, spinners, progress bars, timers,
#              system helpers, and interactive prompts for a beautiful
#              terminal installation experience.
# =============================================================================

# Prevent double-sourcing
[[ -n "${_UTILS_SH_LOADED:-}" ]] && return 0
_UTILS_SH_LOADED=1

# =============================================================================
# COLOR CONSTANTS (tput-based for portability)
# =============================================================================

BOLD="$(tput bold 2>/dev/null || echo '')"
DIM="$(tput dim 2>/dev/null || echo '')"
ITALIC="$(tput sitm 2>/dev/null || echo '')"
UNDERLINE="$(tput smul 2>/dev/null || echo '')"
RESET="$(tput sgr0 2>/dev/null || echo '')"

RED="$(tput setaf 1 2>/dev/null || echo '')"
GREEN="$(tput setaf 2 2>/dev/null || echo '')"
YELLOW="$(tput setaf 3 2>/dev/null || echo '')"
BLUE="$(tput setaf 4 2>/dev/null || echo '')"
MAGENTA="$(tput setaf 5 2>/dev/null || echo '')"
CYAN="$(tput setaf 6 2>/dev/null || echo '')"
WHITE="$(tput setaf 7 2>/dev/null || echo '')"

BG_RED="$(tput setab 1 2>/dev/null || echo '')"
BG_GREEN="$(tput setab 2 2>/dev/null || echo '')"
BG_BLUE="$(tput setab 4 2>/dev/null || echo '')"
BG_MAGENTA="$(tput setab 5 2>/dev/null || echo '')"

# =============================================================================
# SYMBOL CONSTANTS
# =============================================================================

CHECKMARK="✓"
CROSSMARK="✗"
ARROW="➜"
GEAR="⚙"
PACKAGE="📦"
ROCKET="🚀"
SPARKLE="✨"
WARN="⚠"
INFO="ℹ"
COFFEE="☕"

# =============================================================================
# RAW COLOR PRINTING
# =============================================================================

# print_colored "$COLOR" "text"
# Prints text with the given color code.
print_colored() {
    local color="$1"
    local text="$2"
    echo "${color}${text}${RESET}"
}

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# print_header "text"
# Prints centered, bold text with decorative ═══ borders.
print_header() {
    local text="$1"
    local width=64
    local text_len=${#text}
    local pad_total=$(( width - text_len - 2 ))
    local pad_left=$(( pad_total / 2 ))
    local pad_right=$(( pad_total - pad_left ))

    echo ""
    echo "${BOLD}${CYAN} ╔$(printf '═%.0s' $(seq 1 "$width"))╗${RESET}"
    echo "${BOLD}${CYAN} ║$(printf ' %.0s' $(seq 1 "$pad_left")) ${text} $(printf ' %.0s' $(seq 1 "$pad_right"))║${RESET}"
    echo "${BOLD}${CYAN} ╚$(printf '═%.0s' $(seq 1 "$width"))╝${RESET}"
    echo ""
}

# print_step "text"
# Prints a step message with arrow prefix in cyan.
print_step() {
    echo "${CYAN}${BOLD} ${ARROW} ${RESET}${CYAN}$1${RESET}"
}

# print_success "text"
# Prints a success message with checkmark prefix in green.
print_success() {
    echo "${GREEN}${BOLD} ${CHECKMARK} ${RESET}${GREEN}$1${RESET}"
}

# print_error "text"
# Prints an error message with crossmark prefix in red.
print_error() {
    echo "${RED}${BOLD} ${CROSSMARK} ${RESET}${RED}$1${RESET}"
}

# print_warning "text"
# Prints a warning message with warning prefix in yellow.
print_warning() {
    echo "${YELLOW}${BOLD} ${WARN} ${RESET}${YELLOW}$1${RESET}"
}

# print_info "text"
# Prints an info message with info prefix in blue.
print_info() {
    echo "${BLUE}${BOLD} ${INFO} ${RESET}${BLUE}$1${RESET}"
}

# print_package "name"
# Shows what package is being installed.
print_package() {
    echo "${MAGENTA} ${PACKAGE} ${RESET}${BOLD}Installing:${RESET} $1"
}

# =============================================================================
# SPINNER FUNCTION
# =============================================================================

# spinner PID "message"
# Shows an animated braille spinner while a background PID runs.
# Displays elapsed time in seconds. On completion, replaces spinner
# with a checkmark and shows total duration.
spinner() {
    local pid="$1"
    local message="$2"
    local spin_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local start_time
    start_time=$(date +%s)
    local i=0

    # Hide cursor
    tput civis 2>/dev/null || true

    while kill -0 "$pid" 2>/dev/null; do
        local now
        now=$(date +%s)
        local elapsed=$(( now - start_time ))
        local frame="${spin_chars[$((i % ${#spin_chars[@]}))]}"
        printf "\r${CYAN}${BOLD} %s ${RESET}%s ${DIM}(%ds)${RESET}" "$frame" "$message" "$elapsed"
        i=$(( i + 1 ))
        sleep 0.1
    done

    # Check exit status of the background process
    wait "$pid" 2>/dev/null
    local exit_code=$?

    local end_time
    end_time=$(date +%s)
    local total_elapsed=$(( end_time - start_time ))
    local duration
    duration="$(format_duration "$total_elapsed")"

    # Clear the spinner line and show result
    printf "\r\033[K"
    if [[ $exit_code -eq 0 ]]; then
        echo "${GREEN}${BOLD} ${CHECKMARK} ${RESET}${message} ${DIM}(${duration})${RESET}"
    else
        echo "${RED}${BOLD} ${CROSSMARK} ${RESET}${message} ${DIM}(${duration})${RESET}"
    fi

    # Restore cursor
    tput cnorm 2>/dev/null || true

    return "$exit_code"
}

# =============================================================================
# PROGRESS BAR
# =============================================================================

# progress_bar current total "label"
# Draws a colored progress bar: [████████░░░░░░░░] 45% label
progress_bar() {
    local current="$1"
    local total="$2"
    local label="${3:-}"
    local bar_width=30
    local percent=0

    if [[ "$total" -gt 0 ]]; then
        percent=$(( current * 100 / total ))
    fi

    local filled=$(( bar_width * current / total ))
    local empty=$(( bar_width - filled ))

    local bar=""
    if [[ $filled -gt 0 ]]; then
        bar="${GREEN}$(printf '█%.0s' $(seq 1 "$filled"))${RESET}"
    fi
    if [[ $empty -gt 0 ]]; then
        bar+="${DIM}$(printf '░%.0s' $(seq 1 "$empty"))${RESET}"
    fi

    printf "\r ${BOLD}[${RESET}%s${BOLD}]${RESET} ${CYAN}%3d%%${RESET} %s" "$bar" "$percent" "$label"

    if [[ "$current" -eq "$total" ]]; then
        echo ""
    fi
}

# =============================================================================
# TIMER FUNCTIONS
# =============================================================================

TIMER_START=""

# timer_start
# Stores the current epoch time in TIMER_START.
timer_start() {
    TIMER_START=$(date +%s)
}

# timer_elapsed
# Returns formatted elapsed time since timer_start was called.
timer_elapsed() {
    local now
    now=$(date +%s)
    local elapsed=$(( now - TIMER_START ))
    format_duration "$elapsed"
}

# format_duration seconds
# Converts seconds to human-readable format (e.g., "1m 23s").
format_duration() {
    local total_seconds="$1"

    if [[ "$total_seconds" -lt 60 ]]; then
        echo "${total_seconds}s"
    elif [[ "$total_seconds" -lt 3600 ]]; then
        local mins=$(( total_seconds / 60 ))
        local secs=$(( total_seconds % 60 ))
        echo "${mins}m ${secs}s"
    else
        local hours=$(( total_seconds / 3600 ))
        local mins=$(( (total_seconds % 3600) / 60 ))
        local secs=$(( total_seconds % 60 ))
        echo "${hours}h ${mins}m ${secs}s"
    fi
}

# =============================================================================
# SYSTEM HELPERS
# =============================================================================

# command_exists cmd
# Returns 0 if the command exists, 1 otherwise.
command_exists() {
    command -v "$1" &>/dev/null
}

# is_ubuntu_debian
# Returns 0 if running on Ubuntu or Debian.
is_ubuntu_debian() {
    [[ -f /etc/os-release ]] && grep -qiE 'ubuntu|debian' /etc/os-release
}

# get_ubuntu_version
# Prints the Ubuntu version string (e.g., "22.04").
get_ubuntu_version() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        echo "${VERSION_ID:-unknown}"
    else
        echo "unknown"
    fi
}

# ensure_sudo
# Prompts for sudo password if needed and caches credentials.
ensure_sudo() {
    if [[ "$EUID" -eq 0 ]]; then
        return 0
    fi

    print_info "Sudo access is required for some operations."
    if ! sudo -v 2>/dev/null; then
        print_error "Failed to obtain sudo credentials."
        return 1
    fi

    # Keep sudo alive in background
    (
        while true; do
            sudo -n true 2>/dev/null
            sleep 50
        done
    ) &
    SUDO_KEEP_ALIVE_PID=$!

    # Ensure we kill the background process on exit
    trap 'kill $SUDO_KEEP_ALIVE_PID 2>/dev/null' EXIT
}

# add_line_if_missing "line" "file"
# Appends the line to the file if it is not already present.
add_line_if_missing() {
    local line="$1"
    local file="$2"

    if [[ ! -f "$file" ]]; then
        echo "$line" >> "$file"
        return 0
    fi

    if ! grep -qxF "$line" "$file" 2>/dev/null; then
        echo "$line" >> "$file"
    fi
}

# backup_file "path"
# Creates a timestamped backup of a file (e.g., .bashrc.backup.20260305_143022).
backup_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        print_warning "Cannot backup: file does not exist — ${file}"
        return 1
    fi

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup="${file}.backup.${timestamp}"
    cp "$file" "$backup"
    print_info "Backup created: ${backup}"
}

# =============================================================================
# INTERACTIVE HELPERS
# =============================================================================

# confirm "question"
# Displays a yes/no prompt. Returns 0 for yes, 1 for no.
confirm() {
    local question="$1"
    local reply

    while true; do
        printf "${BOLD}${YELLOW} ? ${RESET}${BOLD}%s${RESET} ${DIM}[y/N]${RESET} " "$question"
        read -r reply
        case "${reply,,}" in
            y|yes) return 0 ;;
            n|no|"") return 1 ;;
            *) print_warning "Please answer y or n." ;;
        esac
    done
}

# print_category_header "emoji" "name" "description"
# Prints a formatted category header for selection menus.
print_category_header() {
    local emoji="$1"
    local name="$2"
    local description="$3"

    echo ""
    echo "${BOLD} ${emoji} ${name}${RESET}"
    echo "${DIM}   ${description}${RESET}"
    echo "${DIM}   $(printf '─%.0s' $(seq 1 50))${RESET}"
}

# =============================================================================
# BANNER FUNCTION
# =============================================================================

# _type_out "text"
# Internal helper: prints text character by character with a small delay.
_type_out() {
    local text="$1"
    local delay="${2:-0.002}"
    local i

    for (( i = 0; i < ${#text}; i++ )); do
        printf '%s' "${text:$i:1}"
        sleep "$delay"
    done
    echo ""
}

# BANNER_LINES — total number of lines the banner occupies (used for scroll region)
BANNER_HEIGHT=14
_BANNER_ANIMATED=0

# _print_banner_content [animate]
# Internal: prints the banner lines. If animate=1, uses typing effect.
_print_banner_content() {
    local animate="${1:-0}"

    local lines=(
        ""
        "   ███████╗██╗  ██╗███████╗██╗     ██╗     ███╗   ███╗██╗███╗   ██╗████████╗"
        "   ██╔════╝██║  ██║██╔════╝██║     ██║     ████╗ ████║██║████╗  ██║╚══██╔══╝"
        "   ███████╗███████║█████╗  ██║     ██║     ██╔████╔██║██║██╔██╗ ██║   ██║   "
        "   ╚════██║██╔══██║██╔══╝  ██║     ██║     ██║╚██╔╝██║██║██║╚██╗██║   ██║   "
        "   ███████║██║  ██║███████╗███████╗███████╗██║ ╚═╝ ██║██║██║ ╚████║   ██║   "
        "   ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝   ╚═╝   "
        ""
        "   by Lasantha Kulasooriya"
        "   https://linkedin.com/in/lasantha-kulasooriya/"
        "   ${ROCKET} ShellMint — Modern Terminal for Developers & ML Engineers"
        "   ${COFFEE} Support: https://buymeacoffee.com/lasak97"
        ""
    )

    for line in "${lines[@]}"; do
        if [[ "$animate" -eq 1 ]]; then
            _type_out "${BOLD}${MAGENTA}${line}${RESET}" 0.002
        else
            echo "${BOLD}${MAGENTA}${line}${RESET}"
        fi
    done

    echo "${DIM}  $(printf '─%.0s' $(seq 1 74))${RESET}"
}

# print_banner
# First call: animated typing effect. Subsequent calls: instant print.
# Sets a terminal scroll region so the banner stays pinned at the top.
print_banner() {
    clear

    if [[ "$_BANNER_ANIMATED" -eq 0 ]]; then
        _print_banner_content 1
        _BANNER_ANIMATED=1
    else
        _print_banner_content 0
    fi

    # Set scroll region: from line BANNER_HEIGHT+1 to bottom of terminal
    local total_rows
    total_rows=$(tput lines 2>/dev/null || echo 40)
    printf '\033[%d;%dr' "$((BANNER_HEIGHT + 1))" "$total_rows"

    # Move cursor to the start of the scrollable area
    tput cup "$BANNER_HEIGHT" 0 2>/dev/null
}

# reset_scroll_region
# Restores the terminal to its normal full-screen scroll behavior.
# Call this before exiting or when the banner should no longer be pinned.
reset_scroll_region() {
    printf '\033[r'
    tput cup "$(tput lines 2>/dev/null || echo 40)" 0 2>/dev/null
}

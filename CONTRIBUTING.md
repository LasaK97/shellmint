# Contributing to ShellMint

Thanks for your interest in contributing! This guide will help you get started.

## Ways to Contribute

- **Report bugs** — something broke or behaves unexpectedly
- **Suggest features** — a new tool, category, or installer improvement
- **Submit code** — fix a bug, add a feature, or improve existing code
- **Improve docs** — fix typos, clarify instructions, add examples
- **Test on new distros** — help expand platform support

## Reporting Bugs

1. Check [existing issues](https://github.com/LasaK97/shellmint/issues) first
2. Open a new issue using the **Bug Report** template
3. Include:
   - Your OS and version (`lsb_release -a`)
   - The category/tool that failed
   - Relevant lines from `~/.shellmint-install.log`

## Suggesting Features

Open an issue using the **Feature Request** template. Explain:
- What problem it solves
- How you'd expect it to work
- Any alternatives you considered

## Submitting Code

### Setup

1. Fork the repo
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/shellmint.git
   cd shellmint
   ```
3. Create a branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

### Project Structure

```
shellmint/
├── install.sh              # Main installer entry point
├── uninstall.sh            # Selective uninstaller
├── VERSION                 # Current version number
├── tool-versions.conf      # Pinned tool versions (fallback)
├── scripts/
│   ├── utils.sh            # Shared utilities (colors, spinners, helpers)
│   ├── shell.sh            # Category 1: Zsh, Oh My Zsh, Oh My Posh, Atuin
│   ├── terminal.sh         # Category 2: Kitty, Hack Nerd Font
│   ├── cli-tools.sh        # Category 3: eza, bat, fd, ripgrep, fzf, etc.
│   ├── dev-tools.sh        # Category 4: Docker, Rust, Go, Node.js, etc.
│   ├── editor.sh           # Category 5: Neovim + LazyVim
│   ├── ml-tools.sh         # Category 6: Miniconda, PyTorch, Ollama, etc.
│   └── theme.sh            # Oh My Posh theme switcher
├── configs/
│   ├── .zshrc              # Zsh configuration
│   ├── .zshenv             # Zsh environment
│   ├── kitty/              # Kitty terminal config
│   ├── nvim/               # Neovim / LazyVim config
│   ├── oh-my-posh/         # Prompt theme
│   └── git/                # Git delta config
└── assets/                 # Screenshots and images
```

### Code Style

- **Indentation:** 4 spaces (no tabs)
- **Variables:** Use `local` for all function variables
- **Naming:** `snake_case` for functions and variables
- **Quoting:** Always quote variables (`"$var"`, not `$var`)
- **Error handling:** Use `set -euo pipefail` at the top of scripts
- **Background processes:** Always use the `spinner` function for user feedback
- **Idempotent:** Every install step should be safe to run multiple times (check before installing)

### Adding a New Tool

If you're adding a tool to an existing category (e.g., a new CLI tool):

1. Add the install logic in the appropriate script (e.g., `scripts/cli-tools.sh`)
2. Follow the existing pattern:
   ```bash
   # ── toolname ──────────────────────────────────────────────────────────
   print_step "Installing toolname"
   if command_exists toolname; then
       print_info "toolname is already installed"
       (( skipped++ ))
   else
       # install command here &>/dev/null &
       if spinner $! "Installing toolname"; then
           print_success "toolname installed"
           (( installed++ ))
       else
           print_error "Failed to install toolname"
           register_failure "toolname" "manual install command here"
           (( failed++ ))
       fi
   fi
   ```
3. Add a version check in the health check section of `install.sh`
4. Add the tool to the uninstaller in `uninstall.sh`
5. Update `README.md` (What You Get table, category details)
6. Update `CHANGELOG.md`

### Testing

Test your changes in Docker before submitting a PR:

```bash
docker run -it --rm -v "$(pwd):/shellmint" ubuntu:24.04 bash
```

Inside the container:

```bash
apt-get update && apt-get install -y sudo
useradd -m -s /bin/bash testuser
echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
su - testuser
cd /shellmint && bash install.sh
```

Test on at least one of: Ubuntu 24.04, Ubuntu 22.04, or Debian 12.

### Submitting

1. Commit your changes with a clear message:
   ```bash
   git commit -m "Add toolname to CLI tools category"
   ```
2. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
3. Open a Pull Request against `main`
4. Fill out the PR template checklist

### What to Expect

- PRs are typically reviewed within a few days
- Small fixes may be merged quickly
- Larger features may need discussion first — consider opening an issue before starting

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

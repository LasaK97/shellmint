# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-03-09

### Added
- Interactive installer with category selection menu (fzf-powered)
- 6 installation categories: Shell, Terminal, CLI Tools, Dev Tools, Editor, ML/AI Stack
- Shell setup: Zsh, Oh My Zsh (7 plugins), Oh My Posh prompt, Atuin shell history
- Terminal emulator: Kitty with GPU acceleration, Hack Nerd Font, cursor trails
- 14 modern CLI tools: eza, bat, fd, ripgrep, fzf, zoxide, lazygit, btop, yazi, glow, dust, delta, zellij, direnv
- Development tools: Docker, Rust, Go, Node.js (nvm), Java 17, CMake, uv, Git+Delta config
- Editor: Neovim (AppImage) with LazyVim, LSP, Treesitter, and smear-cursor
- ML/AI stack: Miniconda, PyTorch with automatic CUDA detection, JupyterLab, Ollama, nvitop
- Catppuccin Mocha theme applied across all tools (terminal, editor, fzf, bat, git diffs, prompt)
- Post-install health check verifying all installed tools
- Keybinding cheatsheet displayed after installation
- Selective uninstaller (`uninstall.sh`) with per-category options
- Oh My Posh theme switcher (`scripts/theme.sh`) with 20 popular themes
- CLI flags: `--yes`, `--categories`, `--skip`, `--dry-run`, `--update`, `--configs-only`, `--verbose`
- Version pinning via `tool-versions.conf` with GitHub API fallback
- Automatic config backup before overwriting (timestamped `.backup` files)
- Installation logging to `~/.shellmint-install.log`
- Spinner timeout support for slow package installations
- Graceful Ctrl+C handling with background process cleanup
- Tested on Ubuntu 24.04, Ubuntu 22.04, Debian 12, and Linux Mint 22

#!/usr/bin/env bash
# =============================================================================
# Dotfiles bootstrap — run on a fresh machine to get up and running
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lucafanselau/dotfiles/main/setup.sh | bash
#   — or —
#   git clone git@github.com:lucafanselau/dotfiles.git ~/.config && ~/.config/setup.sh
# =============================================================================
set -euo pipefail

DOTFILES_REPO="git@github.com:lucafanselau/dotfiles.git"
CONFIG_DIR="$HOME/.config"

# ---------- Helpers ----------
info() { printf '\033[1;34m=> %s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m✓  %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!  %s\033[0m\n' "$*"; }
fail() {
	printf '\033[1;31m✗  %s\033[0m\n' "$*"
	exit 1
}

command_exists() { command -v "$1" &>/dev/null; }

# ---------- Detect OS ----------
detect_os() {
	case "$(uname -s)" in
	Linux*) OS=linux ;;
	Darwin*) OS=macos ;;
	*) fail "Unsupported OS: $(uname -s)" ;;
	esac

	if [ "$OS" = "linux" ]; then
		if command_exists apt-get; then
			PKG=apt
		elif command_exists dnf; then
			PKG=dnf
		elif command_exists pacman; then
			PKG=pacman
		else
			fail "No supported package manager found (apt/dnf/pacman)"
		fi
	else
		PKG=brew
	fi

	info "Detected: $OS ($PKG)"
}

# ---------- Install packages ----------
install_packages() {
	info "Installing core packages..."

	case "$PKG" in
	apt)
		sudo apt-get update -qq
		sudo apt-get install -y -qq \
			git curl unzip build-essential \
			fish fzf ripgrep fd-find tmux jq

		# Neovim — distro version is too old, install 0.10+ from GitHub
		install_nvim_release

		# Tools not in default repos — install via their own installers
		install_gh_cli_apt
		install_delta_release
		install_eza_release
		install_zoxide
		install_uv
		install_dust_release
		install_fnm
		;;
	dnf)
		sudo dnf install -y \
			git curl unzip gcc make \
			fish fzf ripgrep fd-find tmux jq

		install_nvim_release
		install_gh_cli_dnf
		install_delta_release
		install_eza_release
		install_zoxide
		install_uv
		install_dust_release
		install_fnm
		;;
	pacman)
		sudo pacman -Syu --noconfirm \
			git curl unzip base-devel \
			fish neovim fzf ripgrep fd tmux jq \
			github-cli git-delta eza zoxide dust

		install_uv
		install_fnm
		;;
	brew)
		brew install \
			git fish neovim gh \
			fzf ripgrep fd tmux jq \
			git-delta eza zoxide dust uv ghostty
		;;
	esac

	ok "Core packages installed"
}

# --- Individual installers for tools not in default repos ---

install_nvim_release() {
	local NVIM_VERSION="0.11.0"
	local current_ver=""
	if command_exists nvim; then
		current_ver="$(nvim --version | head -1 | sed 's/NVIM v//')"
	fi
	# Need 0.10+
	if [ -n "$current_ver" ] && [ "$(printf '%s\n' "0.10" "$current_ver" | sort -V | head -1)" = "0.10" ]; then
		ok "Neovim $current_ver already installed (>= 0.10)"
		return
	fi
	info "Installing Neovim v${NVIM_VERSION} (distro version too old for kickstart)..."
	local arch
	arch="$(uname -m)"
	# 0.10+ uses nvim-linux-x86_64, older used nvim-linux64
	local url="https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-${arch}.appimage"
	curl -fsSL "$url" -o /tmp/nvim.appimage
	chmod +x /tmp/nvim.appimage
	# Try appimage directly, fall back to extraction (FUSE not available on many VPS)
	if /tmp/nvim.appimage --version &>/dev/null; then
		sudo mv /tmp/nvim.appimage /usr/local/bin/nvim
	else
		info "FUSE not available, extracting appimage..."
		(cd /tmp && ./nvim.appimage --appimage-extract) &>/dev/null
		sudo rm -rf /opt/nvim
		sudo mv /tmp/squashfs-root /opt/nvim
		sudo ln -sf /opt/nvim/usr/bin/nvim /usr/local/bin/nvim
		rm -f /tmp/nvim.appimage
	fi
	ok "Neovim $(nvim --version | head -1) installed"
}

install_fnm() {
	if command_exists fnm; then return; fi
	info "Installing fnm (node version manager)..."
	curl -fsSL https://fnm.vercel.app/install | bash
	# Install LTS node (needed by Mason for LSPs like ts_ls, pyright, prettierd)
	export PATH="$HOME/.local/share/fnm:$PATH"
	eval "$(fnm env)" 2>/dev/null || true
	fnm install --lts
	fnm default lts-latest
	ok "fnm + Node LTS installed"
}

install_gh_cli_apt() {
	if command_exists gh; then return; fi
	info "Installing GitHub CLI..."
	curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
		sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
		sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
	sudo apt-get update -qq && sudo apt-get install -y -qq gh
}

install_gh_cli_dnf() {
	if command_exists gh; then return; fi
	info "Installing GitHub CLI..."
	sudo dnf install -y 'dnf-command(config-manager)'
	sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
	sudo dnf install -y gh
}

install_delta_release() {
	if command_exists delta; then return; fi
	info "Installing git-delta..."
	local version="0.18.2"
	local arch
	arch="$(uname -m)"
	case "$arch" in
	x86_64) arch="x86_64" ;;
	aarch64) arch="aarch64" ;;
	*)
		warn "Unknown arch $arch, skipping delta"
		return
		;;
	esac
	curl -fsSL "https://github.com/dandavison/delta/releases/download/${version}/delta-${version}-${arch}-unknown-linux-gnu.tar.gz" |
		tar xz -C /tmp
	sudo install "/tmp/delta-${version}-${arch}-unknown-linux-gnu/delta" /usr/local/bin/delta
	ok "delta installed"
}

install_eza_release() {
	if command_exists eza; then return; fi
	info "Installing eza..."
	local arch
	arch="$(uname -m)"
	curl -fsSL "https://github.com/eza-community/eza/releases/latest/download/eza_${arch}-unknown-linux-gnu.tar.gz" |
		tar xz -C /tmp
	sudo install /tmp/eza /usr/local/bin/eza
	ok "eza installed"
}

install_zoxide() {
	if command_exists zoxide; then return; fi
	info "Installing zoxide..."
	curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
	ok "zoxide installed"
}

install_uv() {
	if command_exists uv; then return; fi
	info "Installing uv..."
	curl -LsSf https://astral.sh/uv/install.sh | sh
	ok "uv installed"
}

install_dust_release() {
	if command_exists dust; then return; fi
	info "Installing dust..."
	local arch
	arch="$(uname -m)"
	local version="1.1.1"
	curl -fsSL "https://github.com/bootandy/dust/releases/download/v${version}/dust-v${version}-${arch}-unknown-linux-gnu.tar.gz" |
		tar xz -C /tmp
	sudo install "/tmp/dust-v${version}-${arch}-unknown-linux-gnu/dust" /usr/local/bin/dust
	ok "dust installed"
}

# ---------- Clone dotfiles ----------
clone_dotfiles() {
	if [ -d "$CONFIG_DIR/.git" ]; then
		info "Dotfiles already cloned, pulling latest..."
		git -C "$CONFIG_DIR" pull --ff-only
	else
		info "Cloning dotfiles..."
		# If ~/.config exists but isn't a repo, clone into temp and merge
		if [ -d "$CONFIG_DIR" ]; then
			local tmp
			tmp="$(mktemp -d)"
			git clone "$DOTFILES_REPO" "$tmp"
			# Copy repo files into existing config dir
			cp -rn "$tmp/." "$CONFIG_DIR/" 2>/dev/null || true
			# Move .git over
			mv "$tmp/.git" "$CONFIG_DIR/.git"
			rm -rf "$tmp"
			# Reset to get clean state
			git -C "$CONFIG_DIR" checkout -- .
		else
			git clone "$DOTFILES_REPO" "$CONFIG_DIR"
		fi
	fi
	ok "Dotfiles in place"
}

# ---------- Set up fish ----------
setup_fish() {
	info "Setting up fish shell..."

	local fish_path
	fish_path="$(command -v fish)"

	# Add fish to /etc/shells if not there
	if ! grep -qF "$fish_path" /etc/shells 2>/dev/null; then
		echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
	fi

	# Set as default shell (try chsh, fall back to sudo usermod on Linux)
	if [ "$SHELL" != "$fish_path" ]; then
		info "Changing default shell to fish..."
		if chsh -s "$fish_path" 2>/dev/null; then
			ok "Default shell changed via chsh"
		elif [ "$OS" = "linux" ] && sudo usermod --shell "$fish_path" "$(whoami)" 2>/dev/null; then
			ok "Default shell changed via usermod"
		else
			warn "Could not change default shell automatically."
			warn "Run manually:  sudo chsh -s $fish_path $(whoami)"
		fi
	fi

	# Install fisher + plugins
	info "Installing fisher and plugins..."
	fish -c '
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        fisher install jorgebucaran/fisher
        fisher update
    '

	ok "Fish configured with plugins"
	echo ""
	info "Run 'tide configure' to set up your prompt theme."
}

# ---------- Set up git config ----------
setup_git() {
	info "Setting up git config..."

	# Point ~/.gitconfig to XDG config
	cat >"$HOME/.gitconfig" <<'EOF'
# Git reads ~/.config/git/config automatically (XDG).
# This file is intentionally minimal.
EOF

	# Remind about local secrets
	if [ ! -f "$CONFIG_DIR/git/config.local" ]; then
		warn "Create $CONFIG_DIR/git/config.local with machine-specific secrets:"
		warn "  [github]"
		warn "    user = <your-pat-token>"
	fi

	ok "Git config linked"
}

# ---------- Set up gh ----------
setup_gh() {
	if ! command_exists gh; then return; fi
	if [ ! -f "$CONFIG_DIR/gh/hosts.yml" ]; then
		info "Authenticate GitHub CLI:"
		info "  Run: gh auth login"
	else
		ok "gh already authenticated"
	fi
}

# ---------- Ghostty (skip on headless) ----------
setup_ghostty() {
	if [ "$OS" = "linux" ] && [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
		info "Headless server detected — skipping Ghostty"
		return
	fi
	ok "Ghostty config ready (${CONFIG_DIR}/ghostty/config)"
}

# ---------- Neovim first launch ----------
setup_nvim() {
	info "Neovim will auto-install plugins on first launch via lazy.nvim"
	ok "Run 'nvim' to trigger plugin installation"
}

# ---------- Worktrunk ----------
setup_worktrunk() {
	if command_exists wt; then
		ok "Worktrunk config ready"
	else
		info "Worktrunk not installed — install from https://worktrunk.dev if needed"
	fi
}

# =============================================================================
# Main
# =============================================================================
main() {
	echo ""
	echo "  Dotfiles Bootstrap"
	echo "  ==================="
	echo ""

	detect_os
	install_packages
	clone_dotfiles
	setup_git
	setup_fish
	setup_gh
	setup_ghostty
	setup_nvim
	setup_worktrunk

	echo ""
	ok "All done! Open a new terminal (or run 'fish') to get started."
	echo ""
	info "Reminders:"
	info "  - Run 'tide configure' to set up your fish prompt theme"
	info "  - Run 'gh auth login' if you haven't authenticated yet"
	info "  - Run 'nvim' to trigger lazy.nvim plugin installation"
	info "  - Create ~/.config/git/config.local for machine-specific git secrets"
	info "  - Create ~/.config/fish/config.local.fish for machine-specific fish config"
	echo ""
}

main "$@"

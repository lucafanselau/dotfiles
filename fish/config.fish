if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Ghostty terminal compatibility
set -gx TERM xterm-256color

# Default editor
set -gx EDITOR nvim
set -gx VISUAL nvim

# Zoxide (smart cd)
if type -q zoxide
    zoxide init fish | source
    alias cd="z"
end

# Paths — use $HOME instead of hardcoded paths
fish_add_path ~/.cargo/bin
fish_add_path ~/.local/bin

# Modern CLI replacements (only alias if installed)
if type -q eza
    alias ls="eza"
    alias ll="eza -l"
end

if type -q dust
    alias du="dust"
end

alias df="df -h"

# ---------- Platform-specific ----------

# pnpm (macOS uses ~/Library, Linux uses ~/.local/share)
if test -d "$HOME/Library/pnpm"
    set -gx PNPM_HOME "$HOME/Library/pnpm"
else if test -d "$HOME/.local/share/pnpm"
    set -gx PNPM_HOME "$HOME/.local/share/pnpm"
end
if set -q PNPM_HOME
    fish_add_path "$PNPM_HOME"
end

# LM Studio (optional)
if test -d "$HOME/.lmstudio/bin"
    fish_add_path "$HOME/.lmstudio/bin"
end

# Machine-local overrides (not tracked by git)
if test -f ~/.config/fish/config.local.fish
    source ~/.config/fish/config.local.fish
end

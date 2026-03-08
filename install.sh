#!/usr/bin/env bash
set -euo pipefail

# WalkCode one-click installer
# Usage: curl -fsSL https://raw.githubusercontent.com/0x5446/walkcode/main/install.sh | bash

REPO="0x5446/walkcode"
GITHUB_URL="https://github.com/${REPO}.git"
CONFIG_DIR="${WALKCODE_DIR:-$HOME/.walkcode}"
SHELL_RC=""

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[walkcode]${NC} $*"; }
warn()  { echo -e "${YELLOW}[walkcode]${NC} $*"; }
error() { echo -e "${RED}[walkcode]${NC} $*" >&2; }

# --- Detect shell rc file ---
detect_shell_rc() {
  if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
    SHELL_RC="$HOME/.zshrc"
  elif [ -n "${BASH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "bash" ]; then
    SHELL_RC="$HOME/.bashrc"
  else
    SHELL_RC="$HOME/.profile"
  fi
}

# --- Check prerequisites ---
check_prereqs() {
  local missing=()

  if ! command -v tmux &>/dev/null; then
    if command -v brew &>/dev/null; then
      info "Installing tmux via Homebrew..."
      brew install tmux
    else
      missing+=("tmux (brew install tmux)")
    fi
  fi

  if ! command -v uv &>/dev/null; then
    info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    error "Missing prerequisites: ${missing[*]}"
    exit 1
  fi
}

# --- Get latest release tag ---
get_latest_tag() {
  local tag
  tag=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null \
        | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/') || true
  echo "$tag"
}

# --- Install Python package via uv tool ---
install_package() {
  local tag
  tag=$(get_latest_tag)

  if [ -n "$tag" ]; then
    info "Installing WalkCode ${tag}..."
    uv tool install "git+${GITHUB_URL}@${tag}" --force 2>/dev/null \
      || uv tool install "git+${GITHUB_URL}@${tag}"
  else
    info "No releases found, installing from main branch..."
    uv tool install "git+${GITHUB_URL}" --force 2>/dev/null \
      || uv tool install "git+${GITHUB_URL}"
  fi
}

# --- Setup config directory and .env ---
setup_config() {
  mkdir -p "$CONFIG_DIR/workspace"

  if [ ! -f "$CONFIG_DIR/.env" ]; then
    cat > "$CONFIG_DIR/.env" << 'ENVFILE'
# WalkCode Configuration
# See: https://github.com/0x5446/walkcode

# Feishu App credentials (required)
FEISHU_APP_ID=
FEISHU_APP_SECRET=

# Who receives notifications (required)
# Use open_id for direct messages, or chat_id for group chats
FEISHU_RECEIVE_ID=
FEISHU_RECEIVE_ID_TYPE=open_id

# Server port (optional, default 3001)
# PORT=3001
ENVFILE
    warn ".env created — edit $CONFIG_DIR/.env with your Feishu credentials"
  else
    info ".env already exists, skipping"
  fi
}

# --- Install shell wrapper ---
install_wrapper() {
  detect_shell_rc

  local marker="# >>> walkcode claude wrapper >>>"
  if grep -q "$marker" "$SHELL_RC" 2>/dev/null; then
    info "Shell wrapper already installed in $SHELL_RC"
    return
  fi

  info "Adding claude wrapper to $SHELL_RC..."
  cat >> "$SHELL_RC" << 'WRAPPER'

# >>> walkcode claude wrapper >>>
claude() {
  if [ -z "$TMUX" ]; then
    local session="claude-$(basename "$PWD")-$$"
    tmux new-session -s "$session" "command claude $@"
  else
    command claude "$@"
  fi
}
# <<< walkcode claude wrapper <<<
WRAPPER

  info "Shell wrapper installed. Run: source $SHELL_RC"
}

# --- Configure tmux ---
configure_tmux() {
  local tmux_conf="$HOME/.tmux.conf"
  local marker="# >>> walkcode tmux config >>>"

  if grep -q "$marker" "$tmux_conf" 2>/dev/null; then
    info "tmux config already present in $tmux_conf"
    return
  fi

  info "Adding tmux scrollback config to $tmux_conf..."
  cat >> "$tmux_conf" << 'TMUXCFG'

# >>> walkcode tmux config >>>
# Disable alternate screen so TUI output (e.g. Claude Code) stays in scrollback
# Use Ctrl-b [ to scroll back through history
set-option -ga terminal-overrides ',*:smcup@:rmcup@'
# <<< walkcode tmux config <<<
TMUXCFG

  # Hot-reload if tmux server is running
  tmux source-file "$tmux_conf" 2>/dev/null || true
  info "tmux config installed"
}

# --- Install Claude Code hooks ---
install_hooks() {
  local settings="$HOME/.claude/settings.json"
  if [ ! -f "$settings" ]; then
    warn "$settings not found — skipping hook installation"
    warn "Run 'walkcode install-hooks' after Claude Code is set up"
    return
  fi

  info "Installing Claude Code hooks..."
  walkcode install-hooks
}

# --- Main ---
main() {
  echo ""
  echo "  ╦ ╦╔═╗╦  ╦╔═╔═╗╔═╗╔╦╗╔═╗"
  echo "  ║║║╠═╣║  ╠╩╗║  ║ ║ ║║║╣ "
  echo "  ╚╩╝╩ ╩╩═╝╩ ╩╚═╝╚═╝═╩╝╚═╝"
  echo "  Code is cheap. Show me your talk."
  echo ""

  check_prereqs
  install_package
  setup_config
  install_wrapper
  configure_tmux
  install_hooks

  # Restart daemon if already running (upgrade scenario)
  if command -v walkcode &>/dev/null && walkcode status &>/dev/null; then
    info "Restarting WalkCode daemon..."
    walkcode restart
  fi

  echo ""
  info "Installation complete!"
  echo ""
  echo "  Next steps:"
  echo "  1. Edit $CONFIG_DIR/.env with your Feishu credentials"
  echo "  2. source $SHELL_RC"
  echo "  3. walkcode start"
  echo "  4. Send a message to your Feishu bot to get your open_id"
  echo "  5. Add open_id to .env, restart, and go for a walk"
  echo ""
  echo "  Recommended: prevent macOS from sleeping on AC power so the network"
  echo "  stays up while you're away (display can still turn off):"
  echo ""
  echo "    sudo pmset -c sleep 0 && sudo pmset -c disksleep 0 \\"
  echo "         && sudo pmset -c standby 0 && sudo pmset -c hibernatemode 0"
  echo ""
}

main "$@"

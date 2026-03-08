#!/usr/bin/env bash
set -euo pipefail

# WalkCode one-click uninstaller
# Usage: bash uninstall.sh
#   or:  curl -fsSL https://raw.githubusercontent.com/0x5446/walkcode/main/uninstall.sh | bash

INSTALL_DIR="${WALKCODE_DIR:-$HOME/.walkcode}"

# All candidate shell rc files (same strategy as rustup/nvm/uv)
RC_CANDIDATES=(
  "$HOME/.zshrc"
  "$HOME/.zshenv"
  "$HOME/.zprofile"
  "$HOME/.bashrc"
  "$HOME/.bash_profile"
  "$HOME/.bash_login"
  "$HOME/.profile"
)

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[walkcode]${NC} $*"; }
warn()  { echo -e "${YELLOW}[walkcode]${NC} $*"; }
error() { echo -e "${RED}[walkcode]${NC} $*" >&2; }

# --- i18n ---
is_zh() {
  case "${LANG:-}${LANGUAGE:-}" in zh*) return 0 ;; esac
  return 1
}
msg() { if is_zh; then echo "$2"; else echo "$1"; fi; }

# --- Stop daemon if running ---
stop_daemon() {
  local pid_file="$INSTALL_DIR/walkcode.pid"
  if [ -f "$pid_file" ]; then
    local pid
    pid=$(cat "$pid_file" 2>/dev/null || true)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      info "$(msg "Stopping WalkCode daemon (pid $pid)..." "正在停止 WalkCode 守护进程 (pid $pid)...")"
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
      info "$(msg "Daemon stopped" "守护进程已停止")"
    fi
    rm -f "$pid_file"
  fi
}

# --- Remove shell wrapper from ALL candidate rc files ---
remove_shell_wrapper() {
  local marker_start="# >>> walkcode claude wrapper >>>"
  local marker_end="# <<< walkcode claude wrapper <<<"
  local found=0

  for rc in "${RC_CANDIDATES[@]}"; do
    [ -f "$rc" ] || continue
    if grep -q "$marker_start" "$rc" 2>/dev/null; then
      info "$(msg "Removing shell wrapper from $rc..." "正在从 $rc 移除 shell wrapper...")"
      sed -i.walkcode-bak "/$marker_start/,/$marker_end/d" "$rc"
      rm -f "${rc}.walkcode-bak"
      found=1
    fi
  done

  if [ "$found" -eq 0 ]; then
    info "$(msg "No shell wrapper found in any shell rc file, skipping" "未在任何 shell rc 文件中找到 wrapper，跳过")"
  fi
}

# --- Remove tmux config ---
remove_tmux_config() {
  local tmux_conf="$HOME/.tmux.conf"
  local marker_start="# >>> walkcode tmux config >>>"
  local marker_end="# <<< walkcode tmux config <<<"

  if [ -f "$tmux_conf" ] && grep -q "$marker_start" "$tmux_conf" 2>/dev/null; then
    info "$(msg "Removing tmux config from $tmux_conf..." "正在从 $tmux_conf 移除 tmux 配置...")"
    sed -i.walkcode-bak "/$marker_start/,/$marker_end/d" "$tmux_conf"
    rm -f "${tmux_conf}.walkcode-bak"
    # Remove file if empty (only whitespace left)
    if [ ! -s "$tmux_conf" ] || ! grep -q '[^[:space:]]' "$tmux_conf" 2>/dev/null; then
      rm -f "$tmux_conf"
      info "$(msg "Removed empty $tmux_conf" "已删除空文件 $tmux_conf")"
    fi
    tmux source-file "$tmux_conf" 2>/dev/null || true
  else
    info "$(msg "No WalkCode tmux config found, skipping" "未找到 WalkCode tmux 配置，跳过")"
  fi
}

# --- Remove Claude Code hooks ---
remove_hooks() {
  local settings="$HOME/.claude/settings.json"
  if [ ! -f "$settings" ]; then
    info "$(msg "No Claude Code settings found, skipping hooks removal" "未找到 Claude Code 配置文件，跳过 hooks 移除")"
    return
  fi

  if ! command -v python3 &>/dev/null; then
    warn "$(msg \
      "python3 not found, cannot auto-remove hooks from $settings" \
      "未找到 python3，无法自动移除 $settings 中的 hooks")"
    warn "$(msg \
      "Please manually remove the \"hooks\" section from $settings" \
      "请手动移除 $settings 中的 \"hooks\" 部分")"
    return
  fi

  # Only remove hooks that contain "walkcode" commands
  if grep -q "walkcode" "$settings" 2>/dev/null; then
    info "$(msg "Removing WalkCode hooks from $settings..." "正在从 $settings 移除 WalkCode hooks...")"
    python3 -c "
import json, sys
path = '$settings'
with open(path) as f:
    data = json.load(f)
hooks = data.get('hooks', {})
changed = False
for event in list(hooks.keys()):
    entries = hooks[event]
    filtered = []
    for entry in entries:
        cmds = entry.get('hooks', [])
        cmds = [c for c in cmds if 'walkcode' not in c.get('command', '')]
        if cmds:
            entry['hooks'] = cmds
            filtered.append(entry)
    if filtered:
        hooks[event] = filtered
    else:
        del hooks[event]
        changed = True
if not hooks and 'hooks' in data:
    del data['hooks']
    changed = True
if changed or hooks != data.get('hooks'):
    with open(path, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print('Hooks removed')
else:
    print('No WalkCode hooks found')
"
  else
    info "$(msg "No WalkCode hooks found in $settings, skipping" "未在 $settings 中找到 WalkCode hooks，跳过")"
  fi
}

# --- Remove install directory ---
remove_install_dir() {
  if [ -d "$INSTALL_DIR" ]; then
    info "$(msg "Removing install directory $INSTALL_DIR..." "正在移除安装目录 $INSTALL_DIR...")"
    rm -rf "$INSTALL_DIR"
    info "$(msg "Install directory removed" "安装目录已移除")"
  else
    info "$(msg "Install directory $INSTALL_DIR not found, skipping" "安装目录 $INSTALL_DIR 不存在，跳过")"
  fi
}

# --- Main ---
main() {
  echo ""
  echo "  ╦ ╦╔═╗╦  ╦╔═╔═╗╔═╗╔╦╗╔═╗"
  echo "  ║║║╠═╣║  ╠╩╗║  ║ ║ ║║║╣ "
  echo "  ╚╩╝╩ ╩╩═╝╩ ╩╚═╝╚═╝═╩╝╚═╝"
  if is_zh; then
    echo "  卸载程序"
  else
    echo "  Uninstaller"
  fi
  echo ""

  if is_zh; then
    echo "即将移除:"
    echo "  1. WalkCode 守护进程（如正在运行）"
    echo "  2. 所有 rc 文件中的 Shell wrapper (.zshrc, .bashrc, .profile 等)"
    echo "  3. ~/.tmux.conf 中的 tmux 配置"
    echo "  4. ~/.claude/settings.json 中的 Claude Code hooks"
    echo "  5. 安装目录 ($INSTALL_DIR)"
  else
    echo "This will remove:"
    echo "  1. WalkCode daemon (if running)"
    echo "  2. Shell wrapper from all rc files (.zshrc, .bashrc, .profile, etc.)"
    echo "  3. tmux config from ~/.tmux.conf"
    echo "  4. Claude Code hooks from ~/.claude/settings.json"
    echo "  5. Install directory ($INSTALL_DIR)"
  fi
  echo ""
  printf "$(msg "Continue? [y/N] " "继续？[y/N] ")"
  read -r answer </dev/tty
  if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    echo "$(msg "Aborted." "已取消。")"
    exit 0
  fi

  echo ""
  stop_daemon
  remove_shell_wrapper
  remove_tmux_config
  remove_hooks
  remove_install_dir

  echo ""
  info "$(msg "WalkCode has been completely removed." "WalkCode 已完全卸载。")"
  echo ""
  echo "  $(msg "Restart your shell or run 'exec \$SHELL' to apply changes." "重启终端或执行 'exec \$SHELL' 以应用更改。")"
  echo ""
}

main "$@"

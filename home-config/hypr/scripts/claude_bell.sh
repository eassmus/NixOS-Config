#!/usr/bin/env bash
# Claude Code Stop/Notification hook (~/.claude/settings.json): ring the bell in this
# session's terminal. kitty turns a bell in an unfocused window into an attention request,
# Hyprland marks the window urgent, and the quickshell workspace dot goes green until the
# window is focused. Hooks have no controlling tty, so find the terminal through the claude
# process: the first ancestor whose stdout is a pty.
p=$PPID
while [ "$p" -gt 1 ]; do
  t=$(readlink "/proc/$p/fd/1")
  if [[ $t == /dev/pts/* ]]; then
    printf '\a' > "$t"
    exit 0
  fi
  p=$(ps -o ppid= -p "$p" | tr -d ' ')
done
